# StreamHub — Phased Roadmap

> Status: **Draft for review.** Phases are sequenced so something is usable as early as
> possible: a working **server + web player** comes before the TV apps, because the TV apps
> depend on a stable API and a proven streaming pipeline.

Each phase lists **deliverables** and **acceptance criteria** (what "done" means). Phases are
deliberately shippable on their own.

---

## Phase 0 — Foundations *(this PR)*
**Goal:** agree on the plan and lay down the skeleton.

- Deliverables
  - This architecture + roadmap + decisions doc set.
  - Repo scaffolding (`server/`, `clients/`, `shared/`, `deploy/`) — *added once the plan is approved.*
  - First cut of `shared/openapi.yaml` (auth, library browse, stream endpoints).
- Acceptance
  - You've reviewed the plan and signed off on the **Build vs. Buy** and **backend language** decisions.

## Phase 1 — Backend MVP (video, local)
**Goal:** a server that can scan a folder of video and stream it as HLS.

- Deliverables
  - Library scanner for video; TMDB metadata; SQLite library DB.
  - Local-filesystem storage adapter.
  - Auth (login → JWT) with a single admin user.
  - Streaming service: **HLS direct-play/remux** + basic FFmpeg transcode fallback.
  - Playback decision engine (v1: direct-play when possible, else single transcode profile).
  - Runs via `docker-compose up` against a mounted media folder.
- Acceptance
  - `GET /library` returns scanned movies with metadata.
  - A movie streams as HLS and plays in VLC/`ffplay` and a browser; an incompatible-codec file
    transcodes and plays.

## Phase 2 — Web app
**Goal:** a real, usable client for the Phase 1 backend.

- Deliverables
  - React + TS app: login, library grid, detail pages, **hls.js** player.
  - Playback progress + resume; basic search.
  - Serves as the admin UI (library paths, rescan, users).
- Acceptance
  - End-to-end: log in → browse → play a movie in the browser → close → resume from the same spot.

## Phase 3 — Mixed media complete (music + photos)
**Goal:** deliver on the "mixed media" requirement end to end.

- Deliverables
  - Backend: music pipeline (MusicBrainz + tags, HLS/direct audio) and photo pipeline
    (EXIF, thumbnails, HEIC→JPEG, albums).
  - Web: music player (queue, album/artist views) and photo browser (grid + slideshow).
- Acceptance
  - All three media types are browsable and playable from the web app.

## Phase 4 — Android TV app
**Goal:** living-room client #1.

- Deliverables
  - Kotlin + Compose for TV; Media3/ExoPlayer HLS playback.
  - **Device-pairing** auth (code on TV → approve on web).
  - D-pad navigation across video/music/photos; resume; search.
  - Generated Kotlin API client from the OpenAPI spec.
- Acceptance
  - Pair a TV, browse the library, play video and music with working resume and remote controls.

## Phase 5 — Roku app
**Goal:** living-room client #2.

- Deliverables
  - BrightScript + SceneGraph app; HLS playback via `Video` node.
  - Device-pairing auth; poster-grid browse for video/music/photos.
  - Verify the server's HLS output meets Roku's ABR/codec guidance; adjust ladder if needed.
- Acceptance
  - Sideload to a Roku device, pair it, and play video with seeking/resume.

## Phase 6 — Cloud + remote streaming
**Goal:** make the "host on the web" path first-class.

- Deliverables
  - PostgreSQL and S3-compatible storage adapters.
  - Container image + deploy recipe (one cloud target, e.g. a VM or container platform).
  - Reverse-proxy + automatic-TLS guide for self-hosters who want remote access.
  - Full **adaptive bitrate ladder** + hardware-accelerated transcode (QSV/NVENC/VAAPI);
    transcoded-segment caching (optionally to object storage).
  - Signed, time-limited stream URLs.
- Acceptance
  - The same build streams over the internet to web + both TV apps with ABR adapting to bandwidth.

## Phase 7 — Polish & multi-user
**Goal:** the things that make it pleasant and shareable.

- Deliverables (prioritize with you)
  - Multiple users/profiles; per-user watch history & resume sync across devices.
  - Subtitles (external + embedded) and audio-track selection.
  - Global search across media types; recommendations/"continue watching" rows.
  - Optional: offline downloads (mobile/TV), gapless audio, AV1, **DRM** (DASH+Widevine — see Architecture §2).
- Acceptance
  - Two users have independent libraries/history; subtitles and multi-audio work on all clients.

---

## Sequencing rationale & dependencies

- The **API contract (OpenAPI)** is authored in Phase 0/1 and is the spine everything hangs off —
  TV clients (Phases 4–5) consume generated clients from it, so it must stabilize first.
- **Web before TV:** the browser is the fastest place to prove the streaming pipeline and to
  build the admin/pairing UI the TV apps need.
- **Cloud (Phase 6) after a working local stack:** the storage/DB abstractions are designed in
  from day one (Architecture §7), but we validate them locally before paying cloud complexity.

## Rough effort shape (not a commitment)

| Phase | Relative size |
| --- | --- |
| 1 Backend MVP | Large |
| 2 Web app | Medium |
| 3 Music + Photos | Medium |
| 4 Android TV | Large |
| 5 Roku | Medium-Large |
| 6 Cloud + remote | Medium |
| 7 Polish | Ongoing |

The two TV apps are the biggest swings because each is a separate language/SDK with
device-specific testing. If timeline matters, the **Build vs. Buy** decision (see
`DECISIONS.md`) is most impactful precisely *because* it can eliminate the TV-client work.
