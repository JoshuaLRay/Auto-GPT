package stream

import "github.com/joshualray/streamhub/internal/models"
import "testing"

func TestDecide(t *testing.T) {
	profile := DefaultProfile() // h264 + aac, max 1080p

	tests := []struct {
		name           string
		item           *models.LibraryItem
		wantDirectPlay bool
	}{
		{
			name:           "h264/aac 1080p is direct play",
			item:           &models.LibraryItem{VideoCodec: "h264", AudioCodec: "aac", Height: 1080},
			wantDirectPlay: true,
		},
		{
			name:           "hevc transcodes",
			item:           &models.LibraryItem{VideoCodec: "hevc", AudioCodec: "aac", Height: 1080},
			wantDirectPlay: false,
		},
		{
			name:           "ac3 audio transcodes",
			item:           &models.LibraryItem{VideoCodec: "h264", AudioCodec: "ac3", Height: 720},
			wantDirectPlay: false,
		},
		{
			name:           "4k exceeds max height, transcodes",
			item:           &models.LibraryItem{VideoCodec: "h264", AudioCodec: "aac", Height: 2160},
			wantDirectPlay: false,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := Decide(tt.item, profile); got.DirectPlay != tt.wantDirectPlay {
				t.Errorf("Decide() directPlay = %v, want %v (reason: %s)", got.DirectPlay, tt.wantDirectPlay, got.Reason)
			}
		})
	}
}
