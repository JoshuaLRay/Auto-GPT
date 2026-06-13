# Dustin Yelton Painting & Cleaning — Proof of Concept

A complete, working 5-page website for a Northern Kentucky painter & cleaner.
Pure HTML/CSS/JS — **no build step, no framework, no dependencies.** Open
`index.html` in any browser and the whole site works.

## Pages

| File | Purpose |
|------|---------|
| `index.html` | Home — hook, three service tiles, recent-work strip, testimonial, CTA |
| `painting.html` | Painting services, process, before/after, service area, licensing |
| `cleaning.html` | Residential cleaning + commercial/custodial, frequency options |
| `about.html` | Dustin's bio + the "music & art coming soon" creative section |
| `contact.html` | Free-estimate form, phone/email/hours, service-area map slot |

Design lives in `css/styles.css` (all colors/fonts are CSS variables at the
top — change those to rebrand). Behavior is in `js/main.js` (mobile menu +
form handling). Hero artwork is `images/hero.svg`.

## Preview locally

```bash
cd dustin-yelton-site
python3 -m http.server 8080
# open http://localhost:8080
```

Or just double-click `index.html`.

## Before launch — replace these placeholders

Everything that needs real data is flagged in-page with a yellow `PLACEHOLDER`
/ `VERIFY` / `SETUP` tag. The big ones:

1. **Phone number** — find/replace `(859) 555-0123` and `+18595550123`.
2. **Email** — find/replace `hello@dustinyelton.com`.
3. **Business name** — currently "Dustin Yelton Painting & Cleaning".
4. **Band name** — `[Band Name]` on `about.html`.
5. **Photos** — work-strip tiles, before/after, portrait, art thumbnails.
6. **Licensing language** — confirm license #, insurance, EPA Lead-Safe RRP
   before publishing those claims.
7. **Contact form** — paste a real [Formspree](https://formspree.io) endpoint
   into the `action` of `#estimate-form` (free tier emails submissions
   straight to Dustin). Until then the form runs in safe "demo mode."
8. **Map** — embed a Google Map of the service area on `contact.html`.

## Deploy (pick one — all free, no credit card)

**Netlify Drop (fastest, ~60 seconds):**
Go to <https://app.netlify.com/drop> and drag the `dustin-yelton-site` folder
onto the page. You get a live URL instantly to share with Dustin.

**GitHub Pages:** push this repo, then Settings → Pages → deploy from branch,
folder `/dustin-yelton-site`. (Note: this is the simplest if it's its own repo;
in a subfolder of a larger repo you may prefer Netlify/Cloudflare.)

**Cloudflare Pages / Vercel:** connect the repo, set the output/root directory
to `dustin-yelton-site`, no build command. Both have generous free tiers.

## Why a static site for the POC?

It's something that can be built end-to-end and shown to Dustin *today* — free,
fast, zero maintenance. It also doubles as the visual + content spec for the
Squarespace build (see `../squarespace-kit/`) if that's the production path he
chooses.
