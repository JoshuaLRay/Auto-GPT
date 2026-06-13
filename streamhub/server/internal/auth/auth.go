// Package auth handles password hashing, JWT issuance/verification, the user
// store, and HTTP middleware that puts the authenticated user in the context.
package auth

import (
	"context"
	"database/sql"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"

	"github.com/joshualray/streamhub/internal/models"
	"github.com/joshualray/streamhub/internal/util"
)

// TokenTTL is how long an issued access token remains valid.
const TokenTTL = 7 * 24 * time.Hour

// ErrInvalidCredentials is returned when a login fails.
var ErrInvalidCredentials = errors.New("invalid credentials")

type ctxKey struct{}

// Service issues/validates tokens and manages users.
type Service struct {
	db     *sql.DB
	secret []byte
}

// NewService wires the auth service.
func NewService(db *sql.DB, secret []byte) *Service {
	return &Service{db: db, secret: secret}
}

// EnsureAdmin creates or updates the bootstrap admin account from config. A
// blank password leaves any existing account untouched and creates none.
func (s *Service) EnsureAdmin(username, password string) error {
	if password == "" {
		return nil
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return err
	}
	_, err = s.db.Exec(`
		INSERT INTO users (id, username, password_hash, is_admin, created_at)
		VALUES (?,?,?,1,?)
		ON CONFLICT(username) DO UPDATE SET password_hash=excluded.password_hash, is_admin=1`,
		util.NewID(), username, string(hash), time.Now().Unix(),
	)
	return err
}

// Authenticate verifies a username/password and returns the user on success.
func (s *Service) Authenticate(username, password string) (*models.User, error) {
	u, err := s.userByUsername(username)
	if err != nil {
		return nil, ErrInvalidCredentials
	}
	if bcrypt.CompareHashAndPassword([]byte(u.PasswordHash), []byte(password)) != nil {
		return nil, ErrInvalidCredentials
	}
	return u, nil
}

// IssueToken mints a signed JWT for the user.
func (s *Service) IssueToken(u *models.User) (string, error) {
	claims := jwt.RegisteredClaims{
		Subject:   u.ID,
		ExpiresAt: jwt.NewNumericDate(time.Now().Add(TokenTTL)),
		IssuedAt:  jwt.NewNumericDate(time.Now()),
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString(s.secret)
}

func (s *Service) parseToken(tokenStr string) (*models.User, error) {
	token, err := jwt.ParseWithClaims(tokenStr, &jwt.RegisteredClaims{}, func(t *jwt.Token) (any, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("unexpected signing method")
		}
		return s.secret, nil
	})
	if err != nil || !token.Valid {
		return nil, errors.New("invalid token")
	}
	claims, ok := token.Claims.(*jwt.RegisteredClaims)
	if !ok {
		return nil, errors.New("invalid claims")
	}
	return s.userByID(claims.Subject)
}

func (s *Service) userByID(id string) (*models.User, error) {
	row := s.db.QueryRow(`SELECT id, username, password_hash, is_admin, created_at FROM users WHERE id = ?`, id)
	return scanUser(row)
}

func (s *Service) userByUsername(username string) (*models.User, error) {
	row := s.db.QueryRow(`SELECT id, username, password_hash, is_admin, created_at FROM users WHERE username = ?`, username)
	return scanUser(row)
}

func scanUser(row interface{ Scan(...any) error }) (*models.User, error) {
	var u models.User
	var admin int
	if err := row.Scan(&u.ID, &u.Username, &u.PasswordHash, &admin, &u.CreatedAt); err != nil {
		return nil, err
	}
	u.IsAdmin = admin != 0
	return &u, nil
}

// Middleware authenticates requests using a Bearer header or a `token` query
// parameter (the query form supports <video>/HLS clients that can't set headers).
func (s *Service) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		tokenStr := bearer(r)
		if tokenStr == "" {
			tokenStr = r.URL.Query().Get("token")
		}
		if tokenStr == "" {
			http.Error(w, "missing token", http.StatusUnauthorized)
			return
		}
		u, err := s.parseToken(tokenStr)
		if err != nil {
			http.Error(w, "invalid token", http.StatusUnauthorized)
			return
		}
		next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), ctxKey{}, u)))
	})
}

func bearer(r *http.Request) string {
	h := r.Header.Get("Authorization")
	if strings.HasPrefix(h, "Bearer ") {
		return strings.TrimPrefix(h, "Bearer ")
	}
	return ""
}

// UserFrom returns the authenticated user from a request context, if any.
func UserFrom(ctx context.Context) (*models.User, bool) {
	u, ok := ctx.Value(ctxKey{}).(*models.User)
	return u, ok
}
