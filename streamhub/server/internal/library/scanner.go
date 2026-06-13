package library

import (
	"context"
	"log"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/joshualray/streamhub/internal/ffmpeg"
	"github.com/joshualray/streamhub/internal/metadata"
	"github.com/joshualray/streamhub/internal/models"
	"github.com/joshualray/streamhub/internal/storage"
	"github.com/joshualray/streamhub/internal/util"
)

// videoExts are the container extensions treated as playable video in Phase 1.
// Music and photos arrive in Phase 3.
var videoExts = map[string]bool{
	".mp4": true, ".mkv": true, ".mov": true, ".avi": true,
	".m4v": true, ".webm": true, ".ts": true, ".wmv": true,
}

// Scanner discovers media on a Storage, probes it, and upserts library items.
type Scanner struct {
	repo  *Repository
	store storage.Storage
	probe ffmpeg.Tools
	tmdb  *metadata.TMDB

	mu       sync.Mutex
	scanning bool
}

// NewScanner wires a scanner. tmdb may be nil to disable online enrichment.
func NewScanner(repo *Repository, store storage.Storage, probe ffmpeg.Tools, tmdb *metadata.TMDB) *Scanner {
	return &Scanner{repo: repo, store: store, probe: probe, tmdb: tmdb}
}

// Scanning reports whether a scan is currently in progress.
func (s *Scanner) Scanning() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.scanning
}

// Scan walks storage once, adding/updating video items. It is safe to call
// concurrently; overlapping calls return immediately while one is running.
func (s *Scanner) Scan(ctx context.Context) (added int, err error) {
	s.mu.Lock()
	if s.scanning {
		s.mu.Unlock()
		return 0, nil
	}
	s.scanning = true
	s.mu.Unlock()
	defer func() {
		s.mu.Lock()
		s.scanning = false
		s.mu.Unlock()
	}()

	err = s.store.Walk(func(fi storage.FileInfo) error {
		if ctx.Err() != nil {
			return ctx.Err()
		}
		ext := strings.ToLower(filepath.Ext(fi.Key))
		if !videoExts[ext] {
			return nil
		}
		// Skip files we've already indexed at the same size (cheap freshness check).
		if existing, err := s.repo.GetByPath(fi.Key); err == nil && existing.SizeBytes == fi.SizeBytes {
			return nil
		}
		if err := s.indexVideo(ctx, fi); err != nil {
			log.Printf("scan: skipping %q: %v", fi.Key, err)
			return nil // one bad file shouldn't abort the whole scan
		}
		added++
		return nil
	})
	return added, err
}

func (s *Scanner) indexVideo(ctx context.Context, fi storage.FileInfo) error {
	info, err := s.probe.Probe(ctx, fi.Key)
	if err != nil {
		return err
	}

	parsed := metadata.ParseFilename(fi.Key)
	it := &models.LibraryItem{
		ID:              util.NewID(),
		Type:            string(models.TypeMovie),
		Title:           parsed.Title,
		SortTitle:       strings.ToLower(parsed.Title),
		Year:            parsed.Year,
		Path:            fi.Key,
		Container:       info.Container,
		VideoCodec:      info.VideoCodec,
		AudioCodec:      info.AudioCodec,
		Width:           info.Width,
		Height:          info.Height,
		DurationSeconds: info.DurationSeconds,
		SizeBytes:       fi.SizeBytes,
	}
	if it.Title == "" {
		it.Title = filepath.Base(fi.Key)
		it.SortTitle = strings.ToLower(it.Title)
	}

	// Preserve a stable ID across re-scans of the same file.
	if existing, err := s.repo.GetByPath(fi.Key); err == nil {
		it.ID = existing.ID
		it.AddedAt = existing.AddedAt
	}

	// Optional online enrichment; failures are non-fatal.
	if s.tmdb != nil {
		ectx, cancel := context.WithTimeout(ctx, 12*time.Second)
		if res, err := s.tmdb.SearchMovie(ectx, parsed.Title, parsed.Year); err == nil && res != nil {
			it.Title = res.Title
			it.SortTitle = strings.ToLower(res.Title)
			it.Overview = res.Overview
			it.PosterURL = res.PosterURL
			if res.Year != nil {
				it.Year = res.Year
			}
		}
		cancel()
	}

	return s.repo.Upsert(it)
}
