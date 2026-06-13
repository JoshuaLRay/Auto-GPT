// Package db opens the SQLite database (via the pure-Go modernc driver, so the
// server stays a single static binary) and applies the schema.
package db

import (
	"database/sql"
	"fmt"

	_ "modernc.org/sqlite"
)

// Open connects to the SQLite database at path, tunes pragmas for a server
// workload, and applies the schema migrations.
func Open(path string) (*sql.DB, error) {
	dsn := fmt.Sprintf(
		"file:%s?_pragma=busy_timeout(5000)&_pragma=journal_mode(WAL)&_pragma=foreign_keys(1)&_pragma=synchronous(NORMAL)",
		path,
	)
	database, err := sql.Open("sqlite", dsn)
	if err != nil {
		return nil, fmt.Errorf("open sqlite: %w", err)
	}
	// SQLite handles one writer at a time; keep the pool small to avoid lock churn.
	database.SetMaxOpenConns(1)
	if err := database.Ping(); err != nil {
		return nil, fmt.Errorf("ping sqlite: %w", err)
	}
	if err := migrate(database); err != nil {
		return nil, fmt.Errorf("migrate: %w", err)
	}
	return database, nil
}

func migrate(database *sql.DB) error {
	_, err := database.Exec(schema)
	return err
}

const schema = `
CREATE TABLE IF NOT EXISTS users (
    id            TEXT PRIMARY KEY,
    username      TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    is_admin      INTEGER NOT NULL DEFAULT 0,
    created_at    INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS library_items (
    id               TEXT PRIMARY KEY,
    type             TEXT NOT NULL,
    parent_id        TEXT REFERENCES library_items(id) ON DELETE CASCADE,
    title            TEXT NOT NULL,
    sort_title       TEXT NOT NULL DEFAULT '',
    year             INTEGER,
    overview         TEXT NOT NULL DEFAULT '',
    path             TEXT NOT NULL UNIQUE,
    container        TEXT NOT NULL DEFAULT '',
    video_codec      TEXT NOT NULL DEFAULT '',
    audio_codec      TEXT NOT NULL DEFAULT '',
    width            INTEGER NOT NULL DEFAULT 0,
    height           INTEGER NOT NULL DEFAULT 0,
    duration_seconds REAL NOT NULL DEFAULT 0,
    size_bytes       INTEGER NOT NULL DEFAULT 0,
    poster_url       TEXT NOT NULL DEFAULT '',
    added_at         INTEGER NOT NULL,
    updated_at       INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_items_type      ON library_items(type);
CREATE INDEX IF NOT EXISTS idx_items_parent    ON library_items(parent_id);
CREATE INDEX IF NOT EXISTS idx_items_sorttitle ON library_items(sort_title);

CREATE TABLE IF NOT EXISTS playback_progress (
    user_id          TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    item_id          TEXT NOT NULL REFERENCES library_items(id) ON DELETE CASCADE,
    position_seconds REAL NOT NULL,
    updated_at       INTEGER NOT NULL,
    PRIMARY KEY (user_id, item_id)
);
`
