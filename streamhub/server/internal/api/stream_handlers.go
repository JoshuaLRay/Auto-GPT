package api

import (
	"errors"
	"net/http"
	"time"

	"github.com/joshualray/streamhub/internal/library"
	"github.com/joshualray/streamhub/internal/stream"
)

// handlePlaybackInfo reports the direct-play/transcode decision for an item
// without starting a stream — useful for clients and debugging.
func (s *Server) handlePlaybackInfo(w http.ResponseWriter, r *http.Request) {
	item, err := s.Repo.Get(r.PathValue("id"))
	if errors.Is(err, library.ErrNotFound) {
		writeError(w, http.StatusNotFound, "item not found")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not load item")
		return
	}
	decision := stream.Decide(item, stream.DefaultProfile())
	writeJSON(w, http.StatusOK, map[string]any{
		"itemId":   item.ID,
		"decision": decision,
	})
}

// handleStartStream starts (or reuses) an HLS session for an item and redirects
// to the session's media playlist. The redirect target's URL becomes the base
// for the playlist's relative segment URLs.
func (s *Server) handleStartStream(w http.ResponseWriter, r *http.Request) {
	item, err := s.Repo.Get(r.PathValue("id"))
	if errors.Is(err, library.ErrNotFound) {
		writeError(w, http.StatusNotFound, "item not found")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not load item")
		return
	}

	inputPath, ok := s.Store.LocalPath(item.Path)
	if !ok {
		// Remote-only storage (e.g. S3) needs a download/pipe path — Phase 6.
		writeError(w, http.StatusNotImplemented, "remote storage streaming not yet supported")
		return
	}

	decision := stream.Decide(item, stream.DefaultProfile())
	sess, err := s.Streams.Start(inputPath, decision.DirectPlay, decision.MaxHeight)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not start stream")
		return
	}
	if _, err := s.Streams.WaitForPlaylist(sess, 15*time.Second); err != nil {
		writeError(w, http.StatusGatewayTimeout, "stream did not start in time")
		return
	}

	http.Redirect(w, r, "/api/stream/sessions/"+sess.ID+"/index.m3u8", http.StatusFound)
}

// handleSessionFile serves a playlist or segment from a session directory.
func (s *Server) handleSessionFile(w http.ResponseWriter, r *http.Request) {
	path, ok := s.Streams.File(r.PathValue("sid"), r.PathValue("file"))
	if !ok {
		http.Error(w, "session not found", http.StatusNotFound)
		return
	}
	http.ServeFile(w, r, path)
}
