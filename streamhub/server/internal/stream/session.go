package stream

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/joshualray/streamhub/internal/ffmpeg"
	"github.com/joshualray/streamhub/internal/util"
)

// sessionTTL is how long an idle session lives before cleanup.
const sessionTTL = 30 * time.Minute

// Session is one running FFmpeg HLS transcode/remux. Its ID doubles as an
// unguessable capability token: possession of the session URL grants access to
// its segments (signed, time-limited URLs are a Phase 6 hardening).
type Session struct {
	ID       string
	Dir      string
	cancel   context.CancelFunc
	lastSeen time.Time
}

// Manager owns the lifecycle of HLS sessions and their on-disk output.
type Manager struct {
	tools   ffmpeg.Tools
	baseDir string

	mu       sync.Mutex
	sessions map[string]*Session
}

// NewManager creates a session manager writing HLS output under baseDir.
func NewManager(tools ffmpeg.Tools, baseDir string) (*Manager, error) {
	if err := os.MkdirAll(baseDir, 0o755); err != nil {
		return nil, err
	}
	m := &Manager{tools: tools, baseDir: baseDir, sessions: map[string]*Session{}}
	go m.reaper()
	return m, nil
}

// Start launches an FFmpeg HLS process for inputPath. When remux is true it
// remuxes (direct play); otherwise it transcodes to H.264/AAC capped at maxHeight.
func (m *Manager) Start(inputPath string, remux bool, maxHeight int) (*Session, error) {
	id := util.NewToken()
	dir := filepath.Join(m.baseDir, id)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return nil, err
	}

	ctx, cancel := context.WithCancel(context.Background())
	cmd := m.tools.BuildHLSCommand(ctx, ffmpeg.HLSArgs{
		Input:     inputPath,
		OutDir:    dir,
		Copy:      remux,
		MaxHeight: maxHeight,
	})
	if err := cmd.Start(); err != nil {
		cancel()
		_ = os.RemoveAll(dir)
		return nil, fmt.Errorf("start ffmpeg: %w", err)
	}
	// Reap the process when it exits on its own so it isn't left as a zombie.
	go func() { _ = cmd.Wait() }()

	sess := &Session{ID: id, Dir: dir, cancel: cancel, lastSeen: time.Now()}
	m.mu.Lock()
	m.sessions[id] = sess
	m.mu.Unlock()
	return sess, nil
}

// WaitForPlaylist blocks until index.m3u8 exists (FFmpeg writes it shortly after
// the first segment) or the timeout elapses.
func (m *Manager) WaitForPlaylist(s *Session, timeout time.Duration) (string, error) {
	playlist := filepath.Join(s.Dir, "index.m3u8")
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if fi, err := os.Stat(playlist); err == nil && fi.Size() > 0 {
			return playlist, nil
		}
		time.Sleep(150 * time.Millisecond)
	}
	return "", fmt.Errorf("playlist not ready after %s", timeout)
}

// File returns the absolute path of a file within a session, guarding against
// path traversal, and refreshes the session's idle timer. ok is false if the
// session is unknown or the name escapes the session directory.
func (m *Manager) File(sessionID, name string) (path string, ok bool) {
	m.mu.Lock()
	sess, found := m.sessions[sessionID]
	if found {
		sess.lastSeen = time.Now()
	}
	m.mu.Unlock()
	if !found {
		return "", false
	}
	clean := filepath.Join(sess.Dir, filepath.Clean("/"+name))
	if rel, err := filepath.Rel(sess.Dir, clean); err != nil || rel == ".." || filepath.IsAbs(rel) {
		return "", false
	}
	return clean, true
}

func (m *Manager) reaper() {
	ticker := time.NewTicker(time.Minute)
	defer ticker.Stop()
	for range ticker.C {
		now := time.Now()
		m.mu.Lock()
		for id, s := range m.sessions {
			if now.Sub(s.lastSeen) > sessionTTL {
				s.cancel()
				_ = os.RemoveAll(s.Dir)
				delete(m.sessions, id)
			}
		}
		m.mu.Unlock()
	}
}
