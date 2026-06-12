# StreamHub *(working title)*

A self-hostable, host-agnostic media server for **mixed media** (video, music, photos)
with first-class clients for the **web**, **Roku**, and **Android TV**.

Think "your own Plex/Jellyfin" — one backend that can run on a home box on your LAN
*or* in the cloud for streaming over the internet, feeding thin clients that all speak
the same API and stream the same format (HLS).

> ⚠️ This directory currently contains **planning artifacts only**. No application code
> has been written yet. The docs below are meant to be reviewed and revised before we
> start building. See [`docs/ROADMAP.md`](docs/ROADMAP.md) for the phased plan.

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
