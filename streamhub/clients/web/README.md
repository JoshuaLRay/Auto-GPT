# StreamHub Web

The StreamHub web client (Phase 2): a React + TypeScript + Vite app that logs in,
browses the library, and plays video as **HLS** via `hls.js`, with resume and
search. It also exposes the admin **Scan** control.

See [`../../docs/ROADMAP.md`](../../docs/ROADMAP.md) for what's next (music/photos
UI in Phase 3).

## Requirements

- Node 20+ (developed on Node 22).
- A running [StreamHub server](../../server/README.md) on `http://localhost:8080`.

## Develop

```sh
npm install
npm run dev          # http://localhost:5173
```

The dev server proxies `/api` and `/healthz` to `http://localhost:8080`, so the
browser talks to a single origin (no CORS, and HLS segment URLs resolve cleanly).

Log in with the admin credentials you configured on the server
(`STREAMHUB_ADMIN_USER` / `STREAMHUB_ADMIN_PASSWORD`).

## Build

```sh
npm run build        # type-checks (tsc) then bundles to dist/
npm run preview      # serve the production build locally
```

## Configuration

| Env var | Default | Purpose |
| --- | --- | --- |
| `VITE_API_BASE` | `""` (same origin) | Point a production build at a remote server, e.g. `https://media.example.com`. In dev, leave empty and rely on the proxy. |

## What's here

```
src/
├── api/client.ts         # typed fetch wrapper over the server API
├── auth/AuthContext.tsx  # token storage + startup validation
├── components/           # Layout, ItemCard, ProtectedRoute
├── pages/                # Login, Library, Detail, Player
├── util/format.ts        # duration/clock formatting
└── types.ts              # mirrors shared/openapi.yaml
```

## Notes & known limitations (Phase 2)

- **Video only** in the UI for now; music and photo views land in Phase 3.
- Seeking past the not-yet-transcoded portion of a stream may stall — the server
  emits a single growing HLS playlist; adaptive bitrate + better seek come in
  Phase 6.
- The JS bundle is dominated by `hls.js`; code-splitting is a later optimization.
