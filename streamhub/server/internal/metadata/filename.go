// Package metadata derives titles/years from filenames and (optionally)
// enriches video items via TMDB.
package metadata

import (
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

var (
	yearRe      = regexp.MustCompile(`\b(19|20)\d{2}\b`)
	separatorRe = regexp.MustCompile(`[._\[\]()]+`)
	// Common release noise we strip from titles.
	noiseRe = regexp.MustCompile(`(?i)\b(1080p|720p|2160p|4k|x264|x265|h264|h265|hevc|bluray|webrip|web-dl|hdtv|dvdrip|aac|dts|ddp?5\.1|remux|proper|repack)\b`)
)

// Parsed holds the cleaned-up title and optional year extracted from a filename.
type Parsed struct {
	Title string
	Year  *int
}

// ParseFilename turns "The.Matrix.1999.1080p.BluRay.x264.mkv" into
// {Title: "The Matrix", Year: 1999}.
func ParseFilename(path string) Parsed {
	base := filepath.Base(path)
	name := strings.TrimSuffix(base, filepath.Ext(base))
	name = separatorRe.ReplaceAllString(name, " ")

	// A title may itself contain a year-like number (e.g. "Blade Runner 2049"),
	// so treat the LAST year-like token as the release year and the text before
	// it as the title.
	var year *int
	if locs := yearRe.FindAllStringIndex(name, -1); len(locs) > 0 {
		last := locs[len(locs)-1]
		if y, err := strconv.Atoi(strings.TrimSpace(name[last[0]:last[1]])); err == nil {
			year = &y
		}
		name = name[:last[0]]
	}

	name = noiseRe.ReplaceAllString(name, " ")
	name = strings.Join(strings.Fields(name), " ") // collapse whitespace
	return Parsed{Title: strings.TrimSpace(name), Year: year}
}
