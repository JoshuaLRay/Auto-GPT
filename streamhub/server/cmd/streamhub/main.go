// Command streamhub is the StreamHub media server: it scans a media library,
// serves a JSON API, and streams media as HLS to web/Roku/Android TV clients.
package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
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

	var uploadDir string
	if len(cfg.MediaDirs) > 0 {
		uploadDir = cfg.MediaDirs[0]
	}
	srv := &api.Server{
		Auth:           authSvc,
		Repo:           repo,
		Scanner:        scanner,
		Store:          store,
		Streams:        streams,
		WebDir:         cfg.WebDir,
		UploadDir:      uploadDir,
		MaxUploadBytes: int64(cfg.MaxUploadMB) << 20,
	}

	// Kick off an initial library scan in the background so first run populates,
	// then (optionally) synthesize a sample clip if the library is still empty.
	go func() {
		log.Println("starting initial library scan...")
		n, err := scanner.Scan(context.Background())
		if err != nil {
			log.Printf("initial scan error: %v", err)
		} else {
			log.Printf("initial scan complete: %d item(s) indexed", n)
		}
		maybeGenerateSample(cfg, tools, repo, scanner, uploadDir)
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

// maybeGenerateSample synthesizes a demo clip when STREAMHUB_GENERATE_SAMPLE is
// set and the library is empty — useful on fresh/ephemeral cloud deployments so
// there's something to stream immediately.
func maybeGenerateSample(cfg *config.Config, tools ffmpeg.Tools, repo *library.Repository, scanner *library.Scanner, dir string) {
	if !cfg.GenerateSample || dir == "" {
		return
	}
	if n, err := repo.Count(); err != nil || n > 0 {
		return
	}
	if err := os.MkdirAll(dir, 0o755); err != nil {
		log.Printf("sample: cannot create media dir: %v", err)
		return
	}
	out := filepath.Join(dir, "StreamHub Sample.mp4")
	log.Println("generating sample clip (library is empty)...")
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()
	if err := tools.GenerateSample(ctx, out); err != nil {
		log.Printf("sample: generation failed: %v", err)
		return
	}
	if err := scanner.AddFile(context.Background(), out); err != nil {
		log.Printf("sample: indexing failed: %v", err)
		return
	}
	log.Println("sample clip ready")
}
