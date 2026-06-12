# Croquet Tracker — Web App (PWA)

The same croquet scorer as the native app, rebuilt as a **Progressive Web
App** so you can run it on your iPhone (or any phone) **without a Mac, Xcode,
the App Store, or a developer account**. Open it in Safari, add it to your
Home Screen, and it behaves like an installed app — full screen, its own icon,
and **fully offline** once loaded (handy on a lawn with no signal).

It mirrors the native features:

- **Deadness board** — tap any cell to toggle which ball (row) is dead on
  which (column).
- **Next wicket per ball** — `1 → 6 → 1-back … Rover → Stake`, with a
  **✓ Scored** button that advances the wicket *and* clears deadness, plus a
  **−** button to step back for corrections.
- **Player / team per ball** — editable player names and team names.
- **4-ball / 6-ball toggle** in Settings (6-ball adds Green and Orange);
  switching is non-destructive.

The game is saved to the browser's `localStorage` after every change, so it
survives closing the app.

## Pure HTML/CSS/JS — no build step

```
croquet-web/
  index.html              Markup + PWA meta tags
  styles.css              Styling (light/dark aware)
  app.js                  Game logic, rendering, persistence
  manifest.webmanifest    PWA manifest (name, icons, standalone)
  sw.js                   Service worker (offline app-shell cache)
  icons/                  Generated PNG app icons
  tools/                  Dev-only: icon generator + logic test (not served)
```

Nothing to compile or install. `tools/` is for development only — don't deploy it.

## Get it onto your phone

The app must be served over **HTTPS** (required for "Add to Home Screen" and
offline support). Pick whichever is easiest:

### Option A — Netlify / Cloudflare Pages drop (fastest, ~1 min)
1. Go to https://app.netlify.com/drop (or Cloudflare Pages).
2. Drag the **`croquet-web` folder** onto the page.
3. You get an HTTPS URL. Open it in Safari on your iPhone.

### Option B — GitHub Pages (free, lives with the repo)
1. In the repo on GitHub: **Settings → Pages**.
2. Under **Build and deployment**, choose **Deploy from a branch**, pick the
   branch that has this folder, and save.
3. Your app will be at
   `https://<you>.github.io/<repo>/croquet-web/`.
   (The app uses relative paths, so serving from a subfolder works fine.)

### Then, on your iPhone
1. Open the URL in **Safari** (not Chrome — only Safari can install PWAs on iOS).
2. Tap the **Share** button → **Add to Home Screen** → **Add**.
3. Launch it from the new icon. It now runs full-screen and works offline.

### Local preview on your computer
```bash
cd croquet-web
python3 -m http.server 8000
# open http://localhost:8000
```
`localhost` counts as a secure context, so the service worker and install work
there. Opening the file directly (`file://…`) won't — use a server.

## Dev checks

```bash
node tools/make-icons.js   # regenerate PNG icons
node tools/test-logic.js   # run the game-logic smoke test
```

## Updating the app

When you change `index.html`, `styles.css`, or `app.js`, bump the `CACHE`
version string in `sw.js` (e.g. `croquet-v1` → `croquet-v2`) so installed
copies fetch the new files instead of serving the old cached ones.
