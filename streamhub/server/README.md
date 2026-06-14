# StreamHub Server

The StreamHub backend (Phase 1): a single Go binary that scans a media library,
serves a JSON API, and streams video as **HLS** to web/Roku/Android TV clients.

See [`../docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md) for the design and
[`../docs/ROADMAP.md`](../docs/ROADMAP.md) for what's coming next.

## What works today (Phase 1)

- **Library scan** of video files with metadata (TMDB when an API key is set,
  otherwise parsed from filenames) stored in SQLite.
- **Auth**: username/password login → JWT; a bootstrap admin from config.
- **Playback decision engine**: direct-play (remux) when the source is
  client-compatible, otherwise FFmpeg transcode to H.264/AAC.
- **HLS streaming** via on-the-fly FFmpeg sessions.
- **Progress/resume** per user.

Single HLS rendition only for now; the adaptive-bitrate ladder, music, photos,
and cloud/object-storage backends come in later phases.

## Requirements

- **Go 1.25+** to build (pure-Go SQLite, so no cgo/C toolchain needed).
- **FFmpeg + ffprobe** on `PATH` at runtime (bundled in the Docker image).

## Run with Docker (recommended)

The image builds the web app and serves it alongside the API on a single port,
so one command gives you a working UI:

```sh
cd ../deploy
STREAMHUB_ADMIN_PASSWORD=yourpass \
STREAMHUB_JWT_SECRET=$(openssl rand -hex 32) \
MEDIA_DIR=/path/to/your/media \
docker compose up --build
```

Then open **http://localhost:8080** — or **http://&lt;your-LAN-IP&gt;:8080** from
a phone/TV on the same network. Log in with the admin credentials above.

## Run from source

```sh
export STREAMHUB_ADMIN_PASSWORD=yourpass
export STREAMHUB_JWT_SECRET=$(openssl rand -hex 32)
export STREAMHUB_MEDIA_DIRS=/path/to/your/media
go run ./cmd/streamhub
```

To also serve the web UI from the running binary (one URL), build the web app
and point `STREAMHUB_WEB_DIR` at it:

```sh
(cd ../clients/web && npm install && npm run build)
STREAMHUB_WEB_DIR=../clients/web/dist go run ./cmd/streamhub
# UI + API on http://localhost:8080
```

Configuration is environment-driven; see [`.env.example`](.env.example).

## Try it

```sh
# Log in
TOKEN=$(curl -s -X POST localhost:8080/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"yourpass"}' | jq -r .token)

# Trigger a scan and list movies
curl -s -X POST localhost:8080/api/library/scan -H "Authorization: Bearer $TOKEN"
curl -s "localhost:8080/api/items?type=movie" -H "Authorization: Bearer $TOKEN" | jq

# Get an item's playback decision, then play it (VLC opens the HLS stream)
ID=...   # an id from the list above
curl -s "localhost:8080/api/items/$ID/playback-info" -H "Authorization: Bearer $TOKEN" | jq
vlc "http://localhost:8080/api/items/$ID/hls.m3u8?token=$TOKEN"
```

## Layout

```
server/
├── cmd/streamhub/      # entrypoint + wiring
├── internal/
│   ├── api/            # HTTP routes & handlers
│   ├── auth/           # JWT, bcrypt, user store, middleware
│   ├── config/         # env-driven configuration
│   ├── db/             # SQLite open + schema
│   ├── ffmpeg/         # ffprobe + HLS command builders
│   ├── library/        # repository + scanner
│   ├── metadata/       # filename parsing + TMDB
│   ├── models/         # domain types
│   ├── storage/        # Storage interface + local FS adapter
│   ├── stream/         # playback decision engine + HLS session manager
│   └── util/           # ID/token helpers
└── Dockerfile
```

## Test

```sh
go test ./...
```
