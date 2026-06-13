# Dustin Yelton Painting & Cleaning — Website

A 5-page website for a Northern Kentucky painter & cleaner, built with
**Eleventy (11ty)** and editable by a non-technical owner through a built-in,
mobile-friendly CMS at **`/admin`**.

## How it's structured

```
dustin-yelton-site/
├─ src/
│  ├─ _data/        ← all editable content (JSON: site, home, painting, …)
│  ├─ _includes/    ← shared header + footer
│  ├─ *.njk         ← page templates (render the data)
│  ├─ css/ js/ images/
│  └─ admin/        ← Sveltia CMS (the /admin editor) + config.yml
├─ _site/           ← generated output (git-ignored; Netlify builds this)
├─ .eleventy.js     ← Eleventy config
└─ package.json
```

**Editing content:** non-technical owners use `/admin` (see `ADMIN-SETUP.md`).
**Editing content as a developer:** just edit the JSON in `src/_data/`.
The HTML design lives untouched in `src/css/styles.css`.

## Local development

```bash
cd dustin-yelton-site
npm install
npm run dev      # live preview at http://localhost:8080
# or
npm run build    # outputs to _site/
```

## Deploying (Netlify)

Already configured in `../netlify.toml`: base `dustin-yelton-site`, build
`npm run build`, publish `_site`. Push to the branch and Netlify rebuilds.

## Setup checklist (placeholders to replace)

1. **Phone / email / business name** — edit in `/admin` → *Site-wide Settings*,
   or in `src/_data/site.json`.
2. **Photos** — add via `/admin` (work strip, before/after, portrait, art).
3. **Band name** — `/admin` → *About Page* → Creative paragraph.
4. **Licensing language** — confirm license #, insurance, EPA Lead-Safe before
   publishing those claims.
5. **Contact form** — set a Formspree endpoint in `src/contact.njk`, or switch
   to Netlify Forms.
6. **Map** — embed a Google Map on the contact page.
7. **Admin login** — follow `ADMIN-SETUP.md` to enable `/admin`.

See also `../squarespace-kit/` (Squarespace alternative) and
`../DUSTIN-YELTON-LAUNCH-ROADMAP.md` (business setup).
