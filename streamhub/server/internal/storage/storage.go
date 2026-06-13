// Package storage abstracts where media bytes live. Phase 1 ships a local
// filesystem adapter; the same interface lets Phase 6 add an S3-compatible
// adapter without touching the scanner or streaming code.
package storage

import "io"

// FileInfo describes a single media file discovered during a walk.
type FileInfo struct {
	Key       string // opaque storage key (the local path, for the local adapter)
	SizeBytes int64
	ModUnix   int64
}

// Storage is the backend-agnostic media source.
type Storage interface {
	// Walk visits every file under the configured roots.
	Walk(fn func(FileInfo) error) error
	// Open returns a readable, seekable handle to the bytes for key.
	Open(key string) (io.ReadSeekCloser, error)
	// LocalPath returns a real filesystem path for key when one exists (so
	// FFmpeg can read it directly). ok is false for remote-only backends, in
	// which case callers must fall back to streaming via Open.
	LocalPath(key string) (path string, ok bool)
}
