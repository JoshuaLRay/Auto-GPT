# StreamHub — Open Decisions

Things to confirm before/while we build. Each has a **recommendation** so you can just say
"go with the recommendations" if you agree.

---

## D1 — Build vs. Buy *(decide first — it changes everything)*

**Jellyfin** is a mature, open-source media server that already does most of what's described
here, **including existing Roku and Android TV clients**, on-the-fly FFmpeg transcoding with
hardware acceleration, and self-host-or-cloud deployment.

- **Buy/adopt:** fork or deploy Jellyfin and customize. Fastest path to "it works." You'd spend
  time on configuration, theming, and any custom client tweaks — not on building a streaming
  engine from scratch.
- **Build (this plan):** full ownership, your own API/UX, a learning project, or requirements
  Jellyfin can't meet. Costs months, especially the two TV clients.

**Recommendation:** decide consciously based on your *goal*. If the goal is "stream my library
to my TVs soon," strongly consider Jellyfin. If the goal is to own/build/learn the system,
proceed with the custom plan. (You chose "plan first," so this doc assumes custom unless you
say otherwise — but I'd be doing you a disservice not to flag this.)

## D2 — Backend language

- **Go (recommended):** single static binary (no runtime to install on a NAS), great concurrency
  for many simultaneous streams, easy to containerize. Pairs with FFmpeg as an external process.
- **Node/TypeScript:** shares a language with the web client and the generated API types; huge
  ecosystem; slightly heavier runtime footprint.
- **C#/.NET:** what Jellyfin uses; excellent media tooling; heavier footprint than Go.

**Recommendation:** **Go**, because the "drop it on a home box *or* a cloud container with no
dependencies" requirement is exactly Go's sweet spot.

## D3 — Streaming format

**Recommendation:** **HLS (fMP4/CMAF)** as the single delivery format for v1 (universal across
web/Roku/Android TV). Keep the packager pluggable so **DASH+Widevine** can be added later *if*
DRM is ever required (Roku needs DASH for Widevine).

## D4 — Metadata sources

- Video: **TMDB** (free API key required).
- Music: **MusicBrainz** + embedded tags.
- Photos: **EXIF** (local, no external service).

**Recommendation:** as above. Note TMDB requires you to register a free API key; we'll make it
configurable.

## D5 — Local repo home

This is scaffolded inside the Auto-GPT repo on a feature branch. Options:

- Keep it in `streamhub/` here for now (simplest while iterating).
- Split into a dedicated repository once it has real code.

**Recommendation:** keep it here through Phase 1, then split to its own repo before it grows.

## D6 — Authentication / device pairing

**Recommendation:** JWT (access + refresh) for web; **device-pairing code flow** for Roku &
Android TV (TV shows a code → user approves it on a web page), since typing credentials on a TV
remote is miserable.

## D7 — Name

"StreamHub" is a placeholder. Pick a real name when you're ready — it affects package names,
app IDs (Android/Roku), and store listings, so earlier is cheaper than later.

---

### Quick sign-off

If you're happy with the recommendations, just say **"go with the recommendations"** (or tell me
which to change), and I'll start **Phase 1** by scaffolding the backend and the OpenAPI contract.
The single most consequential answer is **D1 (Build vs. Buy)**.
