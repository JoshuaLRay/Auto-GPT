# StreamHub *(working title)*

A self-hostable, host-agnostic media server for **mixed media** (video, music, photos)
with first-class clients for the **web**, **Roku**, and **Android TV**.

Think "your own Plex/Jellyfin" — one backend that can run on a home box on your LAN
*or* in the cloud for streaming over the internet, feeding thin clients that all speak
the same API and stream the same format (HLS).

**Status:** the backend (Phase 1) and web app (Phase 2) are built. Music/photos,
Android TV, and Roku are next — see [`docs/ROADMAP.md`](docs/ROADMAP.md).

## Quick start

Requires [Docker](https://docs.docker.com/get-docker/). FFmpeg is bundled in the image.

```sh
cd deploy
STREAMHUB_ADMIN_PASSWORD=pick-a-password \
STREAMHUB_JWT_SECRET=$(openssl rand -hex 32) \
MEDIA_DIR=/path/to/your/media \
docker compose up --build
```

This serves the API **and** the web UI on one port. Open **http://localhost:8080**
(or **http://&lt;your-LAN-IP&gt;:8080** from a phone/TV on the same Wi-Fi — iOS Safari
plays the streams natively), log in, hit **Scan**, and play.

### No computer? Deploy to the cloud (free)

You can run StreamHub on the public internet and stream to your phone over HTTPS
without a local machine. See **[`docs/DEPLOY.md`](docs/DEPLOY.md)** for a
phone-only, free Render setup. On a fresh deploy it auto-generates a sample clip,
and you can **Upload** your own videos from the phone.

## Why this lives here

This was scaffolded on the `claude/streaming-library-multiplatform-xazmzv` branch of the
Auto-GPT repo. It is an independent project kept in its own top-level directory so it does
not entangle with the existing Auto-GPT Python code. If the project graduates, it can be
split into its own repository cleanly.

## Documents

| Doc | What's in it |
| --- | --- |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | System design, components, streaming strategy, tech choices, host-agnostic design |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Phased delivery plan with milestones and acceptance criteria |
| [`docs/DECISIONS.md`](docs/DECISIONS.md) | Open decisions that need your sign-off before we build |

## The one big decision to make first

Before writing custom code, read the **"Build vs. Buy"** section in
[`docs/DECISIONS.md`](docs/DECISIONS.md). An open-source project (Jellyfin) already does
~80% of this — including Roku and Android TV clients. The custom-build plan below is worth
pursuing if you want full ownership/control or are doing this to learn; if the goal is
"working media streaming ASAP," forking/customizing Jellyfin may save months.

## Proposed repo layout (once we build)

```
streamhub/
├── server/              # Host-agnostic backend (local NAS or cloud)
├── clients/
│   ├── web/             # React + TypeScript web player
│   ├── androidtv/       # Kotlin + Compose for TV + Media3/ExoPlayer
│   └── roku/            # BrightScript + SceneGraph
├── shared/
│   └── openapi.yaml     # The API contract every client is generated from
├── deploy/              # Docker, docker-compose, cloud (Terraform/containers)
└── docs/
```
