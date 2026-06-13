# Dustin Yelton Painting & Cleaning — Website

A 5-page website for a Northern Kentucky painter & cleaner, built with
**Eleventy (11ty)** and editable by a non-technical owner through
**[Pages CMS](https://pagescms.org)** — a hosted, mobile-friendly editor he
signs into with GitHub (no self-hosted login to maintain).

## How it's structured

```
dustin-yelton-site/
├─ src/
│  ├─ _data/        ← all editable content (JSON: site, home, painting, …)
│  ├─ _includes/    ← shared header, footer, and blocks.njk (section renderer)
│  ├─ *.njk         ← page templates (render the data)
│  └─ css/ js/ images/
├─ _site/           ← generated output (git-ignored; Netlify builds this)
├─ .eleventy.js     ← Eleventy config
└─ package.json
../.pages.yml       ← Pages CMS configuration (lives at the repo root)
```

**Editing content (owner):** sign in at <https://app.pagescms.org> with GitHub,
open this repo on the working branch, and edit the friendly forms.
**Editing content (developer):** edit the JSON in `src/_data/` directly.
The HTML design lives untouched in `src/css/styles.css`.

### Modular sections (Path C)

The **Home page** uses a modular `blocks` model: `src/_data/home.json` holds a
`blocks` array, and `src/_includes/blocks.njk` renders each block by its `type`
(hero, cards, gallery, testimonial, text, cta). In Pages CMS these appear under
*Home Page → Page Sections*, where they can be reordered, added, removed, or
hidden. Other pages can be migrated to the same model.

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

1. **Phone / email / business name** — Pages CMS → *Site Settings*, or
   `src/_data/site.json`.
2. **Photos** — add via Pages CMS (work strip, before/after, portrait, art).
3. **Band name** — Pages CMS → *About Page* → Creative paragraph.
4. **Licensing language** — confirm license #, insurance, EPA Lead-Safe before
   publishing those claims.
5. **Contact form** — set a Formspree endpoint in `src/contact.njk`, or switch
   to Netlify Forms.
6. **Map** — embed a Google Map on the contact page.

See also `../squarespace-kit/` (Squarespace alternative) and
`../DUSTIN-YELTON-LAUNCH-ROADMAP.md` (business setup).
