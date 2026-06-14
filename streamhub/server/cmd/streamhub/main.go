// Command streamhub is the StreamHub media server: it scans a media library,
// serves a JSON API, and streams media as HLS to web/Roku/Android TV clients.
package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/joshualray/streamhub/internal/api"
	"github.com/joshualray/streamhub/internal/auth"
	"github.com/joshualray/streamhub/internal/config"
	"github.com/joshualray/streamhub/internal/db"
	"github.com/joshualray/streamhub/internal/ffmpeg"
	"github.com/joshualray/streamhub/internal/library"
	"github.com/joshualray/streamhub/internal/metadata"
	"github.com/joshualray/streamhub/internal/storage"
	"github.com/joshualray/streamhub/internal/stream"
)

func main() {
	cfg := config.Load()

	if err := os.MkdirAll(cfg.DataDir, 0o755); err != nil {
		log.Fatalf("create data dir: %v", err)
	}

	database, err := db.Open(cfg.DBPath())
	if err != nil {
		log.Fatalf("open database: %v", err)
	}
	defer database.Close()

	authSvc := auth.NewService(database, cfg.JWTSecret)
	if err := authSvc.EnsureAdmin(cfg.AdminUser, cfg.AdminPassword); err != nil {
		log.Fatalf("bootstrap admin: %v", err)
	}

	tools := ffmpeg.Tools{FFmpeg: cfg.FFmpegPath, FFprobe: cfg.FFprobePath}
	store := storage.NewLocal(cfg.MediaDirs)
	repo := library.NewRepository(database)
	scanner := library.NewScanner(repo, store, tools, metadata.NewTMDB(cfg.TMDBAPIKey))

	streams, err := stream.NewManager(tools, cfg.TranscodeDir())
	if err != nil {
		log.Fatalf("init stream manager: %v", err)
	}

	srv := &api.Server{
		Auth:    authSvc,
		Repo:    repo,
		Scanner: scanner,
		Store:   store,
		Streams: streams,
		WebDir:  cfg.WebDir,
	}

	// Kick off an initial library scan in the background so first run populates.
	go func() {
		log.Println("starting initial library scan...")
		n, err := scanner.Scan(context.Background())
		if err != nil {
			log.Printf("initial scan error: %v", err)
			return
		}
		log.Printf("initial scan complete: %d item(s) indexed", n)
	}()

	httpSrv := &http.Server{
		Addr:              cfg.Addr,
		Handler:           srv.Handler(),
		ReadHeaderTimeout: 10 * time.Second,
	}

	// Graceful shutdown on SIGINT/SIGTERM.
	go func() {
		sigCh := make(chan os.Signal, 1)
		signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
		<-sigCh
		log.Println("shutting down...")
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		_ = httpSrv.Shutdown(ctx)
	}()

	log.Printf("StreamHub listening on %s (media: %v)", cfg.Addr, cfg.MediaDirs)
	if err := httpSrv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("server error: %v", err)
	}
}
