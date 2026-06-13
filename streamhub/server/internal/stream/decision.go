// Package stream contains the playback decision engine and the HLS session
// manager that drives FFmpeg.
package stream

import "github.com/joshualray/streamhub/internal/models"

// ClientProfile describes what a given client can play directly. Clients send
// this (Phase 1 uses defaults); the decision engine uses it to choose
// direct-play vs. transcode.
type ClientProfile struct {
	VideoCodecs []string // e.g. ["h264", "hevc"]
	AudioCodecs []string // e.g. ["aac"]
	MaxHeight   int      // 0 = unlimited
}

// DefaultProfile is a conservative baseline that virtually every client
// (browser, Roku, Android TV) can play: H.264 video + AAC audio, up to 1080p.
func DefaultProfile() ClientProfile {
	return ClientProfile{
		VideoCodecs: []string{"h264"},
		AudioCodecs: []string{"aac"},
		MaxHeight:   1080,
	}
}

// Decision is the outcome of the engine: whether to remux (direct play) or
// transcode, and the target constraints for transcoding.
type Decision struct {
	DirectPlay bool   `json:"directPlay"`
	Reason     string `json:"reason"`
	MaxHeight  int    `json:"maxHeight,omitempty"`
}

// Decide picks the cheapest path that yields a stream the client can play.
// Phase 1 emits a single HLS rendition; the adaptive bitrate ladder is Phase 6.
func Decide(item *models.LibraryItem, p ClientProfile) Decision {
	videoOK := contains(p.VideoCodecs, item.VideoCodec)
	audioOK := item.AudioCodec == "" || contains(p.AudioCodecs, item.AudioCodec)
	heightOK := p.MaxHeight == 0 || item.Height == 0 || item.Height <= p.MaxHeight

	if videoOK && audioOK && heightOK {
		return Decision{DirectPlay: true, Reason: "source codecs are client-compatible"}
	}

	d := Decision{DirectPlay: false, MaxHeight: p.MaxHeight}
	switch {
	case !videoOK:
		d.Reason = "video codec not supported by client: " + item.VideoCodec
	case !audioOK:
		d.Reason = "audio codec not supported by client: " + item.AudioCodec
	default:
		d.Reason = "source resolution exceeds client maximum"
	}
	return d
}

func contains(set []string, v string) bool {
	for _, s := range set {
		if s == v {
			return true
		}
	}
	return false
}
