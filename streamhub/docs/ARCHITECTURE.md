# StreamHub — Architecture

> Status: **Draft for review.** Nothing here is built yet. Comment / revise freely.

## 1. Goals & constraints

- **Mixed media:** one unified library covering **video** (movies/TV), **music/audio**, and **photos/home video**.
- **Host-agnostic:** the *same* backend runs as
  - a **home server** on a LAN (NAS / PC / mini-PC, streaming to devices in the house), and
  - a **cloud deployment** (VM or container platform) streaming over the internet.
- **Three clients:** Web, Roku, Android TV — all thin, all driven by one API.
- **Stream once, play everywhere:** clients should not need to transcode. The server adapts
  the media to what each client can play.

## 2. The central design choice: standardize on HLS

The hardest part of multi-platform streaming is that each platform supports a different set
of containers/codecs. Rather than special-case each client, we make the **server** responsible
for producing a format every client can consume.

**HLS (HTTP Live Streaming) is that common denominator:**

| Client | HLS support |
| --- | --- |
| Web | via `hls.js` (or native on Safari) |
| Android TV | native in Media3 / ExoPlayer |
| Roku | most mature playback path in the SceneGraph `Video` node for clear content |

So: **the backend serves HLS** (fMP4/CMAF segments), and clients are mostly "fetch playlist → play."

Two server paths to produce HLS:

1. **Direct play / remux** — if the source file's codecs already match the client's
   capabilities, we just *remux* (repackage) into HLS without re-encoding. Cheap, near-instant,
   no quality loss. This is the common case and should be the default whenever possible.
2. **Transcode** — when the source codec/container/bitrate is incompatible (or bandwidth is
   constrained), **FFmpeg** re-encodes on the fly to an HLS **adaptive bitrate ladder**
   (e.g. 480p/720p/1080p/4K at ~2/5/10/20 Mbps). Hardware acceleration (Intel QSV, NVIDIA
   NVENC, VAAPI) is used when available to keep CPU cost down.

**Capability negotiation:** each client sends a *device profile* (supported codecs, max
resolution, audio channels, available bandwidth). The server's **playback decision engine**
picks direct-play vs. transcode and which ladder rungs to expose.

> **DRM is explicitly out of scope for v1.** If we later need DRM, note that Roku requires
> **DASH + Widevine** (its Widevine path does not work over HLS), so DRM content would use a
> parallel DASH pipeline. Designing the streaming layer around a pluggable "packager"
> interface keeps that door open without paying for it now.

Codec targets: **H.264** (universal baseline) and **HEVC/H.265** (efficiency, supported on
modern Roku & Android TV). AV1 is a future nice-to-have (DASH-only on Roku).

## 3. High-level system diagram

```
                         ┌───────────────────────────────────────────┐
                         │                 BACKEND                     │
                         │  (single Go binary; runs local OR cloud)    │
   media files           │                                             │
  (local FS or  ───────▶ │  Scanner ─▶ Metadata ─▶ Library DB          │
   S3 bucket)            │     │          (TMDB/                       │
                         │     │        MusicBrainz/EXIF)              │
                         │     ▼                                       │
                         │  Playback Decision Engine                   │
                         │     │                                       │
                         │     ▼                                       │
                         │  Streaming service  ◀── FFmpeg (remux /     │
                         │  (HLS playlists +        transcode, HW       │
                         │   fMP4 segments)         accel)              │
                         │     ▲                                       │
                         │  REST/JSON API  +  Auth (JWT, device pairing)│
                         └────────────┬────────────────────────────────┘
                                      │  HTTPS (one OpenAPI contract)
            ┌─────────────────────────┼─────────────────────────┐
            ▼                         ▼                         ▼
      ┌──────────┐             ┌──────────────┐          ┌──────────────┐
      │  Web app │             │  Android TV  │          │    Roku      │
      │ React/TS │             │ Compose+TV / │          │ SceneGraph / │
      │  hls.js  │             │  Media3      │          │ BrightScript │
      └──────────┘             └──────────────┘          └──────────────┘
```

## 4. Backend components

The backend is the bulk of the work. Proposed as a **single statically-linked Go binary**
(see §7 for why) exposing a REST/JSON API.

- **Library scanner** — walks the configured media roots (or object-storage prefixes),
  detects new/changed/removed items, and feeds the metadata pipeline. Filesystem watcher for
  near-real-time updates locally; scheduled re-scan for cloud/object storage.
- **Metadata service** — enriches items:
  - Video → **TMDB** (posters, descriptions, cast, episode data)
  - Music → **MusicBrainz** + embedded tags (album/artist/track, cover art)
  - Photos → **EXIF** (date, geo, camera), perceptual grouping into albums
- **Library database** — canonical model of items, collections, users, watch state.
  - **SQLite** for the single-binary home deployment (zero-config).
  - **PostgreSQL** option for cloud / multi-user / high concurrency.
  - Accessed through a repository interface so the choice is a config flag.
- **Storage abstraction** — `local filesystem` *or* `S3-compatible object storage` behind one
  interface. **This is the key enabler of the "local or cloud" requirement.**
- **Playback decision engine** — given an item + a device profile, decides direct-play vs.
  transcode and builds the HLS variant list.
- **Streaming service** — generates HLS master/media playlists and fMP4 segments; orchestrates
  FFmpeg; caches transcoded segments; supports seeking/trick-play and adaptive bitrate.
- **Auth & accounts** — JWT-based sessions; multiple users/profiles; **device pairing** for TV
  clients (TV shows a short code; user enters it on a web page to authorize the device — the
  standard "activate on TV" flow, since typing passwords on a remote is painful).
- **API layer** — REST/JSON, documented by a single **OpenAPI spec** in `shared/openapi.yaml`.

## 5. Unified media model (mixed media)

One generic `LibraryItem` with a `type` discriminator so the same browse/search/playback
plumbing serves all media:

| Type | Plays as | Notes |
| --- | --- | --- |
| `movie`, `episode` | HLS video | full direct-play/transcode pipeline |
| `track`, `album` | HLS audio (or direct AAC/FLAC) | lighter pipeline; gapless later |
| `photo` | image API + generated thumbnails | slideshow; HEIC→JPEG conversion |
| `home_video` | HLS video | same as video, no rich metadata |

Collections (TV show → seasons → episodes, artist → albums → tracks, photo albums) are modeled
as parent/child relationships on the same item table.

## 6. Clients

All three are **thin** — they render library data from the API and play HLS. No client does
its own transcoding.

### Web (`clients/web/`)
- **React + TypeScript + Vite.**
- Player: **`hls.js`** (consider **Shaka Player** if we later add DASH/DRM).
- Responsibilities: login, browse/search, detail pages, player with resume, settings.
- Doubles as the **admin UI** (library config, users, device pairing approval).

### Android TV (`clients/androidtv/`)
- **Kotlin + Jetpack Compose for TV** (Leanback is legacy; Compose for TV is the current path).
- Player: **AndroidX Media3 / ExoPlayer** (1.6+), `MediaSession` for system/remote integration.
- D-pad-first navigation, focus handling, leanback launcher integration.
- Auth via device-pairing code flow.

### Roku (`clients/roku/`)
- **BrightScript + SceneGraph** (the only option on Roku).
- HLS playback via the `Video` node; grid/poster UI via `RowList`/`MarkupGrid`.
- Stricter constraints (no client transcode, specific ABR bitrate guidance ~8/10/15/20 Mbps),
  so the server's HLS output must be Roku-friendly. Requires a Roku developer account to
  sideload/publish.

## 7. Host-agnostic design (local **and** cloud)

The "runs anywhere" requirement is met by three abstractions + 12-factor config:

| Concern | Home / local | Cloud |
| --- | --- | --- |
| Storage | local filesystem | S3-compatible object storage |
| Database | SQLite (embedded) | PostgreSQL |
| Networking | LAN + optional mDNS discovery; optional reverse proxy for remote | public TLS endpoint behind a reverse proxy / load balancer |
| Transcode | local CPU/GPU | CPU, or GPU instances; segment cache offloaded to object storage |

- **Single static Go binary** → trivial to drop on a NAS/mini-PC *and* to containerize for the
  cloud, with **no runtime dependency except FFmpeg**. (This is the main reason to prefer Go
  over Node/Python for the backend — see DECISIONS.)
- **Docker + docker-compose** for the local "just works" path; container image + IaC for cloud.
- **Remote access** for the home case: documented reverse-proxy setup (Caddy/Traefik with
  automatic TLS); a hosted relay is a possible later add-on for users who can't port-forward.

## 8. Cross-cutting concerns

- **API contract first:** author `shared/openapi.yaml`, then generate typed clients (TS for web,
  Kotlin for Android TV) so the contract can't silently drift. Roku is hand-written against it.
- **Security:** JWT with short-lived access + refresh; per-device tokens (revocable); signed,
  time-limited stream URLs so media links can't be freely shared; TLS everywhere for remote.
- **Observability:** structured logs, transcode metrics (sessions, CPU/GPU, cache hit rate),
  health endpoints.
- **Testing:** API contract tests against the OpenAPI spec; transcode smoke tests with sample
  media; client UI tests where practical.

## 9. Tech stack summary

| Layer | Choice | Rationale |
| --- | --- | --- |
| Backend | **Go** + FFmpeg | single static binary, strong concurrency for streaming, low footprint on a NAS, easy to containerize |
| DB | SQLite → PostgreSQL | zero-config locally, scalable in cloud |
| Storage | local FS / S3 | the local-or-cloud enabler |
| Streaming | HLS (fMP4/CMAF) | universal across web/Roku/Android TV |
| Web | React + TS + Vite + hls.js | mature, fast, shared TS types |
| Android TV | Kotlin + Compose for TV + Media3 | current Google-recommended stack |
| Roku | BrightScript + SceneGraph | only option on the platform |
| API | OpenAPI-first REST/JSON | one contract, generated clients |

Alternatives and the reasoning for these picks are recorded in
[`DECISIONS.md`](DECISIONS.md). The backend language in particular is worth a conscious choice
(Go vs. Node/TypeScript vs. C#/.NET like Jellyfin).
