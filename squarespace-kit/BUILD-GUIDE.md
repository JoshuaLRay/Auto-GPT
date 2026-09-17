# Squarespace Build Guide — step by step

Follow top to bottom. Copy text from `COPY.md`, styling from `custom-css.css`,
and use the live static site in `../dustin-yelton-site/` as the visual target.

---

## 0. Before you start

- Have ready: logo or business-name text, phone number, email, 6–10 job
  photos, 1–2 before/after pairs, a portrait of Dustin, optional art images.
- Decide the business name (kit assumes **Dustin Yelton Painting & Cleaning**).

## 1. Create the site

1. Go to squarespace.com → **Get Started**. Skip/important: when it asks what
   you're building, pick *Business → Local services*. It generates a starter
   you'll heavily edit — that's fine.
2. You're now on **Squarespace 7.1** with **Fluid Engine** editing. Good.
3. Don't buy a plan yet — build on the free trial, subscribe before launch.

## 2. Set the brand (Design panel)

- **Design → Colors:** create a palette to match the static site:
  - Navy `#1F2A44`, Navy-deep `#161E33`, Terracotta `#C4623C`,
    Sand `#F4EFE7`, Cream `#FBF9F5`, Ink `#20242C`.
  - Assign Terracotta as the **button / accent** color.
- **Design → Fonts:** Headings = a serif (e.g. *Playfair Display* or
  *Georgia*); Body = a clean sans (e.g. *Inter*, *Work Sans*, or system).
- **Design → Buttons:** set shape to **Pill / fully rounded**.

## 3. Build the navigation + pages

In **Pages**, create these top-level pages (this exact order):

`Home` · `Painting` · `Cleaning` · `About` · `Contact`

- Set **Home** as the homepage.
- In the **header**: brand text on the left ("Dustin Yelton" with
  "Painting & Cleaning" as a subtitle if your header style allows), nav in the
  middle/right, and on the right add the **phone number** + a **"Free Estimate"
  button** linking to Contact. Turn on a **sticky header** so the phone stays
  visible while scrolling.

## 4. Build each page with Fluid Engine sections

For every page: **Edit → Add Section → Blank**, then drop in Text/Button/Image
blocks. Pull all wording from `COPY.md`.

### Home
1. **Hero section** — full-width, dark background image (a painting/clean-room
   photo) with a dark overlay. Add: eyebrow, H1, lead paragraph, four small
   "badge" text items, and two buttons (*Get a Free Estimate*, *Call …*).
2. **Service tiles** — a 3-column section, each column = icon/emoji + H3 +
   paragraph + "See …" link to that service page.
3. **Recent work** — an **Image Gallery** (Grid) section, 6 photos.
4. **Testimonial** — dark (navy) section, one quote + attribution.
5. **CTA band** — terracotta background, headline + two buttons.

### Painting
1. Intro section (eyebrow + H1 + lead + buttons), light-sand background.
2. Two-column "What I paint" / "How a job goes" checklists.
3. Before/After — 2-column image section.
4. Service area list + a "Licensed, insured & lead-safe" callout card.
5. CTA band.

### Cleaning
1. Intro section.
2. Two-column "Residential" / "Frequency options".
3. Navy section: "Commercial & custodial" + a "Request a walkthrough" card.
4. 3-column "Why clients stay".
5. CTA band.

### About
1. Two-column bio + portrait photo.
2. Sand section: "The creative side" — text + a "Music & Art coming soon"
   callout + 3 art thumbnails.
3. 3-column "What you can count on".
4. CTA band.

### Contact
1. Intro section.
2. Two columns: left = **Form block**; right = phone/email/hours/service-area
   text + a **Map block**.
3. CTA band.

## 5. The contact form (built in — no Formspree needed)

1. On Contact, add a **Form block**.
2. Fields: **Name** (required), **Phone** (required), **Email**, **Service
   interested in** (dropdown: Interior Painting / Cabinet Refinishing /
   Residential Cleaning / Commercial-Custodial / Not sure yet), **Project
   details** (text area). Optional: enable file upload for photos (Business
   plan).
3. **Storage → Email:** set it to email submissions to Dustin's address.
   Send a test and confirm it arrives.

## 6. Paste the Custom CSS

**Design → Custom CSS** → paste the contents of `custom-css.css`. It refines
spacing, the pill buttons, badge chips, and the callout cards to match the POC.
Tweak as needed — Squarespace's own color/font settings do most of the work.

## 7. SEO + local setup (do not skip — this is how he gets found)

- **Pages → each page → SEO:** set the title + description from the `<title>`
  and meta description in the matching static HTML file.
- **Settings → SEO:** site title "Dustin Yelton Painting & Cleaning |
  Northern Kentucky", add the service-area keywords.
- Create a **Google Business Profile** (free) for the business — for local
  services this often drives more calls than the website itself. Use the same
  name, phone, and service area.

## 8. Domain + launch

1. **Settings → Domains:** connect `DustinYelton.com` (buy at Cloudflare/
   Porkbun for ~$10/yr and point it here, or buy through Squarespace for
   convenience at a higher renewal).
2. Subscribe to a plan (Personal or Business — Business unlocks file uploads
   on the form).
3. Final pass: replace every placeholder, proofread, test the form and the
   click-to-call link on a phone, then **toggle the site live.**

## What to skip in phase one (per the plan)

No blog, no online booking, no pricing tables, no full music/art galleries —
just the "coming soon" mention on About. Add `/music` and `/art` in phase two.
