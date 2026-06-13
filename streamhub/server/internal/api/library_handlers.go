package api

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"

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
