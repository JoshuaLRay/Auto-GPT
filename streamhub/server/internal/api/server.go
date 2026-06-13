// Package api wires the HTTP routes and handlers over the service layer.
package api

import (
	"encoding/json"
	"net/http"

	"github.com/joshualray/streamhub/internal/auth"
	"github.com/joshualray/streamhub/internal/library"
	"github.com/joshualray/streamhub/internal/storage"
	"github.com/joshualray/streamhub/internal/stream"
)

// Server holds the dependencies the HTTP handlers need.
type Server struct {
	Auth    *auth.Service
	Repo    *library.Repository
	Scanner *library.Scanner
	Store   storage.Storage
	Streams *stream.Manager
}

// Handler builds the http.Handler with all routes mounted.
func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()

	// Public.
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})
	mux.HandleFunc("POST /api/auth/login", s.handleLogin)

	// Per-session HLS files are protected by the unguessable session ID itself,
	// so they are not behind the JWT middleware (relative segment URLs in the
	// playlist would otherwise lose the token). See stream.Session docs.
	mux.HandleFunc("GET /api/stream/sessions/{sid}/{file}", s.handleSessionFile)

	// Authenticated API.
	protected := http.NewServeMux()
	protected.HandleFunc("GET /api/me", s.handleMe)
	protected.HandleFunc("GET /api/items", s.handleListItems)
	protected.HandleFunc("GET /api/items/{id}", s.handleGetItem)
	protected.HandleFunc("GET /api/items/{id}/playback-info", s.handlePlaybackInfo)
	protected.HandleFunc("GET /api/items/{id}/progress", s.handleGetProgress)
	protected.HandleFunc("PUT /api/items/{id}/progress", s.handleSetProgress)
	protected.HandleFunc("GET /api/items/{id}/hls.m3u8", s.handleStartStream)
	protected.HandleFunc("POST /api/library/scan", s.handleScan)

	mux.Handle("/api/", s.Auth.Middleware(protected))

	return withCommonHeaders(mux)
}

// writeJSON serializes v as JSON with the given status code.
func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}

// withCommonHeaders applies permissive CORS so the Phase 2 web app (served from
// a different origin in dev) can call the API.
func withCommonHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, OPTIONS")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}
