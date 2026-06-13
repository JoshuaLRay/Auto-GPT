package storage

import (
	"io"
	"io/fs"
	"os"
	"path/filepath"
)

// Local is a Storage backed by one or more local filesystem roots. Keys are
// absolute filesystem paths, so LocalPath is always available.
type Local struct {
	roots []string
}

// NewLocal creates a local-filesystem storage over the given roots.
func NewLocal(roots []string) *Local {
	abs := make([]string, 0, len(roots))
	for _, r := range roots {
		if p, err := filepath.Abs(r); err == nil {
			abs = append(abs, p)
		} else {
			abs = append(abs, r)
		}
	}
	return &Local{roots: abs}
}

func (l *Local) Walk(fn func(FileInfo) error) error {
	for _, root := range l.roots {
		err := filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
			if err != nil {
				return nil // skip unreadable entries rather than aborting the whole scan
			}
			if d.IsDir() {
				return nil
			}
			info, err := d.Info()
			if err != nil {
				return nil
			}
			return fn(FileInfo{Key: path, SizeBytes: info.Size(), ModUnix: info.ModTime().Unix()})
		})
		if err != nil {
			return err
		}
	}
	return nil
}

func (l *Local) Open(key string) (io.ReadSeekCloser, error) {
	return os.Open(key)
}

func (l *Local) LocalPath(key string) (string, bool) {
	return key, true
}
