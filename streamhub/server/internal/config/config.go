// Package config loads StreamHub configuration from the environment, following
// 12-factor conventions so the same binary runs unchanged locally or in the cloud.
package config

import (
	"crypto/rand"
	"encoding/hex"
	"log"
	"os"
	"path/filepath"
	"strings"
)

// Config holds all runtime settings for the server.
type Config struct {
	Addr      string   // listen address, e.g. ":8080"
	DataDir   string   // where the SQLite DB and transcode cache live
	MediaDirs []string // one or more roots to scan for media

	JWTSecret []byte // signing key for access tokens

	AdminUser     string // bootstrapped admin username
	AdminPassword string // bootstrapped admin password (hashed on first run)

	TMDBAPIKey string // optional; enables rich video metadata when set

	FFmpegPath  string // path to ffmpeg binary
	FFprobePath string // path to ffprobe binary

	WebDir string // directory of the built web app to serve (empty = API only)
}

// TranscodeDir is where per-session HLS output is written.
func (c *Config) TranscodeDir() string { return filepath.Join(c.DataDir, "transcode") }

// DBPath is the SQLite database file location.
func (c *Config) DBPath() string { return filepath.Join(c.DataDir, "streamhub.db") }

// Load reads configuration from the environment, applying sensible defaults.
func Load() *Config {
	c := &Config{
		Addr:          env("STREAMHUB_ADDR", ":8080"),
		DataDir:       env("STREAMHUB_DATA_DIR", "./data"),
		AdminUser:     env("STREAMHUB_ADMIN_USER", "admin"),
		AdminPassword: env("STREAMHUB_ADMIN_PASSWORD", ""),
		TMDBAPIKey:    env("STREAMHUB_TMDB_API_KEY", ""),
		FFmpegPath:    env("STREAMHUB_FFMPEG", "ffmpeg"),
		FFprobePath:   env("STREAMHUB_FFPROBE", "ffprobe"),
		WebDir:        env("STREAMHUB_WEB_DIR", ""),
	}

	for _, d := range strings.Split(env("STREAMHUB_MEDIA_DIRS", "./media"), string(os.PathListSeparator)) {
		if d = strings.TrimSpace(d); d != "" {
			c.MediaDirs = append(c.MediaDirs, d)
		}
	}

	if secret := env("STREAMHUB_JWT_SECRET", ""); secret != "" {
		c.JWTSecret = []byte(secret)
	} else {
		// Generate an ephemeral secret so dev startup works; warn loudly because
		// it invalidates all tokens on restart and must be set in production.
		buf := make([]byte, 32)
		_, _ = rand.Read(buf)
		c.JWTSecret = []byte(hex.EncodeToString(buf))
		log.Println("WARNING: STREAMHUB_JWT_SECRET not set; using an ephemeral secret (tokens will not survive restart)")
	}

	if c.AdminPassword == "" {
		log.Println("WARNING: STREAMHUB_ADMIN_PASSWORD not set; the admin account will not be usable until it is configured")
	}

	return c
}

func env(key, def string) string {
	if v, ok := os.LookupEnv(key); ok {
		return v
	}
	return def
}
