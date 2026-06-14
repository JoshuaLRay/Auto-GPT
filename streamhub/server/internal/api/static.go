package api

import (
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

// spaHandler serves the built web app from WebDir. Unknown routes without a
// file extension fall back to index.html so client-side routing works on a hard
// refresh or deep link (e.g. /items/abc). Missing assets still return 404.
func (s *Server) spaHandler() http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if s.WebDir == "" {
			http.NotFound(w, r)
			return
		}
		index := filepath.Join(s.WebDir, "index.html")

		reqPath := filepath.Clean("/" + strings.TrimPrefix(r.URL.Path, "/"))
		file := filepath.Join(s.WebDir, reqPath)

		// Guard against path traversal escaping WebDir.
		if rel, err := filepath.Rel(s.WebDir, file); err != nil || rel == ".." || strings.HasPrefix(rel, ".."+string(filepath.Separator)) {
			http.NotFound(w, r)
			return
		}

		if reqPath != "/" {
			if info, err := os.Stat(file); err == nil && !info.IsDir() {
				http.ServeFile(w, r, file)
				return
			}
			// A missing path that looks like an asset is a genuine 404.
			if filepath.Ext(reqPath) != "" {
				http.NotFound(w, r)
				return
			}
		}
		// SPA route (or "/") => serve index.html (404s on its own if not built).
		http.ServeFile(w, r, index)
	})
}
