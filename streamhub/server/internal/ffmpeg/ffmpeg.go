// Package ffmpeg wraps the ffprobe and ffmpeg binaries: probing media for its
// codecs/dimensions and building the HLS transcode/remux command lines.
package ffmpeg

import (
	"context"
	"encoding/json"
	"fmt"
	"os/exec"
	"strconv"
)

// Tools locates the external ffmpeg/ffprobe binaries.
type Tools struct {
	FFmpeg  string
	FFprobe string
}

// MediaInfo is the subset of probe output the server cares about.
type MediaInfo struct {
	Container       string
	VideoCodec      string
	AudioCodec      string
	Width           int
	Height          int
	DurationSeconds float64
	SizeBytes       int64
}

// Probe inspects a local media file and returns its container/codec details.
func (t Tools) Probe(ctx context.Context, path string) (*MediaInfo, error) {
	cmd := exec.CommandContext(ctx, t.FFprobe,
		"-v", "quiet",
		"-print_format", "json",
		"-show_format",
		"-show_streams",
		path,
	)
	out, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("ffprobe %q: %w", path, err)
	}

	var raw struct {
		Streams []struct {
			CodecType string `json:"codec_type"`
			CodecName string `json:"codec_name"`
			Width     int    `json:"width"`
			Height    int    `json:"height"`
		} `json:"streams"`
		Format struct {
			FormatName string `json:"format_name"`
			Duration   string `json:"duration"`
			Size       string `json:"size"`
		} `json:"format"`
	}
	if err := json.Unmarshal(out, &raw); err != nil {
		return nil, fmt.Errorf("parse ffprobe output: %w", err)
	}

	info := &MediaInfo{Container: raw.Format.FormatName}
	for _, s := range raw.Streams {
		switch s.CodecType {
		case "video":
			if info.VideoCodec == "" { // first video stream wins
				info.VideoCodec = s.CodecName
				info.Width = s.Width
				info.Height = s.Height
			}
		case "audio":
			if info.AudioCodec == "" {
				info.AudioCodec = s.CodecName
			}
		}
	}
	if d, err := strconv.ParseFloat(raw.Format.Duration, 64); err == nil {
		info.DurationSeconds = d
	}
	if sz, err := strconv.ParseInt(raw.Format.Size, 10, 64); err == nil {
		info.SizeBytes = sz
	}
	return info, nil
}

// HLSArgs are the parameters for building an HLS-producing ffmpeg command.
type HLSArgs struct {
	Input       string // local input path
	OutDir      string // directory to write index.m3u8 + segments into
	Copy        bool   // true => remux (-c copy); false => transcode to H.264/AAC
	MaxHeight   int    // transcode: scale down to at most this height (0 = source)
	SegmentSecs int    // target HLS segment duration
}

// BuildHLSCommand returns an *exec.Cmd that streams Input into an HLS playlist
// (index.m3u8) plus MPEG-TS segments under OutDir.
func (t Tools) BuildHLSCommand(ctx context.Context, a HLSArgs) *exec.Cmd {
	if a.SegmentSecs <= 0 {
		a.SegmentSecs = 6
	}
	args := []string{
		"-nostdin", "-y",
		"-i", a.Input,
	}
	if a.Copy {
		// Remux only: cheap, lossless, requires a client-compatible codec set.
		args = append(args, "-c", "copy")
	} else {
		args = append(args,
			"-c:v", "libx264", "-preset", "veryfast", "-crf", "21",
			"-c:a", "aac", "-ac", "2", "-b:a", "160k",
		)
		if a.MaxHeight > 0 {
			// Scale to MaxHeight, keep aspect ratio, force even width for H.264.
			args = append(args, "-vf", fmt.Sprintf("scale=-2:min(ih\\,%d)", a.MaxHeight))
		}
	}
	args = append(args,
		"-f", "hls",
		"-hls_time", strconv.Itoa(a.SegmentSecs),
		"-hls_list_size", "0",
		"-hls_playlist_type", "event",
		"-hls_segment_type", "mpegts",
		"-hls_segment_filename", a.OutDir+"/seg_%05d.ts",
		a.OutDir+"/index.m3u8",
	)
	return exec.CommandContext(ctx, t.FFmpeg, args...)
}
