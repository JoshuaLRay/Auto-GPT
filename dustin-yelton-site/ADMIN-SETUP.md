# Letting Dustin edit the site — `/admin` setup

The site now has a built-in content editor at **`/admin`** (e.g.
`https://your-site.netlify.app/admin/`), powered by **Sveltia CMS** — a modern,
phone-friendly editor. Dustin logs in, edits friendly forms ("Hero headline,"
"Phone number," "Add a photo"), hits publish, and Netlify rebuilds the site in
~30 seconds. He never touches code or files.

## How content flows

```
Dustin edits at /admin  →  saves to data files on GitHub (behind the scenes)
                        →  Netlify rebuilds with Eleventy  →  live site updates
```

All editable text/photos live in `src/_data/*.json`. The editor writes to those
files; the page templates in `src/*.njk` render them.

## One-time login setup (do this once; easier on a computer)

The editor signs in through GitHub. Using the editor afterward is fully
mobile-friendly — only this initial wiring is fiddly on a phone.

**Step 1 — Give Dustin access.**
- Dustin creates a free GitHub account (he'll never see code — just the editor).
- In the repo: **Settings → Collaborators → Add people** → add his username with
  **Write** access. (Repo: `JoshuaLRay/Auto-GPT`.)

**Step 2 — Create a GitHub OAuth App.**
- GitHub → **Settings → Developer settings → OAuth Apps → New OAuth App**.
- Homepage URL: your live site URL.
- Authorization callback URL: `https://<your-auth-worker>.workers.dev/callback`
  (you'll get this URL in Step 3 — you can come back and fill it in).
- Save the **Client ID** and generate a **Client Secret**.

**Step 3 — Deploy the free auth helper (Cloudflare Worker).**
Sveltia publishes a tiny auth worker so logins are secure without running your
own server. Follow its README (deploy to Cloudflare's free tier):
<https://github.com/sveltia/sveltia-cms-auth>
- Set the worker's secrets to your **Client ID** and **Client Secret** from Step 2.
- Set `ALLOWED_DOMAINS` to your Netlify domain.
- Copy the worker's URL (e.g. `https://sveltia-cms-auth.<you>.workers.dev`).

**Step 4 — Point the CMS at the worker.**
- In `src/admin/config.yml`, uncomment and set:
  ```yaml
  backend:
    name: github
    repo: JoshuaLRay/Auto-GPT
    branch: claude/squarespace-dustin-yelton-poc-doh4b6
    base_url: https://sveltia-cms-auth.<you>.workers.dev
  ```
- Commit that change (or tell me and I'll do it once you have the worker URL).

**Step 5 — Test.**
- Visit `https://your-site.netlify.app/admin/` on your phone, click **Login with
  GitHub**, authorize, and you should see the editor with all the pages listed.
- Make a tiny edit, publish, wait ~30s, and confirm the live site updated.

## Notes

- **Mobile:** once logged in, Sveltia works well on a phone — that was the goal.
- **Photos:** uploads go to `src/images/uploads/` and are inserted automatically.
- **Safety:** every edit is a normal Git commit, so nothing is ever truly lost —
  any change can be rolled back.
- If you'd rather avoid GitHub logins entirely, the alternative is a hosted
  headless CMS (Sanity/Storyblok) — more setup, but Dustin gets an
  email/password login. Ask and I'll lay out that path.
