package metadata

import "testing"

func TestParseFilename(t *testing.T) {
	tests := []struct {
		in        string
		wantTitle string
		wantYear  int // 0 means "expect nil"
	}{
		{"The.Matrix.1999.1080p.BluRay.x264.mkv", "The Matrix", 1999},
		{"Inception (2010) [1080p].mp4", "Inception", 2010},
		{"Blade_Runner_2049_2017_2160p_HEVC.mkv", "Blade Runner 2049", 2017},
		{"home_video_clip.mp4", "home video clip", 0},
	}
	for _, tt := range tests {
		got := ParseFilename(tt.in)
		if got.Title != tt.wantTitle {
			t.Errorf("ParseFilename(%q) title = %q, want %q", tt.in, got.Title, tt.wantTitle)
		}
		switch {
		case tt.wantYear == 0 && got.Year != nil:
			t.Errorf("ParseFilename(%q) year = %d, want nil", tt.in, *got.Year)
		case tt.wantYear != 0 && (got.Year == nil || *got.Year != tt.wantYear):
			t.Errorf("ParseFilename(%q) year = %v, want %d", tt.in, got.Year, tt.wantYear)
		}
	}
}
