// Package library handles the canonical media catalog: persistence (repository)
// and discovery (scanner).
package library

import (
	"database/sql"
	"errors"
	"time"

	"github.com/joshualray/streamhub/internal/models"
)

// ErrNotFound is returned when an item or progress row does not exist.
var ErrNotFound = errors.New("not found")

// Repository provides CRUD access to library items and playback progress.
type Repository struct{ db *sql.DB }

// NewRepository wraps a database handle.
func NewRepository(db *sql.DB) *Repository { return &Repository{db: db} }

const itemCols = `id, type, parent_id, title, sort_title, year, overview, path,
	container, video_codec, audio_codec, width, height, duration_seconds,
	size_bytes, poster_url, added_at, updated_at`

func scanItem(row interface{ Scan(...any) error }) (*models.LibraryItem, error) {
	var it models.LibraryItem
	var parentID sql.NullString
	var year sql.NullInt64
	err := row.Scan(
		&it.ID, &it.Type, &parentID, &it.Title, &it.SortTitle, &year, &it.Overview,
		&it.Path, &it.Container, &it.VideoCodec, &it.AudioCodec, &it.Width, &it.Height,
		&it.DurationSeconds, &it.SizeBytes, &it.PosterURL, &it.AddedAt, &it.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	if parentID.Valid {
		it.ParentID = &parentID.String
	}
	if year.Valid {
		y := int(year.Int64)
		it.Year = &y
	}
	return &it, nil
}

// List returns items, optionally filtered by type and/or parent ID. Pass empty
// strings to skip a filter.
func (r *Repository) List(itemType, parentID string) ([]*models.LibraryItem, error) {
	query := `SELECT ` + itemCols + ` FROM library_items WHERE 1=1`
	var args []any
	if itemType != "" {
		query += ` AND type = ?`
		args = append(args, itemType)
	}
	if parentID != "" {
		query += ` AND parent_id = ?`
		args = append(args, parentID)
	}
	query += ` ORDER BY sort_title, title`

	rows, err := r.db.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []*models.LibraryItem
	for rows.Next() {
		it, err := scanItem(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, it)
	}
	return items, rows.Err()
}

// Count returns the total number of library items.
func (r *Repository) Count() (int, error) {
	var n int
	err := r.db.QueryRow(`SELECT COUNT(*) FROM library_items`).Scan(&n)
	return n, err
}

// Get returns a single item by ID.
func (r *Repository) Get(id string) (*models.LibraryItem, error) {
	row := r.db.QueryRow(`SELECT `+itemCols+` FROM library_items WHERE id = ?`, id)
	it, err := scanItem(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	return it, err
}

// GetByPath returns an item by its storage path, or ErrNotFound.
func (r *Repository) GetByPath(path string) (*models.LibraryItem, error) {
	row := r.db.QueryRow(`SELECT `+itemCols+` FROM library_items WHERE path = ?`, path)
	it, err := scanItem(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	return it, err
}

// Upsert inserts a new item or updates the existing one matching its path.
func (r *Repository) Upsert(it *models.LibraryItem) error {
	now := time.Now().Unix()
	if it.AddedAt == 0 {
		it.AddedAt = now
	}
	it.UpdatedAt = now

	var parentID any
	if it.ParentID != nil {
		parentID = *it.ParentID
	}
	var year any
	if it.Year != nil {
		year = *it.Year
	}

	_, err := r.db.Exec(`
		INSERT INTO library_items (`+itemCols+`)
		VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
		ON CONFLICT(path) DO UPDATE SET
			type=excluded.type, parent_id=excluded.parent_id, title=excluded.title,
			sort_title=excluded.sort_title, year=excluded.year, overview=excluded.overview,
			container=excluded.container, video_codec=excluded.video_codec,
			audio_codec=excluded.audio_codec, width=excluded.width, height=excluded.height,
			duration_seconds=excluded.duration_seconds, size_bytes=excluded.size_bytes,
			poster_url=excluded.poster_url, updated_at=excluded.updated_at`,
		it.ID, it.Type, parentID, it.Title, it.SortTitle, year, it.Overview, it.Path,
		it.Container, it.VideoCodec, it.AudioCodec, it.Width, it.Height,
		it.DurationSeconds, it.SizeBytes, it.PosterURL, it.AddedAt, it.UpdatedAt,
	)
	return err
}

// GetProgress returns a user's playback position for an item, or ErrNotFound.
func (r *Repository) GetProgress(userID, itemID string) (*models.Progress, error) {
	row := r.db.QueryRow(
		`SELECT user_id, item_id, position_seconds, updated_at FROM playback_progress WHERE user_id = ? AND item_id = ?`,
		userID, itemID,
	)
	var p models.Progress
	err := row.Scan(&p.UserID, &p.ItemID, &p.PositionSeconds, &p.UpdatedAt)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	return &p, err
}

// SetProgress upserts a user's playback position for an item.
func (r *Repository) SetProgress(userID, itemID string, pos float64) error {
	_, err := r.db.Exec(`
		INSERT INTO playback_progress (user_id, item_id, position_seconds, updated_at)
		VALUES (?,?,?,?)
		ON CONFLICT(user_id, item_id) DO UPDATE SET
			position_seconds=excluded.position_seconds, updated_at=excluded.updated_at`,
		userID, itemID, pos, time.Now().Unix(),
	)
	return err
}
