package api

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/joshualray/streamhub/internal/auth"
	"github.com/joshualray/streamhub/internal/library"
	"github.com/joshualray/streamhub/internal/models"
)

func (s *Server) handleListItems(w http.ResponseWriter, r *http.Request) {
	itemType := r.URL.Query().Get("type")
	parent := r.URL.Query().Get("parent")
	items, err := s.Repo.List(itemType, parent)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not list items")
		return
	}
	if items == nil {
		items = []*models.LibraryItem{} // ensure [] not null in JSON
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items})
}

func (s *Server) handleGetItem(w http.ResponseWriter, r *http.Request) {
	item, err := s.Repo.Get(r.PathValue("id"))
	if errors.Is(err, library.ErrNotFound) {
		writeError(w, http.StatusNotFound, "item not found")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not load item")
		return
	}
	writeJSON(w, http.StatusOK, item)
}

func (s *Server) handleGetProgress(w http.ResponseWriter, r *http.Request) {
	user, _ := auth.UserFrom(r.Context())
	prog, err := s.Repo.GetProgress(user.ID, r.PathValue("id"))
	if errors.Is(err, library.ErrNotFound) {
		writeJSON(w, http.StatusOK, map[string]any{"positionSeconds": 0})
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not load progress")
		return
	}
	writeJSON(w, http.StatusOK, prog)
}

func (s *Server) handleSetProgress(w http.ResponseWriter, r *http.Request) {
	user, _ := auth.UserFrom(r.Context())
	var req struct {
		PositionSeconds float64 `json:"positionSeconds"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if err := s.Repo.SetProgress(user.ID, r.PathValue("id"), req.PositionSeconds); err != nil {
		writeError(w, http.StatusInternalServerError, "could not save progress")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) handleScan(w http.ResponseWriter, r *http.Request) {
	user, _ := auth.UserFrom(r.Context())
	if !user.IsAdmin {
		writeError(w, http.StatusForbidden, "admin required")
		return
	}
	// Run the scan in the background so the request returns promptly.
	go func() { _, _ = s.Scanner.Scan(context.Background()) }()
	writeJSON(w, http.StatusAccepted, map[string]string{"status": "scan started"})
}

// handleUpload accepts a multipart video upload (admin only), stores it in the
// upload directory, and indexes it so it appears in the library immediately.
func (s *Server) handleUpload(w http.ResponseWriter, r *http.Request) {
	user, _ := auth.UserFrom(r.Context())
	if !user.IsAdmin {
		writeError(w, http.StatusForbidden, "admin required")
		return
	}
	if s.UploadDir == "" {
		writeError(w, http.StatusNotImplemented, "uploads are not configured")
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, s.MaxUploadBytes)
	if err := r.ParseMultipartForm(32 << 20); err != nil {
		writeError(w, http.StatusRequestEntityTooLarge, "upload too large or malformed")
		return
	}
	file, header, err := r.FormFile("file")
	if err != nil {
		writeError(w, http.StatusBadRequest, "missing 'file' field")
		return
	}
	defer file.Close()

	name := safeFilename(header.Filename)
	if !library.IsVideoExt(filepath.Ext(name)) {
		writeError(w, http.StatusUnsupportedMediaType, "unsupported file type (video only)")
		return
	}

	if err := os.MkdirAll(s.UploadDir, 0o755); err != nil {
		writeError(w, http.StatusInternalServerError, "could not prepare upload directory")
		return
	}
	dst := uniquePath(filepath.Join(s.UploadDir, name))
	out, err := os.Create(dst)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not save upload")
		return
	}
	if _, err := io.Copy(out, file); err != nil {
		out.Close()
		os.Remove(dst)
		writeError(w, http.StatusInternalServerError, "could not write upload")
		return
	}
	out.Close()

	// Index immediately; if probing fails (e.g. not real media), discard it.
	if err := s.Scanner.AddFile(r.Context(), dst); err != nil {
		os.Remove(dst)
		writeError(w, http.StatusUnprocessableEntity, "could not process file: "+err.Error())
		return
	}
	item, err := s.Repo.GetByPath(dst)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "indexed file not found")
		return
	}
	writeJSON(w, http.StatusCreated, item)
}

// safeFilename reduces an uploaded filename to a safe basename, replacing
// anything unusual so it can't escape the upload directory.
func safeFilename(name string) string {
	name = filepath.Base(strings.ReplaceAll(name, "\\", "/"))
	cleaned := strings.Map(func(r rune) rune {
		switch {
		case r >= 'a' && r <= 'z', r >= 'A' && r <= 'Z', r >= '0' && r <= '9':
			return r
		case r == ' ' || r == '.' || r == '-' || r == '_' || r == '(' || r == ')':
			return r
		default:
			return '_'
		}
	}, name)
	cleaned = strings.TrimLeft(strings.TrimSpace(cleaned), ".")
	if cleaned == "" {
		cleaned = "upload.mp4"
	}
	return cleaned
}

// uniquePath returns path, or path with a numeric suffix if it already exists,
// so concurrent uploads of the same name don't clobber each other.
func uniquePath(path string) string {
	if _, err := os.Stat(path); os.IsNotExist(err) {
		return path
	}
	ext := filepath.Ext(path)
	base := strings.TrimSuffix(path, ext)
	for i := 1; ; i++ {
		candidate := fmt.Sprintf("%s (%d)%s", base, i, ext)
		if _, err := os.Stat(candidate); os.IsNotExist(err) {
			return candidate
		}
	}
}
