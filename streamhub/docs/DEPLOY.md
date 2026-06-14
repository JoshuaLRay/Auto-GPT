# Deploying StreamHub to the cloud

This guide gets StreamHub running on the public internet so you can stream to
your phone (or any device) over HTTPS. It's written for the **free, phone-only**
path on **Render**, with notes on making it persistent and on other hosts.

## What "free" gets you (read this first)

| | Free (Render free tier) | Persistent (paid) |
| --- | --- | --- |
| Cost | $0 | ~$7/mo + disk |
| HTTPS | ✅ automatic | ✅ automatic |
| Set up from a phone | ✅ web dashboard | ✅ web dashboard |
| Keeps your media/DB across restarts | ❌ ephemeral | ✅ persistent disk |
| Sleeps when idle (~15 min) | ✅ (cold starts) | ❌ |

Because the free tier is **ephemeral**, StreamHub auto-generates a short **sample
clip** on every boot (when the library is empty) so there's always something to
play. You can also **upload** your own clips from the phone during a session —
just know they'll be gone after the service restarts until you add a disk.

## Deploy to Render from your phone (free)

1. **Push this branch to GitHub** (already done by the agent). The blueprint
   lives at the repo root: [`render.yaml`](../../render.yaml).
2. On your phone, open **https://dashboard.render.com** and sign up (free) — you
   can use "Sign in with GitHub".
3. Tap **New → Blueprint**.
4. Connect the **`JoshuaLRay/Auto-GPT`** repo and pick the branch
   **`claude/streaming-library-multiplatform-xazmzv`**. Render reads `render.yaml`.
5. When prompted, set **`STREAMHUB_ADMIN_PASSWORD`** to a strong password.
   (`STREAMHUB_JWT_SECRET` is generated for you.)
6. Tap **Apply**. Render builds the Docker image (a few minutes) and gives you a
   URL like **`https://streamhub-xxxx.onrender.com`**.
7. Open that URL on your phone, log in as `admin` with the password you set, and
   you'll see the **StreamHub Sample** clip. Tap it → **Play**. 🎉
8. To add your own video: tap **Upload** (top bar), pick a file from your phone,
   wait for it to process, and it appears in the library.

> First open after idle may take ~30–60s while the free service wakes up.

## Make it persistent (when you're ready to pay a little)

On Render, edit `render.yaml` (or the service settings):

```yaml
    plan: starter            # instead of free
    disk:
      name: streamhub-data
      mountPath: /data       # SQLite DB + transcode cache survive restarts
      sizeGB: 10
```

For media that survives too, point `STREAMHUB_MEDIA_DIRS` at a path on that disk
(e.g. `/data/media`) so uploads persist. Then remove
`STREAMHUB_GENERATE_SAMPLE` if you don't want the sample re-created.

## Free *and* persistent (needs a computer/CLI later)

**Oracle Cloud Always Free** gives a genuinely free VM with persistent storage
and a public IP — enough to run the container with a real disk forever. It needs
SSH to set up, so it's a good option to revisit when you have a computer. The
flow is: create an Always-Free VM → install Docker → run
`deploy/docker-compose.yml` → put Caddy in front for automatic HTTPS.

## Other hosts

- **Railway / Fly.io:** both work with the same Docker image and a small volume
  mounted at `/data` (and your media path). Set `STREAMHUB_ADMIN_PASSWORD` and
  `STREAMHUB_JWT_SECRET`; the server honours the platform's `$PORT`.
- **Any VM:** use [`deploy/docker-compose.yml`](../deploy/docker-compose.yml) and
  a reverse proxy (Caddy/Traefik) for automatic TLS.

## Security notes for a public deployment

- **Always set** a strong `STREAMHUB_ADMIN_PASSWORD` and a stable
  `STREAMHUB_JWT_SECRET` (the blueprint generates the latter).
- Uploads are **admin-only** and size-limited (`STREAMHUB_MAX_UPLOAD_MB`,
  default 4096).
- Stream URLs currently rely on an unguessable session ID as the capability.
  **Signed, time-limited stream URLs** are planned hardening (roadmap Phase 6/7);
  fine for personal use, worth adding before sharing widely.
- Only video is supported today; music and photos arrive in Phase 3.
