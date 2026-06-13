// Package models defines the core domain types shared across the backend.
package models

// ItemType discriminates the kind of media a LibraryItem represents.
type ItemType string

const (
	TypeMovie     ItemType = "movie"
	TypeEpisode   ItemType = "episode"
	TypeTrack     ItemType = "track"
	TypeAlbum     ItemType = "album"
	TypePhoto     ItemType = "photo"
	TypeHomeVideo ItemType = "home_video"
)

// User is an account that can authenticate and stream.
type User struct {
	ID           string `json:"id"`
	Username     string `json:"username"`
	PasswordHash string `json:"-"`
	IsAdmin      bool   `json:"isAdmin"`
	CreatedAt    int64  `json:"createdAt"`
}

// LibraryItem is a single piece of media (or a collection node) in the library.
// The same struct serves every media type via the Type discriminator; fields
// that don't apply to a given type are simply zero-valued.
type LibraryItem struct {
	ID              string  `json:"id"`
	Type            string  `json:"type"`
	ParentID        *string `json:"parentId,omitempty"`
	Title           string  `json:"title"`
	SortTitle       string  `json:"sortTitle,omitempty"`
	Year            *int    `json:"year,omitempty"`
	Overview        string  `json:"overview,omitempty"`
	Path            string  `json:"-"` // storage key; never exposed to clients
	Container       string  `json:"container,omitempty"`
	VideoCodec      string  `json:"videoCodec,omitempty"`
	AudioCodec      string  `json:"audioCodec,omitempty"`
	Width           int     `json:"width,omitempty"`
	Height          int     `json:"height,omitempty"`
	DurationSeconds float64 `json:"durationSeconds,omitempty"`
	SizeBytes       int64   `json:"sizeBytes,omitempty"`
	PosterURL       string  `json:"posterUrl,omitempty"`
	AddedAt         int64   `json:"addedAt"`
	UpdatedAt       int64   `json:"updatedAt"`
}

// Progress records how far a user has watched/listened to an item.
type Progress struct {
	UserID          string  `json:"-"`
	ItemID          string  `json:"itemId"`
	PositionSeconds float64 `json:"positionSeconds"`
	UpdatedAt       int64   `json:"updatedAt"`
}
