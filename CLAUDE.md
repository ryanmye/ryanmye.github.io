# CLAUDE.md — Codebase Index

> **If you are an LLM modifying this repository:**
> 1. Update the relevant sections of this file to reflect your changes before finishing.
> 2. **Anti-AI defense is a hard requirement.** Every new page, layout, or include you create MUST follow the anti-AI defense checklist in the "Anti-AI Defense" section below. Do not skip this, even for dev-only pages.
>
> Last updated: 2026-10-07 (World Seed added to projects.yml and the projects put in Ryan's order: DoRA, Worship Rig, World Seed, Geometric Art, Traveling Salesman, Personal Website, Sisyphus, Piano; the Personal Website picture is back; the Spotify "listened to" line is one include, `_includes/spotify_line.html`, markup and script together, used in the homepage hero and now in the /projects/ page head under the lede; `css_version` 13). Before that, 2026-10-02, latest (image security pass: every raster upload is stored with its orientation baked in and EXIF/XMP/IPTC removed, so no GPS or camera data reaches the site; ImageMagick always gets a forced coder and runs under `scripts/magick-policy/policy.xml`; data-URL images in post bodies are sniffed and stored like uploads; the SVG sanitizer has size, element and depth limits and removes unsafe CSS declarations instead of rewriting them; SVGs from the API and from bin/dev's Jekyll carry a sandboxed CSP; og:image and the post JSON-LD `image` share one pick; `generate_thumbnails.rb --strip-metadata`). Before that, 2026-10-02 (image formats: the studio accepts WebP, GIF (animation kept), SVG (sanitized by `scripts/image_pipeline.rb`, served by the API under a script-blocking CSP), HEIC/HEIF/AVIF (converted to JPEG with macOS `sips`) and TIFF/BMP (converted with ImageMagick); animated GIF/WebP get only a first-frame thumb, SVGs no variants; `photo_card.html`, `gallery.md` and `head.html` fall back for them). Before that, 2026-09-30, latest (a breadcrumb line above the h1 on every page but the homepage, from `_includes/breadcrumb.html`: "← Home", or "← Home / Blog" on posts and /gallery/, "← Home / Blog / Gallery" on albums, "← Home / Research" on /publications/; it replaces the gallery header's "Blog →" and the "Home" item of the 404 list; albums keep a plain "← Back to gallery" paragraph at the end). Before that, 2026-09-30 (/projects/ pictures: an optional `image` per project in projects.yml, shown only on /projects/ at 16:10 beside featured rows and on top of grid cells, linked to the site or repo; the grid is two columns from 700px, and projects with a picture come before the ones without; pictures for Worship Rig, DoRA, Traveling Salesman and this site in `assets/images/projects/`). Before that, 2026-09-28, latest (softer hero: no headline line; the ask "This cycle I'm looking for a Summer 2027 software engineering internship." at 18px/600 under the credential line; the intro opens "I do research in the Sun Lab…"; a homepage "From the blog" section with the three newest /blog/ entries, built from the shared `_includes/blog_entries.html` and `_includes/blog_line.html`; a homepage-only `short` field in projects.yml for DoRA and Sisyphus). Before that, 2026-09-28 (/blog/ lists standalone albums with the posts, by date, as "Album · N photos" rows; a credential line under the homepage name, "Cornell University · B.S. Computer Science · Class of 2028", built from `about.education`; the intro no longer repeats school and class year). Before that, 2026-09-28, later (no result numerals: the Selected work cards carry a two-sentence `card_summary` and /research/ positions are eyebrow, title, description and Details, with a figure column only when a figure is set; the "Outside academics" paragraph and the Spotify line are in the hero text column and the "Outside the lab" section is gone; an identity block under the photo (icon links, "Resume", "Jesus is King"); homepage "News" renamed "Updates"; publications ordered by a `rank` field everywhere; the JDS paper published with its DOI; resume Leadership restored). Before that, 2026-09-28 (editorial redesign, final: one 1120px page on a 12-column grid; SWE-first homepage hero with a 280px photo, three research cards with 48px result numbers, featured projects with his role stated; /research/ positions with a result on top and focus items in a Details that opens from its anchor; rows without hairlines, one hairline above each section heading, sections 96px apart; type 13/15/18/22/28/40/56 with text measured in em; blog excerpts and thumbnails, gallery album titles and captions; resume adds the statistical validation work). Before that, 2026-09-27 (design overhaul: tokens, self-hosted fonts, no tag pills, frameless photos; the studio at /editor/ with git publish and bin/dev; plus the earlier content sync, light/dark theme, a11y/perf, Spotify, build and CI work)

## Project Overview

Jekyll 3.x personal website and blog for **Ryan Ye** (CS @ Cornell). Deployed on GitHub Pages at `ryanmye.github.io` (root user site, repo `ryanmye/ryanmye.github.io`). Features data-driven pages (homepage bio, updates, projects, research, CV), a light/dark theme that follows the OS, a local "studio" editor for posts, drafts, and albums (Sinatra API, git publish), standalone photo albums (Jekyll collection), a gallery page, and automated Spotify "recently played" integration via GitHub Actions.

Audiences, in order: PhD admissions committees and professors, industry recruiters, Ryan himself. "Better" for this site means: facts match the master resume; a professor can tell what he works on and what he wants next in 60 seconds; the CV is scannable; copy sounds like Ryan and follows his house style (see Data Files); updates are one YAML edit; Lighthouse stays at 90+ and every theme passes AA contrast.

## Quick Reference

```bash
# Local development: editor API (4001) + Jekyll with --drafts (4000); Ctrl+C stops both
bin/dev                      # then open http://127.0.0.1:4000/editor/

# Or by hand. Jekyll:
bundle exec jekyll serve --livereload --drafts --baseurl ""
# Editor API (not `bundle exec ruby`: the repo path has a space, which breaks RUBYOPT)
ruby -rbundler/setup scripts/local_editor_server.rb

# Production build (CI uses both configs)
bundle exec jekyll build --config _config.yml,_config_prod.yml
```

- **Base URL:** `""` (GitHub Pages root user site)
- **Permalink format:** `/blog/:year/:month/:day/:title/`
- **Themes:** light (warm cream, default) and dark (warm charcoal). All colors are CSS custom properties in `styles.css`: `:root` = light, `:root[data-theme="dark"]` = dark, and `@media (prefers-color-scheme: dark) :root:not([data-theme="light"])` = dark by OS preference. `theme.js` only sets `data-theme` and updates the single toggle button.
- **Fonts:** Inter 400/600 + italics (body, UI, row and card titles), DM Serif Display (page h1s, section headings, post h2s and the brand), JetBrains Mono (code). All self-hosted in `assets/fonts/` (no Google Fonts); `head.html` preloads the three files every page uses, and a metric-matched local "Inter Fallback" keeps any late swap from moving text.
- **Design system:** one page width: every page is the 1120px container (plus 24px side padding, 16px on phones) on a 12-column grid, and all content starts at the same left edge except blog posts, whose reading column is centred. Type: 13/15/18/22/28/40/56px (each step at least 20% larger; body 18px, fluid down to 16px on phones). There are no stat-as-hero numerals anywhere (the owner rejected them; do not reintroduce them). Text is measured in em of its own size with one token, `--measure: 34em` (about 70 characters: 612px at 18px, 510px at 15px). Every section heading is DM Serif Display 28px with one hairline above it; sections are 96px apart; items inside a section are 24px apart with no lines. The homepage research cards are the only boxed element. Spacing on a 4px unit. All tokens are custom properties at the top of `styles.css`; see Assets.
- **Spotify:** GitHub Actions checks every 30 minutes and force-pushes `now-playing.json` to the orphan `spotify-data` branch only when `played_at` changed; no commit to main, no deploy
- **Ruby:** 3.3.6 (`.ruby-version`), gems locked in `Gemfile.lock`. macOS system Ruby 2.6 cannot run this bundle; see README for setup
- **Icons:** inline SVGs via `_includes/icon.html` (no Font Awesome)

## Directory Tree

```
.
├── _config.yml              # Main Jekyll config
├── _config_prod.yml         # Production overrides (disables editor; full exclude list duplicated, see below)
├── Gemfile                  # Ruby deps: jekyll 3.x; :development sinatra + mini_magick + rexml; :test html-proofer
├── Gemfile.lock             # Committed (arm64-darwin + x86_64-linux platforms)
├── .ruby-version            # 3.3.6, read by ruby/setup-ruby in CI
├── .gitignore
├── CLAUDE.md                # This file (excluded from Jekyll build)
├── robots.txt               # Anti-AI crawler rules (blocks GPTBot, CCBot, etc.)
├── ai.txt                   # Machine-readable AI opt-out (Spawning.ai standard)
│
├── _layouts/
│   ├── default.html         # Base layout (head + navbar + footer + theme.js)
│   ├── post.html            # Blog post layout (title, date, body, extra photos not in the body, prev/next nav)
│   ├── album.html           # Standalone album detail page layout
│   └── editor.html          # Studio app layout (library sidebar, post/album panes, dialogs; dev-only)
│
├── _includes/
│   ├── head.html            # <head>: meta, OG tags, fonts, CSS
│   ├── navbar.html          # Skip link, sticky nav, light/dark toggle button, mobile hamburger menu
│   ├── breadcrumb.html      # "← Home" (+ "/ Blog", "/ Gallery", "/ Research") above the h1 on every page but the homepage
│   ├── footer.html          # One line: copyright · Jesus is King · Gallery · GitHub · LinkedIn · email
│   ├── icon.html            # Inline SVG icon include (replaces Font Awesome)
│   ├── spotify_line.html    # The Spotify "listened to" line: markup + fetch script (homepage hero, /projects/ page head)
│   ├── image_src.html       # Pluggable image URL resolver (local | cloudflare_resize | cloudflare_images)
│   ├── photo_card.html      # Shared album/gallery photocard (figure + lightbox trigger)
│   ├── pub_rows.html        # Publications as rows (callers sort by `rank`), year right-aligned (research, publications, cv)
│   ├── project_rows.html    # Project rows, featured first (homepage; details=true for /projects/, with pictures)
│   ├── blog_entries.html    # Assigns `blog_entries`: posts + published standalone albums with photos, newest first (/blog/, homepage)
│   ├── blog_line.html       # One entry's line of text: excerpt / first 24 words, or album_caption / description's first sentence
│   └── figure_slot.html     # A research figure (rendered only when research.yml sets `figure`)
│
├── _data/
│   ├── about.yml            # seeking, intro, outside, cv_summary, education, skills, teaching, honors, blog_blurb
│   ├── news.yml             # Homepage "Updates" list (date, markdown text; three newest shown)
│   ├── projects.yml         # 8 non-research projects: summary, short, context, featured, description, bullets (5 have cv: true)
│   ├── research.yml         # Research positions (3), publications (3), interests (site-wide)
│   └── image_meta.yml       # Generated image manifest (dimensions + thumb/med variant paths)
│
├── _posts/                  # Blog posts (YYYY-MM-DD-slug.md) — currently 3 posts
├── _drafts/                 # Unpublished drafts (slug.md) — currently 2 drafts
├── _albums/                 # Standalone photo albums (slug.md, Jekyll collection)
│
├── index.md                 # Homepage (hero; Selected work cards; projects, publications, updates)
├── 404.html                 # Custom not-found page (default layout, sitemap: false)
├── redirects/               # Standalone redirect pages for moved URLs (layout: null, manual anti-AI meta)
├── blog.md                  # Blog listing: posts and standalone albums, grouped by year
├── projects.md              # Projects: lede, the Spotify line, then rows with optional pictures (two columns from 700px, featured spanning)
├── research.md              # Research page
├── cv.md                    # CV page (data-driven from about.yml, research.yml, projects.yml)
├── publications.md          # All publications (pub_rows.html, no filter)
├── editor.md                # Studio page at /editor/ (dev-only)
├── album-editor.md          # Redirect /album-editor/ → /editor/#albums (dev-only)
├── gallery.md               # Photo gallery page (album cards only)
├── feed.xml                 # Atom feed: jekyll-feed 0.17.0's template, with a summary fallback to the first 40 words
│
├── assets/
│   ├── css/styles.css       # The one public stylesheet; tokens (palettes, type, spacing, radii) live at the top
│   ├── css/editor.css       # Studio styles only (dev-only, loaded by editor.html, excluded in prod)
│   ├── js/theme.js          # Light/dark toggle (sets data-theme, localStorage persistence)
│   ├── js/editor.js         # Studio UI (posts, drafts, albums, photos, backups, git publish)
│   ├── js/album-lightbox.js # Shared lightbox for album photocards and post body images (keyboard nav, neighbor preload)
│   ├── fonts/               # Self-hosted woff2 (Inter 400/600 + italics, DM Serif Display, JetBrains Mono) + OFL licenses
│   └── images/
│       ├── headshot.jpeg    # Profile photo, 640px (the homepage hero photo, og:image, Person schema)
│       ├── headshot-320.jpeg # Same photo at 320px (currently unused; the hero uses headshot.jpeg)
│       ├── projects/        # /projects/ pictures (projects.yml `image`), 1200x750 WebP
│       ├── posts/           # Published post images (timestamped)
│       ├── drafts/          # Draft post images (gitignored)
│       └── albums/          # Standalone album images
│
├── bin/
│   ├── dev                  # Starts editor API + `jekyll serve --drafts`; excluded from builds
│   └── dev-plugins/svg_headers.rb # Dev-only Jekyll plugin (loaded by bin/dev only): CSP + nosniff on served SVGs
│
├── scripts/
│   ├── local_editor_server.rb      # Sinatra REST API for the studio (port 4001)
│   ├── image_pipeline.rb            # Shared image rules: formats, sniffing, storing/stripping uploads, variants, SVG sanitizer
│   ├── magick-policy/policy.xml     # ImageMagick policy the pipeline runs under (denied coders, limits)
│   ├── generate_thumbnails.rb       # Backfill CLI: emits -thumb.jpg/-med.jpg + image_meta.yml
│   └── get-spotify-refresh-token.py # One-time Spotify OAuth setup
│
├── .github/workflows/
│   ├── deploy.yml           # Jekyll build + Pages deploy (push to main / manual)
│   ├── ci.yml               # PR check: production build + html-proofer
│   └── update-spotify.yml   # Cron job: fetch Spotify → force-push now-playing.json to the spotify-data branch
│
├── _editor_tmp/             # Temp images during editing (not committed)
├── _site/                   # Built output (not committed)
├── resume.pdf               # One-page resume served at /resume.pdf ("Resume (PDF)" on the homepage and /cv/); regenerated from resume/resume.tex
├── resume/resume.tex        # LaTeX source (excluded from the Jekyll build). Build: `tectonic resume/resume.tex && mv resume/resume.pdf resume.pdf`
└── README.md                # Setup, authoring, and deployment runbook
```

---

## Configuration Files

### _config.yml (~65 lines)
Main Jekyll configuration. Key settings:
- `title: "Ryan Ye"`, `baseurl: ""`, `url: "https://ryanmye.github.io"`
- `title_suffix: "Ryan Ye | Cornell CS"` — appended to inner-page `<title>` tags by `head.html` (SEO keyword signal)
- `css_version: 13` — cache-busting query param for `styles.css`; bump manually whenever the stylesheet changes
- `description` — "Personal website of Ryan Ye, a computer science student at Cornell University…" (fallback meta description + WebSite schema)
- `twitter_username: "ryanmye0"` — used for Twitter Card meta tags
- `markdown: kramdown` with GFM input, Rouge syntax highlighter
- `permalink: /blog/:year/:month/:day/:title/`
- `excerpt_separator: ""` — no automatic excerpts: `post.excerpt` exists only when a post's front matter sets `excerpt:` (the blog index then shows it, else the first 24 words)
- `local_editor: true` — enables editor nav link and page in development
- `plugins: [jekyll-sitemap, jekyll-feed]` — auto-generates `sitemap.xml`; jekyll-feed skips `/feed.xml` because the root `feed.xml` exists (a copy of the plugin's template whose `<summary>` falls back to the first 40 words when a post has neither `description` nor `excerpt`; re-copy it if jekyll-feed is upgraded)
- `collections.albums`: `output: true`, `permalink: /albums/:title/` — standalone album Jekyll collection
- `images:` block selects the image delivery backend used by `_includes/image_src.html`:
  - `source: local` (default) — serves pre-generated thumbnails from `assets/images/`
  - `source: cloudflare_resize` — routes originals through `/cdn-cgi/image/<opts>/` (requires the site to sit behind a Cloudflare zone with Image Resizing enabled)
  - `source: cloudflare_images` — uses `https://imagedelivery.net/<account_hash>/<cf_id>/<variant>` (requires `cf_id` in `_data/image_meta.yml` and `images.cloudflare.account_hash` set)
  - `images.widths: { thumb: 600, med: 1600 }` — pixel widths used by local generation and Cloudflare Image Resizing variant URLs
- Defaults: `post` layout applied to all files in `_posts/`, `album` layout applied to all files in `_albums/`
- Excludes: README.md, CLAUDE.md, LOCAL_DEV.md, Gemfile, Gemfile.lock, .ruby-version, node_modules, vendor, scripts/, .github/, _deleted/, resume/, bin/. **Jekyll replaces exclude lists across config files, it does not merge them**, so this exact list is duplicated in `_config_prod.yml`; edit both.

### _config_prod.yml
Production overlay (used in CI build). Overrides:
- `local_editor: false` — hides editor
- The full exclude list from `_config.yml` (kept in sync by hand) plus `editor.md`, `album-editor.md`, `assets/js/editor.js`, `assets/css/editor.css`. A production build contains no `/editor/`, `/album-editor/`, `editor.js`, `editor.css`, or `bin/`.

### Gemfile / Gemfile.lock / .ruby-version
Dependencies: `jekyll ~> 3.8` (resolves to 3.10.0), `webrick ~> 1.7`, `kramdown-parser-gfm`, `jekyll-sitemap`, `jekyll-feed`. `:development` group: `sinatra ~> 3.0` (editor API), `mini_magick ~> 4.12` (thumbnail generation; requires ImageMagick on PATH — `brew install imagemagick`), `rexml ~> 3.4` (the SVG sanitizer; a bundled gem since Ruby 3.0, so it must be listed to load under Bundler; kramdown also depends on it, so the default group has it anyway). `:test` group: `html-proofer ~> 5.0` (needs Ruby ≥ 3.3). The lockfile is committed with `arm64-darwin` and `x86_64-linux` platforms; run `bundle lock --add-platform <platform>` for a new one. Ruby is pinned to 3.3.6 in `.ruby-version`; CI sets `BUNDLE_WITHOUT` so only the default group installs for deploys.

---

## Layouts

### _layouts/default.html
Base HTML5 layout for all non-post, non-album pages. Includes `head.html`, `navbar.html`, `footer.html`. Wraps the page in `.container > .page-content` (the full 1120px page; there is no per-page width flag). On every page but the homepage (`page.url != "/"`) it puts `{% include breadcrumb.html %}` at the top of `.page-content`, above the page's own `<header class="page-head">`. Loads `theme.js` before `</body>`. Also conditionally loads `album-lightbox.js` when the page sets `album_lightbox: true` in its front matter (no page does now that the gallery shows album cards only). **Used by:** `index.md`, `blog.md`, `projects.md`, `research.md`, `publications.md`, `cv.md`, `gallery.md`, `404.html`.

### _layouts/post.html
Blog post layout. Renders, inside `.page-content`, `<article class="post-reading">`: one reading column (34em, about 70 characters at 18px) centred in the 1120px page, with the breadcrumb ("← Home / Blog", `breadcrumb.html`, first in the article so it lines up with the title), the 40px serif title, date (`<time>` with `date_to_xmlschema`, shown as `"%B %-d, %Y"`), post content at 18px/1.55 (h2 28px serif with 56px above and 12px below; h3 18px/600 with 40px above) (post-processed: body `<img>` srcs are rewritten to `-med.jpg` variants via the `_data/image_meta.yml` manifest, and `loading="lazy" decoding="async"` is injected), then a photo section (`.post-album`, heading "More photos" or "Photos") with only the `page.images` whose `src` does not appear in the rendered body (`content contains img.src`), so no photo shows twice; each is a photocard with a lightbox trigger in a two-column masonry grid. Images in the body also open in the lightbox (see album-lightbox.js). Then previous/next links. Tags are not shown; they stay in front matter for `article:tag` and the JSON-LD `keywords`. Includes BlogPosting JSON-LD structured data (headline, datePublished, author, image, keywords); `image` is the og:image pick from `head.html` (`og_first` / `og_image`), so an SVG or an animated GIF is never sent as the original. Loads `theme.js` and `album-lightbox.js`. **Used by:** all files in `_posts/` via default collection config.

### _layouts/album.html
Standalone photo album detail page layout, in `.page-content` (left edge of the page). Renders: the breadcrumb ("← Home / Blog / Gallery", `breadcrumb.html`; at the top), the 40px title, date · photo count, optional description (34em), a photocard grid (three masonry columns at >=1024px, two below) of `page.images` (`<figure>` + `<button class="album-photo-trigger">` + `<figcaption>`), then `p.album-end`, a plain "← Back to gallery" paragraph (arrow `aria-hidden`; not a nav landmark) 72px below the grid, since albums run long. Loads `theme.js` and `album-lightbox.js` for lightbox support. **Used by:** all files in `_albums/` via default collection config. Permalink: `/albums/:title/`.

### _layouts/editor.html (~260 lines)
The studio: an app-style page (navbar, no footer, `body.studio-page`) with `{% include head.html %}`. Loads Toast UI Editor **3.2.2** (pinned, core + dark theme CSS from uicdn.toast.com), then `assets/css/editor.css` (all studio styles; `styles.css` has none), `theme.js`, `editor.js`. Markup: `<main id="main-content" class="studio" data-api-origin="http://127.0.0.1:{{ site.studio_api_port | default: 4001 }}">` (`bin/dev` sets `studio_api_port` through a temporary extra Jekyll config when `STUDIO_API_PORT` is given) holding the library sidebar (New post / New album, search, Posts / Drafts / Albums groups, git summary, `?` button), the top bar (breadcrumb, status pill, Preview, Publish draft, Save, overflow menu with Copy markdown / Open file / Clean up abandoned uploads / Delete, Publish to site with a count), a restore banner, and four views (`#view-empty` welcome, `#view-post`, `#view-album`, `#view-offline`) plus one shared `#photos-panel` that `editor.js` moves into the post or album view. Post view: title, meta row (date, tags, Draft), `#post-description` (SEO, counter 160), `#post-excerpt` (label "Excerpt", counter 160), body. Album view: title, meta row, `#album-description`, `#album-caption` (label "Album caption", counter 120), photos. The photos panel holds `#post-card-fields` (`#post-album-title`, `#post-album-caption` with counter 120, and a hint), shown only in post mode. The one-line fields use `.studio-line-field` (inline label) or `.studio-line-box` (label over a boxed input with the counter inside) in `editor.css`. Dialogs after `</main>`: confirm, typed-slug delete, "file changed on disk" (Keep editing / Reload from disk / Overwrite), keyboard shortcuts, and the Publish to site drawer. **Conditionally rendered:** only when `site.local_editor == true` AND `jekyll.environment == "development"`; otherwise a one-line notice.

---

## Includes

### _includes/head.html
HTML `<head>` contents:
- Meta: charset, viewport, dynamic title (priority: `page.full_title` > `{{ page.title }} — {{ site.title_suffix | default: site.title }}` > `site.title`), description (computed once as `meta_desc` for the meta, Open Graph and Twitter tags: `page.description` > the front-matter `excerpt` > for posts, the first 160 characters of the body > `site.description`; escaped), author
- Canonical URL: `<link rel="canonical">` using `absolute_url`
- Feed discovery: `{% feed_meta %}` (Atom feed link from jekyll-feed; the feed itself is the root `feed.xml`)
- Anti-AI/crawler: `<meta name="robots" content="noai, noimageai">`, `<meta name="tdm-reservation" content="1">`
- Open Graph: type ("article" for posts, "website" otherwise), URL, title, description, site_name, image. The image is the `-med.jpg` variant of the page's first photo (via `image_src.html`, with `og:image:width/height` from `image_meta.yml`), never the original; an animated GIF/WebP (no med) uses its still first-frame `-thumb.jpg`; headshot fallback when there is no photo, when the first photo is an SVG (social sites do not show SVG) or an animated one has no thumb, and then `og:image:alt` is "Ryan Ye". It sets `og_first` / `og_image`, which `post.html` reuses for the JSON-LD `image` (left out when `og_first` is unset). Posts also get `article:published_time`, `article:author`, `article:tag`
- Twitter Card: `summary_large_image` on pages with photos, `summary` otherwise; site handle (@ryanmye0), title, description, image
- `<meta name="color-scheme" content="light dark">`
- CSS: loads `styles.css` with `?v={{ site.css_version }}` cache-buster (bump `css_version` in `_config.yml` when editing the stylesheet)
- Fonts: self-hosted, no third-party requests. `<link rel="preload" as="font" type="font/woff2" crossorigin>` for `inter-latin-400-normal`, `inter-latin-600-normal` and `dm-serif-display-latin-400-normal` (the files every page renders with), so they arrive with the stylesheet and the first view renders in Inter (cold-load CLS 0.0000 on fast, throttled 4G and 3G). The `@font-face` rules (font-display: swap) live at the top of `styles.css`; the Inter italics and JetBrains Mono load only when used. The "Inter Fallback" faces in `styles.css` (local Arial, Arial Bold, Italic, Bold Italic with measured `size-adjust` and ascent/descent overrides, within 0.5% of Inter's width) cover the case where a font is late. (No Font Awesome; icons are inline SVGs via `icon.html`.)
- Favicon: inline SVG data URI, a serif "RY" (Georgia, since web fonts cannot load inside a data URI) in the light accent color
- JSON-LD structured data: WebSite schema on all pages (with `alternateName` array, e.g. "Ryan Ye's Personal Website"); Person + ProfilePage schemas on homepage only. Person schema includes `givenName`/`familyName`, `alternateName` (e.g. "ryanmye"), `jobTitle`, `memberOf`/`affiliation` (Cornell), `knowsAbout` keywords, `sameAs` links (GitHub, LinkedIn, Twitter, Google Scholar). ProfilePage references the Person and WebSite via `@id`.
- Inline theme-bootstrap `<script>` at end: reads `localStorage.theme` (mapping the old five palette names to light/dark) and sets `data-theme` on `<html>` before first paint. With no saved choice nothing is set and the CSS media query decides.

### _includes/navbar.html
Skip link (`.skip-link` → `#main-content`, first tab stop on every page) followed by the sticky top navigation bar:
- Brand link (`site.author`) to homepage
- One `#theme-toggle` button (36px hit area, `aria-pressed`, sun/moon inline SVGs; which icon shows is driven by the `--icon-sun` / `--icon-moon` custom properties set per theme in `styles.css`)
- Nav links (order): research (`/research/`), projects (`/projects/`), blog (`/blog/`), cv (`/cv/`). There is no about tab: the brand links home. 15px, links fill the nav height and overlap its bottom border by 1px so the active 2px underline sits on the border line. Hrefs carry trailing slashes so GitHub Pages does not 301. Research is also active on `/publications`; blog is also active on `/gallery` and `/albums/*`. Gallery is linked from the blog page header, not the navbar.
- Dev-only nav link: editor (`/editor/`, which also covers albums) — between `blog` and `cv`, only when `site.local_editor == true` AND `jekyll.environment == "development"`
- Mobile: hamburger toggle button (3 spans), click-outside-to-close JS, ARIA attributes. The open menu uses `--bg`, auto height, a shadow, and a left accent bar on the active item.
- Active link detection via `page.url` comparison, with `aria-current="page"`

### _includes/footer.html
One 13px line on `--bg` (no border, no slab): "© {year} Ryan Ye" · "Jesus is King" (`.footer-faith-note`) · Gallery · GitHub · LinkedIn · email, with `aria-hidden` middot separators. On phones the links drop to their own line. All external links use `target="_blank" rel="noopener noreferrer"`.

### _includes/breadcrumb.html
The one line above the h1 on every page but the homepage (the brand link alone was not an obvious way home). `<nav class="crumbs" aria-label="Breadcrumb">` with an `ol`: "← Home" (a link to `/` via `relative_url`; the arrow is an `aria-hidden` inline-block span, so the accessible name is "Home" and the underline skips it), then the page's section, if any, after an `aria-hidden` "/": Blog on posts and /gallery/, Blog / Gallery on albums, Research on /publications/ (the sections the navbar marks `aria-current="true"`). The current page is not repeated, so there is no `aria-current`. 13px (`--fs-1`), accent links with a `--muted` underline (currentColor on hover), the site's accent focus ring. `.crumbs` has a negative top margin (-32px, -24px at <=600px) that takes its height back from `main`'s top padding, so the h1 sits where it did (2px lower on desktop, 10px on phones), with 16px between the line and the h1. **Used by:** `default.html` (not on `/`), `post.html`, `album.html`. Not on the dev-only studio (`editor.html`).

### _includes/icon.html
Inline SVG icon include (replaces Font Awesome). Usage: `{% include icon.html name="github" class="optional-extra-class" %}`. Supported names: `envelope`, `github`, `linkedin`, `spotify`, `file-pdf`, `file-lines`, `graduation-cap` (the Google Scholar icon). Emits `<svg class="icon ..." fill="currentColor" aria-hidden="true">` sized at 1em by the `svg.icon` rule in `styles.css` — inherits `font-size` and `color` from context. Path data from Font Awesome Free 6.4.2 (CC BY 4.0). To add an icon: add a `{% when %}` branch with its viewBox + path. **Used by:** `index.md` (the hero's icon row: envelope, github, linkedin, graduation-cap) and `spotify_line.html` (the Spotify icon). `file-pdf` and `file-lines` are currently unused.

### _includes/spotify_line.html
`{% include spotify_line.html %}`, no parameters, at most once per page (it uses the ids `spotify-widget` and `spotify-now-playing`). The Spotify "listened to …" line and its inline script in one file, so the homepage hero (`index.md`) and the /projects/ page head (`projects.md`) run the same code. Markup: `p.spotify-widget#spotify-widget[hidden]` with the Spotify glyph (`icon.html`) and `span#spotify-now-playing`; the `<script>` follows the paragraph directly. The script fetches `https://raw.githubusercontent.com/<github_username>/<github_username>.github.io/spotify-data/now-playing.json` with a 5s timeout, only accepts `https://open.spotify.com/` links, writes "listened to <track> by <artists> from <context> (N hours ago)" and un-hides the line on success; on any failure the line stays hidden. Helpers: `timeAgo`, `escapeHtml`, `clip`, `link`, `safeUrl`. Styles are the shared `.spotify-widget` rules in `styles.css`: 13px, `--muted`, at most two lines (clamped), both lines reserved with `min-height: 3.2em` and `visibility: hidden` while hidden, so loading or failing moves nothing. The lines after the first are indented four spaces so the homepage HTML keeps its indentation.

### _includes/image_src.html (~40 lines)
Pluggable image URL resolver — the single choke point for every album/gallery image URL. Takes `src` (repo-relative path, e.g. `/assets/images/posts/foo.png`) and `variant` (`thumb` | `med` | `original`) and emits one URL string. Branches on `site.images.source`:
- `local` — looks up `site.data.image_meta[<key>]` and returns the matching variant path (e.g. `/assets/images/posts/foo-thumb.jpg`), falling back to the original if no manifest entry or variant exists. Some sources never have every variant: an animated GIF/WebP has a still `thumb` but no `med` (so `med` resolves to the animated original, which the lightbox and post body show), and an SVG has neither (every variant is the SVG).
- `cloudflare_resize` — emits `<site.images.cloudflare.resize_prefix>/width=<W>,quality=<Q>,format=auto/<original-url>` using `site.images.widths[<variant>]` (never for `.svg`, which is always the original).
- `cloudflare_images` — emits `https://imagedelivery.net/<account_hash>/<cf_id>/<variant>` (falls back to `public` variant for `original`); requires `cf_id` in the manifest and `account_hash` in config, otherwise falls through to the local branch.

Callers capture the output and pipe through `strip` to drop Liquid whitespace. Usage example in `_includes/photo_card.html`. Swapping backends is a config-only change; no templates need editing.

### _includes/photo_card.html (~15 lines)
Shared photocard renderer used by every album/gallery context. Inputs: `src`, `caption`, `index` (global photo index for the lightbox), `fallback_alt`. Delegates URL construction entirely to `image_src.html` — captures `thumb`, `med`, and `original` variants. Reads `site.data.image_meta[<key>]` for `width`/`height` attributes (prevents CLS): the thumb's size, else the entry's own `w`/`h` (an SVG has no thumb), and gracefully degrades to bare `src` + original URL when the manifest has no entry. Emits `loading="lazy"`, `decoding="async"`, `fetchpriority="low"` on the grid `<img>`, and exposes `data-full-src` (med) + `data-original-src` for the lightbox. The trigger button only gets an `aria-label` when there is a caption; otherwise the img alt names it, so uncaptioned photos don't all read "Open photo". **Used by:** `_layouts/post.html`, `_layouts/album.html`.

### _includes/pub_rows.html
`{% include pub_rows.html pubs=array descriptions=true|false %}`: a `ul.rows` of `.row`s: title (linked if `url`), authors (Ryan's name, "Ryan M. Ye", "Ryan Ye" or "R. M. Ye", wrapped in `<strong>`), venue · lowercased role in muted, the description when `descriptions=true`, and `year` right-aligned. No tiles, images, or tags. **Used by:** `research.md` (selected, descriptions), `publications.md` (all, grouped by `type`, descriptions), `cv.md` (all, none). The homepage renders its own compact title + venue list. Every caller sorts by `rank` first (`| sort: "rank"`), so the order everywhere is rank order (1 = most significant; currently the ADSA poster).

### _includes/project_rows.html
`{% include project_rows.html %}` or `{% include project_rows.html details=true heading="h2" %}`. Lists `projects.yml` with `featured: true` projects first (then the rest in file order). Every row: title with an inline "site →" when `site` is set and "code →" when `url` is set, `date` right-aligned. Homepage (default, `ul.proj-list`): featured rows add `short` when set, else the `summary` (Markdown; it states his role); the others add the one-line `context` (team and role). `details=true` (`ul.proj-grid`, /projects/): every row adds `summary` and `context`, then a closed `<details class="more">` ("+ Details") with the `description` and `bullets`; two columns from 700px (cells top-aligned; it was three at >=1024px until the pictures, which left the fourth non-featured project alone on a row) with featured rows full width, a 22px title and an 18px summary; the non-featured cells put the date above the title. **Pictures:** a project with `image` gets `div.row-media` first and the `li` gets `.has-media`: the `<img>` (`relative_url`, `width`/`height` from the data, `loading="lazy"`, `decoding="async"`, the data's `alt`) shown at 16:10 with `object-fit: cover`, a 1px `--border` hairline, an 8px radius and a `--card` background while loading; it is wrapped in a link to `site`, else `url` (new tab), which is `aria-hidden="true"` and `tabindex="-1"` because the title row already links there (no duplicate tab stop); hover is opacity 0.9. A grid cell shows it on top (above the date); a featured row shows it on top below 700px and from 700px in the first column (the same width as a cell's picture) with the date and text in the second. After the featured rows, the projects with a picture come before the ones without (each group in file order), so a grid row never pairs a picture with a text-only cell that would read as its caption. A project without `image` renders exactly as before; a featured row without one keeps its own three-column layout at >=1024px (title and summary across two, the date, context and Details stacked in the third). The homepage (no `details`) never renders pictures and keeps plain file order.

### _includes/figure_slot.html
`{% if position.figure %}{% include figure_slot.html figure=position.figure %}{% endif %}`: a `figure.study-figure` with the image (`relative_url`, lazy, `width`/`height` when given so nothing shifts; at most 480px tall) and an optional caption. /research/ puts it in `.study-media`, the right column (columns 9 to 12 at >=1024px, the space right of the text; above the text on narrower screens) of a `.study-body.has-figure`. Nothing is rendered for a position without `figure`.

---

## Root Pages

### _includes/blog_entries.html
`{% include blog_entries.html %}` outputs nothing and assigns `blog_entries` (an include's `assign` persists in the page): every post plus each standalone album that is not `draft: true`, not `published: false`, and has at least one image, sorted by `date`, newest first. /blog/ groups all of them by year; the homepage "From the blog" takes the first three. Change the list here only, so the two cannot drift.

### _includes/blog_line.html
`{% capture l %}{% include blog_line.html entry=post %}{% endcapture %}` then `l | strip`: the entry's line as plain text (`markdownify | strip_html`). A post: front-matter `excerpt`, else its first 24 words. An album: `album_caption`, else the first sentence of `description`, else empty. Used by /blog/ rows and the homepage teasers. (No Liquid tags inside `{% comment %}` in these includes: a `{% for` there breaks the build.)

### index.md — Homepage
**Layout:** default. **Title:** `full_title: "Ryan Ye — Computer Science Student at Cornell University"`. **Data deps:** `site.data.about` (seeking, intro, outside, education: institution, institution_url, degree_short, expected), `site.data.research.positions` (`homepage: true`), `site.data.research.publications` (`selected: true`), `site.data.research.google_scholar`, `site.data.news`, `site.data.projects`, `site.posts` and `site.albums` (via `blog_entries.html`), `_config.yml` (author, email, github_username, linkedin_username). GPA is not on the homepage.

Sections (top to bottom):
1. **Hero** (`header.hero`). DOM order: `.hero-lead` (the 56px serif name; the credential line; `about.seeking`, the internship ask, `p.hero-seeking`: body size (`--fs-3`, 18px at 1440)/600, `--text`, one line at 1440, 16px under the credential line. There is no headline line: the owner rejected both "I build full-stack web apps and ML systems." and a softer replacement, so don't add one back), `.hero-aside` (identity block), `.hero-intro` (34em, 20px under the ask; the hero spaces with margins, not `gap`: `about.intro`, then `about.outside`, the "Outside academics…" paragraph with the Cru link, 16px below it, then the Spotify line last in the text column). So the tab order is skip link, nav, the Cornell link, the four icons, Resume, then the intro's links.
   - **Credential line** (`p.hero-credential`, 12px under the name, 16px above the ask): "Cornell University · B.S. Computer Science · Class of 2028", built from `about.education` (`institution` linked to `institution_url` in a new tab, `degree_short`, and the year of `expected`: `expected | split: ' ' | last`). Body size (`--fs-3`), `--text-2`; the school is 600 with an accent underline (the text itself is not accent). It is a flex row that breaks only at a dot, and first at the school's dot: the school and `.cred-group` (degree, class year) are nowrap `.cred-item`s and the group moves to the next line whole before it wraps inside (320px). The dots are `::before`s in the 1.2em column gap; a dot left at the start of a wrapped line falls left of the paragraph and `clip-path` hides it. Visually hidden commas make screen readers read it as a list. So at 1440 it is one line; at 390 and 768, "Cornell University" then "B.S. Computer Science · Class of 2028". No GPA on the homepage.
   - **Identity block** (`.hero-aside`: the photo, then `.hero-id`): the round headshot `headshot.jpeg` (640px, sharp at 2x; `width`/`height` 280) and, under it, one centered column exactly the photo's width (280px at >=1024px, 200px from 700px): an icon row `ul.profile-icons` (Email, GitHub, LinkedIn, Google Scholar via `icon.html` envelope/github/linkedin/graduation-cap; each link has `aria-label` and `title`, external ones `target="_blank" rel="me noopener noreferrer"`; the link box is the ~20px glyph, optically sized per mark with `.i-mail` 21px / `.i-github` 20px / `.i-linkedin` 19px / `.i-scholar` 26x21, and a `::after` extends the hit area to 44x44 with the hit areas touching (24px between glyphs); `--muted`, accent on hover/focus, focus ring on the hit area), then `a.resume-link` (the word "Resume", underlined in `--muted` with a 3px offset, 15px/600 accent, `aria-label="Resume (PDF)"`, links to `/resume.pdf`), then "Jesus is King" (`.profile-faith-note`, 13px, `--muted`, letter-spacing 0.02em). Rhythm: photo, 20px, icons, 14px, Resume, 10px, Jesus is King (the owner's measurements, not tokens). At >=700px the hero is a grid (text column + photo column: `minmax(0, 44rem) 280px` with a 72px gap at >=1024px, `1fr 200px` from 700px) and the aside spans both text rows. Below 700px the hero is a flex column and the whole aside moves above the name (`order: -1`): the 160px photo centered, with the icons, Resume and "Jesus is King" centered on it (same 20/14/10px rhythm); 24px below it, the name, the credential line, the internship ask and the intro. The lead's only link is the credential's Cornell link: at >= 700px it is first in the text column, top left, so the tab order follows the layout; on phones it is focused just before the icons although it sits below them (the one place the tab order and the layout differ; the DOM keeps the h1 first for screen readers).
   - **Spotify line** (`{% include spotify_line.html %}`, the last thing in `.hero-intro`: `#spotify-widget`, 13px, at most two lines, clamped; the glyph sits on the first text line; both lines are reserved with `min-height` and `visibility: hidden`, so loading or failing causes no layout shift. The markup and the script live in the include, shared with /projects/; the script now sits right after the line inside `.hero-intro` instead of at the end of the page). It stays hidden until the `spotify-data` branch exists (the fetch 404s).
   The first section sits 72px below the hero.
2. **Selected work** (h2 + "All research →") — `ul.work-grid` of `.work-card`s, one per `homepage: true` position: eyebrow ("Research · <date>"), `.work-body` (`index_title`, 22px/600, with the `card_summary` right under it: `.work-summary`, 18px `--text-2`, `text-wrap: wrap`, run through `markdownify` for typographic quotes: what the project is, then what he did; never a metric), and "Details →" to `/research/#<slug>`, pinned to the bottom (the link's `::after` covers the card; the focus ring is drawn on the card via `:has()`). Three subgrid rows (eyebrow, body, Details) keep eyebrows and Details level, so the cards in a row are the same height and a one-line title does not leave a gap above its summary. 3-up at >=1024px, 2-up from 700px (an odd last card spans the row), 1-up below. Cards use `--card` with a 12px radius and are the only boxed element on the site.
3. **Two columns** (`.home-columns`, 7fr/5fr at >=1024px): left, Projects (`project_rows.html`: featured first with `short`, else the summary; the rest title, context and date); right, Publications (selected, sorted by `rank`; 15px title + 13px venue · role; "All publications →") and **Updates** (`#home-updates`, from `_data/news.yml`, three newest; `display` or "%b %Y"). There is no "Outside the lab" section; that paragraph is in the hero.
4. **From the blog** (`#home-blog`, h2 + "All posts →" to /blog/), full width after the columns: `ul.teasers`, the first three of `blog_entries` (the same list as /blog/). Each `li.teaser`: when it has `images`, `img.teaser-thumb` (the `thumb` variant of `images[0]` via `image_src.html`, `alt=""`, width/height 600x375, lazy, CSS `aspect-ratio: 16 / 10` with `object-fit: cover`, 8px radius); then `.teaser-body`: the linked title (`h3.teaser-title`, `--fs-3` 600; the link's `::after` covers the item), the meta line (`.teaser-meta`, 13px `--muted`: "Mar 17, 2026", albums add " · Album · N photos") and the `blog_line.html` text (`.teaser-line`, 15px `--text-2`, clamped to two lines). No background or border; hover changes only the title's underline color (muted to accent). 3-up at >=900px (thumb on top; a photo-less entry is text only, its title level with the others' thumbnails); below 900px one per row with the thumb left (160px, 120px on phones) and a photo-less entry's text in the text column.

### blog.md — Blog Listing
**Layout:** default. Header: h1, `about.blog_blurb`, "Gallery →". Posts and standalone albums merged into one list by `_includes/blog_entries.html` (shared with the homepage "From the blog"), sorted by `date` newest first, and grouped by year (`group_by_exp`) under a 13px uppercase year label (`.year-label`); each item is a `.row`: a 120x90 thumbnail (the `thumb` variant of `images[0]` through `image_src.html`, lazy, 4px radius) only when it has `images`, the linked 22px/600 title, a line of text, and the date (`%b %-d`) with the photo count under it, right-aligned. Each line comes from `_includes/blog_line.html`: a post's line is its front-matter `excerpt` when set (run through `markdownify | strip_html`, so Markdown shows as text; else its first 24 words). An album row (`item.collection == "albums"`) links to the album page; its line is `album_caption`, else the first sentence of `description` (as on /gallery/), else nothing, through the same `markdownify | strip_html`; its count reads "Album · N photos". A year with any thumbnail keeps the 120px column for every row (`.rows-thumbs`), so titles align. Draft albums also set `published: false`, so production never reads them; the `draft` check keeps them out if one is ever built. `feed.xml` stays posts only.

### projects.md — Projects
**Layout:** default. **Data deps:** `site.data.projects.projects`.
h1 and a lede pointing to the research page; under the lede, still inside `header.page-head`, the Spotify line (`{% include spotify_line.html %}`, the same include as the homepage hero): 13px, 12px below the lede and as wide as it (`.page-head .spotify-widget`: `max-width: calc(34 * var(--fs-3))`). Its two lines are reserved as on the homepage, and a negative bottom margin (`calc(-3.2em - 12px)`) takes that space out of the 96px above the first section, so the section and every row sit exactly where they do without the line, whether it is loading, shown or failed. Then `project_rows.html details=true heading="h2"` (featured first and full width with the picture beside the text, then the projects with a picture, then the rest, two across from 700px; picture when set, summary, context, date, and a closed Details with the description and bullets).

### research.md — Research
**Layout:** default. **Data deps:** `site.data.research`.
Header (`.page-head`): h1, one lab line per lab ("<lab>, <institution> · PI <pi> · since <oldest start>", from `positions | group_by: "lab"`; positions are newest first, so the oldest is `items.last`), Google Scholar · All publications. Then the positions section, whose h2 ("Research projects") is `.visually-hidden` so the list follows the page header directly with one `article.study` per position, 72px apart, with `id` = `slug` (the homepage cards link to `/research/#<slug>`): eyebrow (date · role), the 22px/600 title (h3, so the section headings outrank it), then the `description` (34em; first person on what he built) and a closed `<details class="more study-more">` ("+ Details") holding the `focus` items as a two-column grid (h4 18px/600 + 15px detail) and the `note`. There is no result number. When the position sets `figure`, `.study-body.has-figure` puts the figure (`figure_slot.html`) in columns 1–4 and the text in columns 5–12 at >=1024px; without one the text starts at the left edge and no column is left empty. A small inline script opens the Details of the section named in the URL hash on load and on `hashchange`; without JS they stay closed. Then Publications (`pub_rows.html`, selected, sorted by `rank`, with descriptions) and Interests (a two-column grid).

### publications.md — Publications
**Layout:** default. **Data deps:** `site.data.research.publications`, `site.data.research.google_scholar`.
Header (h1, Google Scholar), then ALL publications sorted by `rank` and grouped by `type` (`group_by` after the sort, so the group holding the best-ranked entry comes first and each group keeps rank order): "Posters" (the ADSA poster, rank 1) then "Journal articles". Linked from "All publications" on the homepage and `research.md`.

### cv.md — CV
**Layout:** default. **Data deps:** `site.data.about` (cv_summary, education, skills, teaching, honors), `site.data.research.positions` (`cv: true`), `site.data.research.publications`, `site.data.research.interests`, `site.data.projects.projects` (`cv: true`).
Header: h1, the one-sentence `about.cv_summary`, and a contact row (email · GitHub · LinkedIn · "Resume (PDF)"). Sections are `section.cv-block`s (96px apart, one hairline above each heading); at >=1024px the 28px serif heading sits in a left rail (columns 1–3) and `.cv-body` fills columns 4–12. Order: Education, Skills (a label/line `dl`), Research (the role once in `.cv-role`, then rows titled by `cv_title`), Publications (`pub_rows.html`, all, sorted by `rank`), Projects, Teaching & leadership, Interests, Honors. Dated items are `.row`s 24px apart with the date right-aligned (above the title below 600px). Fully data-driven; edit the data files, not this template.

### editor.md — Studio Page
**Layout:** editor. **Permalink:** `/editor/`, `sitemap: false`. Front matter only; the layout is the app. Dev-only (excluded in `_config_prod.yml`).

### gallery.md — Gallery Page
**Layout:** default. **Permalink:** `/gallery/`. Linked from the blog page header ("Gallery →"); the breadcrumb ("← Home / Blog") links back, and the header is the h1 alone. Merges posts with `images` and non-draft standalone albums into one array, sorted by `date` descending, and renders an album card per item (cover = the `thumb` variant of the first image via `image_src.html`, with width/height from `image_meta.yml`: the thumb's, else the entry's `w`/`h` for an SVG; the first two covers load eagerly, the rest lazily; an 18px/600 `h2` title = a post's `album_title`, else its title; a one-line `album_caption` under it when set (a standalone album without one uses the first sentence of its `description`); date and photo count), three columns at >=1024px, two from 681px, one at 680px and below, frameless covers with a 4px radius and opacity 0.9 on hover. Post-album cards link to the post URL; standalone album cards link to `/albums/:slug/`. There is no "All Photos" grid; photos live on each post or album page. Standalone albums with `draft: true` are excluded from the listing, but Jekyll still builds their pages unless they also set `published: false`.

### album-editor.md — Redirect
`layout: null`, **Permalink:** `/album-editor/`. A meta-refresh page (manual `noai`/`tdm-reservation` meta tags) that sends the old album editor URL to `/editor/#albums`. Dev-only (excluded in `_config_prod.yml`).

### 404.html
**Layout:** default. **Permalink:** `/404.html`, `sitemap: false`. GitHub Pages serves it for unknown URLs. A "Try instead" heading and a plain list of links to the main pages (Research, Projects, Blog, CV; Home is the breadcrumb above the h1).

---

## Data Files

> **Contact info lives in `_config.yml`** (`author`, `email`, `github_username`, `linkedin_username`). There is no `_data/profile.yml` — it was removed as a duplicate. Templates use `site.email`, `site.github_username`, `site.linkedin_username`, and `site.author` directly.

### _data/about.yml
Structured personal data:
- No `headline`: the owner removed the line under the name (he rejected both the slogan and a softer replacement); the hero goes name, credential line, ask, intro
- `seeking`: the internship ask, its own 18px/600 line under the credential line, conversational ("This cycle I'm looking for a Summer 2027 software engineering internship.")
- `intro`: the homepage intro paragraph (Markdown, about 60 words): the research, interests, and one stack clause from resume.tex skills. It opens "I do research in the Sun Lab (PI: Jennifer Sun), building computer vision tools for animal behavior: posture classification for dairy calves from farm video, and video models that recognize behavior across labs."; school, degree and class year are on the credential line, so it does not repeat them
- `outside`: the hero's second paragraph, directly under `intro` ("Outside academics, I play violin in a quartet…", with the Cru at Cornell link; Markdown)
- `cv_summary`: the one sentence under the /cv/ h1
- `bio`: an older, longer bio (reserved; not rendered)
- `education`: institution (Cornell), `institution_url` (https://www.cornell.edu/, the credential line's link), degree (B.S. CS, College of Engineering), `degree_short` ("B.S. Computer Science", the credential line), expected May 2028 (the credential line prints its year as "Class of 2028"), GPA 4.02 (CV only), coursework array (joined with ", " for cv.md)
- `skills`: `languages`, `libraries`, `tools` — plain strings printed as-is on three CV lines; they must match the Technical Skills lines in `resume/resume.tex` exactly (React sits in Languages as "JavaScript (Node.js, Express.js, React)" in both). After editing the .tex, rebuild the PDF and check the log says 1 page
- `teaching`: array of teaching/leadership entries (Basic Coding, Conestoga HS TA), each with title, date, subtitle, bullets (used by cv.md)
- `honors`: array of honor strings (used by cv.md) — BURE Fellow, CIDA Grant Recipient, AIMI Junior Affiliate, 4× AIME Qualifier, USACO Silver
- `blog_blurb`: one-line tagline under the Blog heading

Facts here must match Ryan's master resume (the source of truth for dates, GPA, roles). House style for all site copy: result-first, no hype adjectives, no em dashes in prose (the " — " inside `research.yml` `interests` strings is a separator the templates split on, not prose), never claim solo credit for team work, and say what he did in first person. Sun Lab links go to https://lab.jenjsun.com/.

### _data/projects.yml
Top-level key `projects` — ordered list of 8 projects (research work lives in research.yml, not here), each with: `title`, `date` ("Mon YYYY – present", "Mon YYYY – Mon YYYY", or a season, en dash), `summary` (the result plus his role, in first person; Markdown, bold the one key number sparingly), optional `short` (featured projects: the homepage's one-to-two-line version of the summary, Markdown; the homepage falls back to `summary`, /projects/ always shows `summary`; Worship Rig, DoRA and Sisyphus have one), `context` (short muted meta: course, team and role; shown alone on non-featured homepage rows), optional `featured: true` (at most two: listed first; on the homepage only featured rows show the summary; on /projects/ they are full width), `description` and `bullets` (behind "Details" on /projects/), optional `site` (a project page, shown as "site →") and optional `url` (the repo, shown as "code →"), optional `image` (`{src, alt, width, height}`, /projects/ only: a real picture of the project, a screenshot or a results figure, never a mockup; saved under `assets/images/projects/` as 16:10 WebP about 1200px wide, since the list crops to 16:10; `width`/`height` are its pixel size; `alt` says what the picture shows; leave it out when no real picture exists and nothing is drawn). No `tags`. Current pictures (16:10 WebP, 1200x750 unless noted): Worship Rig `worship-rig.webp` (the app's perform screen, `docs/site/img/perform.webp` from the worship-rig repo, the same screenshot as its project page), DoRA `dora.webp` (the team's `results/figures/figI_dora_vs_lora.png` from leonjiao5/cs4782-project, padded with white to 16:10), Traveling Salesman `traveling-salesman.webp` (the top of `frontend/Sample_flight_frontend.png` from boaz-ng/traveling-salesmen, cropped to 16:10), Geometric Art `geometric-art.webp` (675x422: the original Mona Lisa and its triangle-mesh version, cut from `docs/screenshot.png` in ryanmye/geometric-art). World Seed `worldseed.webp` (the README picture, `docs/world-42-year-4067.png` from ryanmye/worldseed). Personal Website `personal-website.webp` (a light-theme screenshot of the live homepage at a 1440x900 viewport, saved at 1200x750, Oct 2026; retake it when the hero changes) is back so the four pictured non-featured projects fill two rows; keep the pictured count even so no text-only cell sits beside a picture. Sisyphus (no screenshot in its repo; the demo is a phone video) and Piano Melody Generation have none. Current projects (file order, which is Ryan's chosen order as of Oct 2026: DoRA, Worship Rig, World Seed, Geometric Art, then the rest; Worship Rig and DoRA are featured):
Project facts were checked against the repos' commit history (Sep 2026). Ryan's decisions: Worship Rig says "built and shipped" with no mention of how it was built; the DoRA bug is worded "diagnosed"; his Sisyphus role stays general ("worked on the frontend and the AI validation"). Don't reintroduce the claims that were removed: "top 5 of 40+" (it was one of 5 winners among 38 projects), trip sharing on Traveling Salesman (a teammate built it), "fixed" the DoRA bug, or "DoRA showed a consistently larger knows-vs-generates gap" (true in one setting only).
1. **DoRA Re-Implementation and Evaluation** (Spring 2026, featured) — CS 4782 4-person team (Ryan Ye, Boaz Ng, Leon Jiao, Aadi Singla); he ran all experiments on the HPC cluster, wrote the evaluation harness (logit-probe and two-pass scoring), the data scripts with a leakage filter, the analysis and figures, and the first report draft, and diagnosed a critical bug in the DoRA layer. Team finding: trained on little data, both methods often ranked the right AMC12 answer highest but failed to generate it; more data closed the gap and DoRA reached 46% generated, against LoRA's 36% on the same data (not the best overall: LoRA r4 instruct scored 48%); only a partial replication at 3B
2. **Worship Rig** (Sep 2026, featured) — his solo Mac app (Electron + Chrome fallback, Web Audio) that turns a MIDI keyboard into a keys rig for worship bands: its own Web Audio engine, 43 instruments (23 sampled, 16 synth patches, 4 drawbar-organ presets), a key drone, an 8-band EQ per sound, a GarageBand/Logic EXS converter, 1,000+ automated tests and a 20-minute soak test, CI releases for Apple Silicon and Intel (Intel only smoke-tested under Rosetta: say "builds for", not "tested on"). v1.0.0 released 2026-09-30 and v1.0.1 on the way, so the site names no version number; `site` https://ryanmye.github.io/worship-rig/, `url` github.com/ryanmye/worship-rig (commits from both his accounts, ryanmye and ilomacht)
3. **World Seed** (Oct 2026, not featured, not on the CV) — a browser planet and civilization simulator (TypeScript, three.js, a Web Worker): one seed builds a planet and simulates its history year by year (2,000 years by default; peoples, trade, states, wars, faiths, dynasties, disease, ideas), deterministic, no backend and no language model, with nudges, a city view and sagas. The text follows the repo's README as rewritten on 2026-10-07; `site` https://ryanmye.github.io/worldseed/, `url` github.com/ryanmye/worldseed (commits as ilomacht). Picture `worldseed.webp` is the README's `docs/world-42-year-4067.png` (seed 42 in the year 4067), resized to 1200x750
4. **Geometric Art** (Oct 2026, small personal project, not featured, not on the CV) — a browser app (TypeScript, web workers) that rebuilds a photo as overlapping shapes (hill climbing), a triangle mesh or a polygon mosaic (threshold accepting); `site` https://ryanmye.github.io/geometric-art/, `url` github.com/ryanmye/geometric-art. The geometric art album holds animations made with it
5. **Traveling Salesman: Conversational Flight Search** (Mar 2026) — Cornell AI Hackathon; he built most of the React frontend (the 2D map and 3D globe, requirements strip, plan cards; he reworked the scaffolded chat panel) and the agent tool that fills in the planner; teammates built flight search, the rest of the backend and trip sharing (team size unconfirmed; do not state one)
6. **Personal Website** (Mar 2026 – present) — this site
7. **Sisyphus: AI Productivity App** (Nov 2025; not featured since Worship Rig was added) — Claude Builders Club Hackathon at Cornell, Nov 15, 2025, 4-person team; one of 5 winners among 38 projects (Fun Award); he worked on the frontend and the AI validation
8. **Transformer-Based Piano Melody Generation** (Aug 2023 – Apr 2024)

CV display fields (on 5 projects: DoRA, Worship Rig, Traveling Salesman, Sisyphus, Piano Melody Generation; /cv/ lists them in file order):
- `cv: true` — flags project to appear in cv.md
- `cv_tech` — tech subtitle string shown under project title on CV
- `cv_bullets` — array of resume-style bullet points for CV (may differ from `bullets`)

### _data/research.yml
- `google_scholar`: Google Scholar link
- `positions`: 3 entries, newest first:
  1. **Statistical Validation for Automated Hypothesis Discovery** (Summer 2026) — description opens with the finding (FDR 35 to 41% vs a 10% target, 99.3% under adaptive selection, which led to the conservative controller becoming the default; per the master resume, do not say his fixes became the default). Those numbers appear only in the description (prose), not again in `focus`, and never as a display numeral. `homepage: true`, `cv: true`
  2. **Video Behavior Recognition Across Labs (MABe)** (Feb 2026 – present) — description separates his part from the shared lab codebase (he designed the LoRA fine-tuning with the kinematic loss and built the 8-stage SLURM pipeline); `homepage: true`, `cv: true`
  3. **AI for Animal Behavior Monitoring** (May 2025 – present) — description says what he built (annotated the dataset, fine-tuned YOLO, benchmarked DINOv2 vs v3 and VLMs); poster presented at ADSA 2026; `homepage: true`, `cv: true`
  Each entry has `title`, `role`, `lab` ("Sun Lab"), `pi` ("Jennifer Sun"), `institution`, `date` (one format: "Mon YYYY – present" or a season, en dash), multi-line `description`, and a `focus` array of `{title, detail}` objects (the two-column grid inside each /research/ section's Details; each `detail` starts with a capital letter). Position 3 also has `note` (BURE/CIDA grant). `research.md` builds its lab header line from `lab`, `institution`, `pi`, and the oldest position's `date`.
  Never mention the Science manuscript or any other venue for the statistical-validation work.
- `publications`: 3 entries, each with an integer `rank` (1 = most significant, listed first). **Every page sorts by `rank`** (homepage, /research/, /publications/, /cv/), so to reorder, change the numbers; file order does not matter. Current ranks: 1 ADSA 2026 poster (`selected`, `type: poster`; author list still to be completed), 2 JDS lung ultrasound paper (published Sep 2026: full authors "Marina Madureira Ferreira, Keshawa M. Dadallage, Tyler Ward, Hannah McCray, Ryan M. Ye, Jennifer J. Sun, Francisco A. Leal Yepes", venue "Journal of Dairy Science, 2026", `url` https://doi.org/10.3168/jds.2026-28434, supporting author, `selected`, `type: journal`), 3 economics paper (2023, high school, not selected, `type: journal`). The owner's rule: the most significant item leads. `type` groups /publications/ ("poster" → Posters, "journal" → Journal articles; the group with the best-ranked entry first). Each publication has `title`, `rank`, `authors` ("Ryan M. Ye" / "Ryan Ye" / "R. M. Ye" is bolded by `pub_rows.html`), `venue`, `url`, `description`, `role` ("Supporting author" / "Author" / "First author"; printed lowercased after the venue everywhere: "Journal of Dairy Science, 2026 · supporting author"), `selected` (boolean), and `year` (right-aligned in the row). No tags or images. The ADSA poster's role is "Author" (he did not present it). Don't add an Updates item for a publication already listed.
- `interests`: 4 research interest areas, the only interests list (shown on `/research/` and `/cv/`); " — " separates the bold lead from the detail (capitalized).

Card fields (all three positions):
- `slug` — the section id on /research/ (`statistical-validation`, `mabe`, `calf-behavior`); the homepage card links to `/research/#<slug>`
- `card_summary` — the card's two short sentences: what the project is, then what he did (first person). Not a metric: the owner rejected result numerals ("not meaningful in the grand scheme… takes away from the point"). Currently: "The statistical layer that checks an automated scientific-discovery agent's findings. I built it and found where its false-discovery guarantees broke." / "Video foundation models that recognize animal behavior across 15 labs' datasets. I designed the fine-tuning and built the training pipeline on Cornell's GPU cluster." / "Computer vision that classifies dairy calf posture from farm video, for veterinary researchers. I annotated the data and built the detection and classification pipeline."
- `figure` — optional `{src, alt, caption, width, height}` (src repo-relative, e.g. `/assets/images/research/mabe.png`; width/height = the image's pixel size). /research/ renders it through `figure_slot.html` in the right column beside the description; with no `figure` nothing is rendered. Ryan will add these

Homepage and CV display fields (`homepage: true` and `cv: true` on all three):
- `homepage: true` — flags this position for a homepage Selected work card
- `index_title` — shorter title for the homepage card (defaults to `title`)
- `index_description` — one result-first sentence (no venue for statistical validation, no manuscript for MABe); not rendered by the current templates, kept for reuse
- `cv: true` — flags position to appear in cv.md
- `cv_title` — CV entry title, "Sun Lab · <project>" (the role is printed once above the entries)
- `cv_date` — date range string for CV
- `cv_subtitle` — subtitle line for CV (e.g. grant/program info)
- `cv_bullets` — array of resume-style bullet points for CV

### _data/news.yml
The homepage **Updates** list (the section is called "Updates" everywhere a visitor sees it; the file keeps its name). List of `{date, display?, text}`. `date` (YYYY-MM-DD; use day 01 when only the month is known) sorts the list and fills `<time datetime>`; the date prints as "Mon YYYY" unless `display` is set ("Summer 2026"), which is printed as-is; `text` is Markdown (links allowed). `index.md` shows the three newest. Don't add items that repeat something already on the homepage (the publications list sits right above), e.g. no item for the JDS publication.

### Spotify data (not in `_data/`)
The workflow writes `now-playing.json` to the orphan `spotify-data` branch, never to `main`. Schema:
```json
{
 "track": {
 "name": "...", "url": "https://open.spotify.com/track/...",
 "artists": [{"name": "...", "url": "..."}],
 "played_at": "ISO8601"
 },
 "fetched_at": "ISO8601",
 "context": { "type": "playlist|album|artist", "name": "...", "url": "..." }
}
```

### _data/image_meta.yml
Generated image manifest — do not hand-edit. Maps each source image under `assets/images/` to original dimensions (as displayed: EXIF orientation 5–8 swaps them) and pre-generated `thumb` (600w) / `med` (1600w) JPEG variants. Per format: JPEG, PNG, WebP and still GIF have both variants; an animated GIF/WebP has only `thumb` (its first frame) plus `animated: true`, and no `med`; an SVG has only `w`/`h` (from its width/height or viewBox; no entry when it has no usable size). Consumed by `_includes/image_src.html` (URL resolution) and `_includes/photo_card.html` (`width` / `height` attributes for CLS-free layout).

Schema:
```yaml
posts/20260423112441-Screenshot.png:
  w: 3024
  h: 1964
  thumb: { src: posts/20260423112441-Screenshot-thumb.jpg, w: 600, h: 390 }
  med:   { src: posts/20260423112441-Screenshot-med.jpg,   w: 1600, h: 1040 }
  # cf_id: <opaque-id>   # optional; reserved for Cloudflare Images integration
albums/20261001120000-loop.gif:
  w: 480
  h: 320
  thumb: { src: albums/20261001120000-loop-thumb.jpg, w: 480, h: 320 }
  animated: true
albums/20261001120001-diagram.svg:
  w: 400
  h: 240
```

The optional `cf_id` field is preserved across regenerations and is used by `image_src.html` when `site.images.source == "cloudflare_images"`. Produced and updated by `scripts/generate_thumbnails.rb` (CLI backfill) and `scripts/local_editor_server.rb` (on every image upload / delete).

---

## Blog Posts & Albums

Published posts (in `_posts/`):

| File | Title | Date | Tags |
|------|-------|------|------|
| `2025-12-01-i-was-part-of-an-art-exhibit.md` | I Was Part of an Art Exhibit | Dec 1, 2025 | life-update, i'm an artist now |
| `2026-03-12-research-symposium-accepted.md` | Abstract accepted to ADSA! | Mar 12, 2026 | research, life-update |
| `2026-03-17-first-real-blog-post.md` | first real blog post | Mar 17, 2026 | brief life update, test post |

Unpublished drafts (in `_drafts/`):

| File | Title |
|------|-------|
| `first-post.md` | Hello, World — Welcome to My Blog |
| `spring-semester-started.md` | Spring 2026 Semester Started |

Standalone albums (in `_albums/`):

| File | Title | Date | Draft |
|------|-------|------|-------|
| `some-cornell-propaganda.md` | Some Cornell Propaganda | Apr 23, 2026 | no (renamed from `propoganda` Sep 2026; old URL redirected by `redirects/some-cornell-propoganda.html`) |
| `end-of-year-recap.md` | End of Year Recap | Jun 12, 2026 | yes (25 photos, captions pending review). Also `published: false` — Jekyll ignores `draft:` on collections, so without it the page would build and appear in the sitemap. |

`redirects/` holds standalone redirect pages (`layout: null`, explicit `permalink`, `sitemap: false`, manual anti-AI meta tags) for URLs that moved.

Post front matter schema: `layout: post`, `title`, `date` (YYYY-MM-DD or ISO 8601 with timezone), `tags` (array), optional `description` (SEO meta description — all 3 published posts have one), optional `excerpt` (one line he writes; shown on /blog/, else the first 24 words), optional `album_title` (the /gallery/ card title; default: the post title), optional `album_caption` (one line under the gallery card; hidden when empty), optional `images` (array of `{src, caption?}` for photo album — the ones not already in the body are shown at the bottom of the post; the first is the gallery cover). `tags` are not displayed; they feed `article:tag` and JSON-LD `keywords`.

---

## Assets

### assets/css/styles.css
The one public stylesheet (all Studio/editor styles live in `assets/css/editor.css`, which is dev-only). Sections in order: Reset; Custom Properties (the self-hosted @font-face rules for DM Serif Display, JetBrains Mono and Inter, the "Inter Fallback" faces, then all tokens: light palette in `:root`, dark palette in `:root[data-theme="dark"]` and in the `prefers-color-scheme: dark` media query guarded by `:not([data-theme="light"])`); Base Typography (h1–h3, links, skip link, `.visually-hidden`, text-wrap); Layout (`.container`, `.page-content`); Navigation (incl. `.theme-toggle`); Footer; Homepage hero (`.hero*` incl. `.hero-credential`/`.cred-group`/`.cred-item`, `.hero-aside`/`.hero-id`, `.profile-icons`, `.resume-link`, `.profile-faith-note`, `.spotify-widget`); Section headings (`.section-title`, `.section-head`, `.section-more`, `.eyebrow`); Page sections, cards, rows (`.home-section`, `.page-section`, `.work-grid`/`.work-card`/`.work-summary`/`.work-more`, `.home-columns`, `.side-*`, `.rows`/`.row`/`.row-*`, `.teasers`/`.teaser*` (homepage From the blog), `.more` details, `.proj-list`, `.proj-grid`); Research sections (`.study*` incl. `.study-body.has-figure`/`.study-media`, `.focus-*`, `.interest-grid`); Page head (`.page-lede`, `.page-links`, `.page-head .spotify-widget` for the Spotify line on /projects/, `.crumbs`/`.crumb-arrow` for the breadcrumb, `.empty-note`); Blog Post Page (incl. `.post-album` and `.post-image-trigger`); Gallery Page; Album Detail Page (`.album-grid`, `.album-photo*`); Album Lightbox; `.album-end`; CV (`.cv-block`, `.cv-body`, `.cv-role`, `.skill-grid`, `.cv-list`); Responsive (mobile nav, gallery one column, footer).

Tokens:
- Palette: `--bg`, `--surface` (code only, no panels), `--border`, `--text`, `--text-2` (descriptions and bullets; #4A3A2E light, #CFC6BC dark, 10:1 and 9.4:1), `--muted` (dates, venues, counts, labels only), `--accent` (links, active nav, focus only), `--accent-soft`, `--accent-dark` (used by the editor), `--color-code-bg`, `--color-code-text`, `--icon-sun`, `--icon-moon`.
- Type: `--fs-1` 13px (meta, eyebrows, blog year labels, dates), `--fs-2` 15px (summaries, bullets, nav, side column), `--fs-3` `clamp(16px, 15.2px + 0.26vw, 18px)` (body and row titles: 18px from about 1080px), `--fs-4` 22px (card, position and blog titles, featured project titles, brand), `--fs-h2` 28px (section headings and post h2s in the serif), `--fs-title` 40px (post and album h1s, every h1 on phones), `--fs-h1` 56px (page h1s). No numeral token. Body line-height 1.55. Inter weights 400 and 600 only. Fonts: `--font-sans` (Inter, then "Inter Fallback"), `--font-hero` (DM Serif Display), `--font-mono`.
- Spacing: `--s-1`…`--s-9` = 4, 8, 12, 16, 24, 32, 48, 72, 96px. Sections (`.home-section`, `.page-section`, `.cv-block`) are 96px apart with one hairline above the heading (72px under the homepage hero); research positions 72px apart; rows, side items and blog posts 24–32px apart with no lines; blog years 48px apart.
- Radii: `--r-1` 4px (images, code), `--r-2` 8px (lightbox controls, toggle focus), `--r-3` 12px (work cards), `--r-round` 50% (avatar).
- Layout: `--wide` 1120px, `--col-gap` 32px (12-column grids), `--measure` 34em (line length in em of the element's own size, so one token serves every text size: about 70 characters of Inter, 612px at 18px, 510px at 15px); `--card` (card surface: #F6EBE1 / #2F2B27). One transition: `--ease` (150ms, set to 0s under reduced motion) on color, border-color, opacity. The only image hover is opacity 0.9.
Rules of the file: always `var(--name)` for colors, never hex in component styles; no font size or spacing outside the tokens; h1s, section headings and the brand are `--font-hero` (serif), everything else `--font-sans`; lines are the nav border and one rule above each section heading (no row lines, no boxes except the homepage cards); in-content links that are not in a `<p>`/`<li>`/`<dd>` (titles, "All … →", code →, footer) get an underline in `--muted` (at least 5:1) that turns to `currentColor` on hover, so links are never identified by color alone. The Editor and Editor Album sections belong to the dev-only editor and are edited separately.

### assets/css/editor.css (~815 lines, dev-only)
All studio (`/editor/`) styles, moved out of the public stylesheet so the site never ships them. Every selector is prefixed `studio-` (or scoped under `.studio-page`); it reads the palette tokens from `styles.css` and defines only `--danger` / `--ok` (for both themes) on `.studio-page`. Loaded by `_layouts/editor.html` after `styles.css` and Toast UI's CSS; excluded in `_config_prod.yml`. Not covered by `css_version`.

### assets/js/theme.js
IIFE for the light/dark toggle. Maps legacy stored values (warm/linen/pure → light, barely/dark-mono → dark). On load, sets `data-theme` from `localStorage["theme"]` if present; otherwise leaves it unset so the CSS media query follows the OS, and listens for OS changes. `#theme-toggle` click flips the effective theme, saves it, and updates `aria-pressed`, `aria-label`, and `title`.

### assets/js/album-lightbox.js
IIFE that powers the lightbox on post and album pages. **Depends on:** `.album-photo-trigger` buttons rendered by `post.html` / `album.html` with `data-album-index`, `data-full-src`, `data-caption` attributes.

Key behavior:
- `wrapBodyImages()` first wraps every `.post-content img` that is not already inside a link or button in a `<button class="post-image-trigger">` with the same `data-full-src` / `data-caption` attributes (caption = the editor's `*caption*` line under the image, else a `<figcaption>`, else the alt text). The button takes over the image's 70% width limit and margins, so nothing moves.
- On `DOMContentLoaded`, collects all `.album-photo-trigger` and `.post-image-trigger` buttons in document order (body images first, then the post's extra photos). If none, no-ops (no DOM injected, no listeners).
- Injects a single `<div class="album-lightbox" role="dialog" aria-modal="true" hidden>` overlay into `<body>` with close/prev/next buttons, full-size `<img>`, `<figcaption>`, and a counter (`n / total`).
- `showAt(i)` updates image src, alt, caption text, counter. Wraps around via modulo.
- Click a trigger → open at that index; click backdrop or close button → close.
- Keyboard: `Esc` closes; `ArrowLeft` / `ArrowRight` navigate when >1 photo.
- Focus management: saves previously focused element, focuses close button on open, restores focus on close, traps Tab within the overlay.
- Locks body scroll (`document.body.style.overflow = 'hidden'`) while open.
- Sets `data-single="true"` on the overlay when only one photo (hides prev/next and counter via CSS).

### assets/js/editor.js (~1,530 lines)
The studio UI. One IIFE, plain JS, `var`. **Depends on:** Toast UI Editor 3.2.2 (from `editor.html`), `local_editor_server.rb` on `data-api-origin` (default `http://127.0.0.1:4001`; a `?api=<port>` query parameter overrides it). Previews open on `window.location.origin`. If the API answers 403 "Forbidden origin" (it was started for another Jekyll port), `apiRejected()` says so in the offline view with the `STUDIO_SITE_PORT=<port> bin/dev` command. Sections:
- **API:** `api(method, path, body)` (JSON, turns `{error}` / text bodies into `Error`s with `status` and `data`; a network failure calls `apiDown()`), `upload(file, opts, onProgress)` (XHR for per-file progress).
- **Toasts + dialogs:** `toast(msg, {type, duration, action, onAction, onExpire})` replaces `alert()`; `confirmDialog()`; `deleteDialog()` unlocks Delete only when the slug is typed.
- **Library:** `loadLists()` (`GET /posts`, `GET /albums`), `renderSidebar()` with search over title/slug/tags/description/excerpt/album_title/album_caption, arrow-key navigation, collapsible groups (state in localStorage), a dot on rows with a local backup, "front matter does not parse" on rows the server could not read. Welcome view lists recent items.
- **Body editor:** Toast UI in WYSIWYG with a Markdown tab. `getBody()` strips the API origin from image URLs and wraps `/assets/...` images as `{{ '...' | relative_url }}`; `setBody()` reverses it. Toast UI 3.2.2 keeps `*caption*` lines through the WYSIWYG round-trip, so there is no caption-restoring step (an older hack re-added captions the user deleted). `insertImage()` inserts image + caption as markdown, hopping to the Markdown tab and back when in WYSIWYG. `addImageBlobHook` (`bodyImageHook`) uploads pasted/dropped images; Cmd/Ctrl+Shift+K uploads into the text. If a different item is open when the upload finishes, the image is not inserted (a toast names the item; the temp file is left for the cleanup). `usableImages()` keeps JPEG, PNG, GIF, WebP, SVG, HEIC/HEIF, AVIF, TIFF and BMP (by MIME type or extension, `IMAGE_TYPE` / `IMAGE_EXT`) and skips anything else with a toast ("Skipped x.psd: .psd files are not supported. Use …"); the server checks the bytes again. `uploadNote()` toasts what the API did ("Converted IMG_1.HEIC to JPEG.", "Cleaned logo.svg: removed N parts that could run code or load outside files."). The two file inputs (`#photo-input`, `#body-image-input` in `editor.html`) list the same types in `accept`. The `toastui-editor-dark` class follows `data-theme` / the OS via a MutationObserver.
- **Photos (`state.photos`):** one panel for post albums and standalone albums. Drop/browse multiple files (25 max), per-file progress (HEIC and TIFF, which browsers cannot draw, show their file name in the tile, `.studio-photo-name`, until the API returns the JPEG; once the API has converted a file or sanitized an SVG, the tile shows the stored file instead of the local one), caption inputs, HTML5 drag reorder (plus Alt+Arrow), "Use as cover" (albums), "Insert in body" (posts). Upload callbacks only touch the item they started in. Post photos found in the body are flagged `fromBody` (dimmed, caption read-only) by `syncBodyPhotos()`. `removePhoto()` shows a 5 s Undo toast; only after it expires is the src queued in `state.pendingDeletes`, and `flushDeletes()` calls `POST /images/delete` (the server refuses while a saved file still references it, so it retries after the next save).
- **Form state:** `formData()` / `snapshot()`; dirty = snapshot differs from `state.baseline`. Posts send `excerpt`, `album_title`, `album_caption` and albums send `album_caption` (each through `oneLine()`: whitespace runs to one space, trimmed; `''` means "remove the key"), so dirty tracking, backups, the Restore banner, and stale checks cover them; `fill()` loads them and `updateCounters()` / `softCount()` show soft limits (160 for description and excerpt, 120 for album captions; `.is-over` past the limit, nothing is cut). `updateCardHint()` (called from `renderPhotos`) dims `#post-card-fields` and changes its hint while the post has no photos; the fields stay editable. `save()` sets the baseline to the snapshot it **sent**, so edits typed while a save is in flight stay "Unsaved changes" and in the backup; the backup is cleared only when the form still equals what was sent. After a publish, the reload GET only refills the form if nothing was typed while it was pending. Every write sends `state.version` (the file's content hash from the API); a 409 `stale` opens the "changed on disk" dialog (Reload keeps the edits as a backup; Overwrite resends with `force`). Autosave of the form to `localStorage["studio:backup:<kind>:<slug>"]` (with the version it was based on) and a Restore banner that warns when the disk copy is newer. `beforeunload` warns when dirty. Drafts keep an optional date (empty = dated when published).
- **Actions:** `openItem` (a 422 shows the YAML error and does not open the file), `newItem` (new posts start as drafts), `save`, `publishDraft` (confirm, then `save({publish: true})` → `POST /publish/:slug`), `deleteCurrent` (sends the version), `preview` (opens the URL from the API on the Jekyll port; for drafts it HEAD-checks first and explains `--drafts`; draft albums are never built), `copyMarkdown` (a front matter block from `frontMatterText()`: title, date, tags, description, excerpt, album_title, album_caption for posts; title, date, description, album_caption for albums; empty fields left out; then the body or the photo list), `showFile`, `cleanupUploads` (counts `_editor_tmp/` files older than a day, confirms, deletes them except srcs still used by unsaved edits). Routes live in the hash: `#post/<slug>`, `#draft/<slug>`, `#album/<slug>`, `#new-post`, `#new-album`, `#albums`; the hash is reopened when the API comes back. With no hash, `/editor/` opens the most recently modified post, draft, or album (by file `mtime`, `mostRecentItem()`) and sets the hash; a local backup for it still gets the Restore banner. The welcome view shows only when there is nothing to open (or after a delete).
- **Git:** `refreshGit(fetch)` (`GET /git/status`) drives the Publish to site count and sidebar summary. The drawer fetches first, lists changed content files by group with checkboxes, puts draft albums, photos only draft albums use, and `_data/image_meta.yml` when all of its changes concern draft images in an unticked "Drafts (not recommended)" group, lists unpushed commit subjects, warns about other branches, merges/rebases, fetch failures, and being behind, and refuses while any item has unsaved changes (open item or local backups). Default message: `content: <title>` when exactly one post/album is ticked, else `content: update N files`. With nothing ticked and commits waiting, the button becomes "Push N commits to main" (`push_only`). Output of each git step is shown, with a link to GitHub Actions.
- **Other:** Jekyll's livereload would reload the page after every save; `tameLiveReload()` swaps the reload for a "site rebuilt" note. If the API is unreachable with nothing open, `#view-offline` shows the start commands and polls every 4 s. `GET /info` at start: a one-time warning if the API cannot make thumbnails. Esc closes the narrow-screen library; Cmd/Ctrl+S is ignored while a dialog is open.

### assets/images/
- `headshot.jpeg` — profile photo (640×640, ~90KB); the homepage hero photo (280px, sharp at 2x) and og:image
- `posts/` — published post images, naming convention: `YYYYMMDDHHMMSS-originalname.ext`
- `drafts/` — draft post images (same naming convention, gitignored)
- `albums/` — standalone album images (same naming convention)

---

## Scripts

### scripts/local_editor_server.rb (~1,050 lines)
Sinatra REST API on `127.0.0.1:4001` behind the studio. Start with `bin/dev` or `ruby -rbundler/setup scripts/local_editor_server.rb` (not `bundle exec ruby`; the repo path has a space). Env: `STUDIO_SITE_PORT` (Jekyll port allowed as Origin, default 4000), `STUDIO_API_PORT` (listen port, default 4001). **Depends on:** sinatra, json, yaml, fileutils, time, base64, open3, digest (all stdlib or development-group gems), `scripts/image_pipeline.rb` (rexml), and `mini_magick` plus an ImageMagick binary (`magick` or `convert`) on PATH (`ImagePipeline::MAGICK_AVAILABLE` / `IMAGE_TOOL`) for thumbnails and for storing raster uploads (without them SVG uploads and saves still work, raster uploads are refused with a message), plus macOS `sips` for HEIC/HEIF/AVIF (`GET /info` reports `heic`).

**Endpoints:**

| Method | Route | Purpose |
|--------|-------|---------|
| `GET` | `/info` | `{thumbnails, image_tool, heic, site_port, stale_uploads}` |
| `GET` | `/posts` | Sidebar list of posts + drafts: title, date, tags, description, excerpt, album_title, album_caption, kind, slug, path, url, version, `mtime`, `image_count` (no body, no images); unreadable files come back with `error` |
| `GET` | `/posts/:kind/:slug` | Single post/draft with body, images, description, excerpt, album_title, album_caption (`''` when absent), path, url, `version` (422 if the front matter does not parse) |
| `POST` | `/posts` | Create a post or draft |
| `PUT` | `/posts/:kind/:slug` | Update; `draft` in the body moves it between `_posts/` and `_drafts/` |
| `POST` | `/publish/:slug` | Draft → post; same code path as PUT (`save_post(force_post: true)`) |
| `DELETE` | `/posts/:kind/:slug?version=` | Delete post/draft + images nothing else uses |
| `GET` | `/albums` | Sidebar list of standalone albums (same summary shape, plus `draft` and `album_caption`) |
| `GET` | `/albums/:slug` | Single standalone album (with `album_caption`, `version`) |
| `POST` / `PUT` | `/albums`, `/albums/:slug` | Create / update a standalone album (`save_album`) |
| `DELETE` | `/albums/:slug?version=` | Delete standalone album + images nothing else uses |
| `POST` | `/images` | Upload to `_editor_tmp/` (`album=true` / `draft=true`) as `YYYYMMDDHHMMSS-name.ext`, a `-N` suffix when that stem exists with any extension (so `x.png` and `x.svg` never share `x-thumb.jpg`). The name is the upload's, with characters outside `[A-Za-z0-9.-]` as `_`, a trailing `-thumb`/`-med` removed (it would read as a variant) and at most 80 characters. `ImagePipeline.store` runs first, outside the write lock (it can take seconds; the lock is held only to pick the name and move the file): it sniffs the bytes (`ImagePipeline.sniff`; the extension and MIME type are not trusted) and stores JPEG/PNG/WebP/still GIF in the same format with the orientation baked in and EXIF/XMP/IPTC, comments and PNG text chunks removed (ICC kept; re-encoded, JPEG/lossy WebP at quality 92), an animated GIF/WebP with every frame kept and only its metadata stripped (`webpmux` for WebP), an SVG sanitized (`SvgSanitizer`; 422 with the reason), HEIC/HEIF/AVIF as a stripped `.jpg` (sips decodes to TIFF, then one JPEG encode; the HEIC is not stored), TIFF/BMP as a stripped `.jpg`; anything else 415 "x is not an image type the site can use. Use …". Returns `{url, basename}` plus `converted_from` ("HEIC", "AVIF", "TIFF", "BMP") or `svg_removed` (what the sanitizer took out, deduplicated with counts) |
| `POST` | `/images/delete` | `{src}`: delete an image (its temp copy, thumb/med variants, manifest entry) if nothing references it; only under `assets/images/{posts,drafts,albums}/`, only the canonical spelling of the path (400 for `./`, `//`, `..`), never a `-thumb`/`-med` variant on its own |
| `GET` | `/assets/images/*` | Serve images from temp or final dirs; `?variant=thumb` serves the `-thumb.jpg` when present. Content-Type from the extension of the file sent (`ImagePipeline::MIME`; Rack has no `.webp`), and on every response `X-Content-Type-Options: nosniff` and `Content-Security-Policy: default-src 'none'; style-src 'unsafe-inline'; img-src data:; sandbox`, so an SVG opened directly on this origin (which can publish to git) cannot run script or load anything |
| `GET` / `POST` | `/uploads/stale`, `/uploads/cleanup` | Count / delete `_editor_tmp/` files older than 24 h (`{keep: [srcs]}` spares srcs used by unsaved edits) |
| `GET` | `/git/status[?fetch=1]` | Branch, upstream, ahead/behind, `unpushed` subjects, HEAD, in-progress merge/rebase, `fetch_error`, changed content files (with `title` for posts/albums and `draft_only` for draft albums, images only draft albums or `_drafts/` use, and the manifest when every entry that differs from HEAD is such an image) |
| `POST` | `/git/publish` | `{message, paths}` → fetch, `git add -- <files>`, `git commit -m <message> -- <files>`, `git push origin main`; or `{push_only: true}` to push waiting commits. Returns each step's stdout/stderr and HEAD |
| `OPTIONS` | `*` | CORS preflight |

**Writes (`save_post`, `save_album`):** one code path for create, update, and publish. Every write route (posts, albums, publish, deletes, uploads, image deletion, upload cleanup, git publish) runs inside `locked { }` (one `WRITE_LOCK` mutex), so a version check and its write, and every read-modify-write of the manifest, are atomic: two PUTs with the same version give one 200 and one 409. Form dates must be real `YYYY-MM-DD[THH:MM[:SS]]` dates (`parse_form_date`); anything else is a 422 and nothing is written. Every write to an existing file checks `version` (`check_version!`): 409 `{code: "stale"}` if the file changed since the client read it, unless `force`. A file whose front matter does not parse is never loaded or overwritten (422 with the YAML error; `read_front_matter` raises `FrontMatterError`). Posts get `layout` (kept from the file, default `post`), `title`, `date`, `tags`, `description`, `excerpt`, `album_title`, `album_caption`, then every key the editor does not edit (`published`, ..., via `extra_front_matter`), then `images`; albums get `album_caption` right after `description`. The one-line fields are managed keys (`POST_TEXT_KEYS` = excerpt, album_title, album_caption, in `POST_KEYS`; `ALBUM_TEXT_KEYS` = album_caption, in `ALBUM_KEYS`): `text_fields` takes the request's value when it sent the key and the file's otherwise, `one_line` collapses whitespace (newlines too) and trims, an empty value leaves the key out, and `text_fields_to_frontmatter` writes the rest with `yaml_quote`. The public site reads them: `excerpt` on the blog index (Jekyll's own front matter excerpt), `album_title` (fallback: the post title) and `album_caption` on the `/gallery/` cards; a `draft:` key is dropped from posts (location decides). **Drafts keep a date** when they have one: a post turned back into a draft keeps its date and URL and gets them back on publish; a draft without a date is dated when published. Posts always have a date (the form's, else the existing one, else now). Slugs are unique across `_posts/` whatever the date: create, rename, draft→post, and publish all 409 on a clash. Albums: `draft: true` and `published: false` are written together and dropped together; an album with either one reads as a draft; `layout` and unknown keys are kept. Strings are YAML-quoted with `yaml_quote` (JSON escaping); tags stay bare in `[a, b]` unless a tag needs quoting (`tag_scalar`). `resolve_date` keeps the existing date string when the form shows the same wall-clock minute (no churn in seconds or DST offsets). Posts are found by exact slug (`find_post_path`).

**Images when a post changes state:** post → draft leaves images where they are (`assets/images/posts/`). Draft → post: `promote_draft_images` copies each `assets/images/drafts/` image to `posts/` with its `-thumb`/`-med` files and a copy of its manifest entry under the new key (`copy_image`, which regenerates variants, and with them the manifest entry, whenever there was no entry to copy), rewrites the paths, and after the post is written deletes the draft copy only if no other file still uses it (`delete_image_if_orphaned`). A different file already at the destination is left alone (the draft path stays, with a warning in the log). Deleting a post or album removes every image it mentions (the `images:` list plus any `/assets/images/` URL anywhere in the body, inline images included, via `body_image_srcs`) that nothing else references.

**Git publish:** content paths are `GIT_CONTENT_PATHS` = `_posts/ _drafts/ _albums/ assets/images/posts/ assets/images/albums/ _data/image_meta.yml` (`_drafts/` is gitignored, so it never shows). Git runs through `Open3.capture3(GIT_ENV, 'git', *args, chdir: ROOT)` with `GIT_TERMINAL_PROMPT=0` and a low-speed abort, never a shell string. Publish runs `git fetch origin` first and refuses (JSON `{error}`): empty message (400), branch other than `main` (409), merge/rebase/cherry-pick/revert in progress (409), fetch failure (502), `main` behind its upstream (409), `paths` not a subset of the changed files (400), nothing to publish / nothing to push (409). It never uses `git add -A`, and `git commit -- <files>` commits only those files even if others are staged. A rejected push returns 502 with `committed: true` and leaves the commit; `push_only` pushes it later. The push also sends any older unpushed commits on `main` (the drawer lists them). Tested against a local bare remote (happy path, rejection, push-only, behind, branch, merge); never run against GitHub by tests.

**Key helpers:**
- `read_front_matter(path)` / `front_matter!(path)` — `[data, body]`; raises / answers 422 when the YAML does not parse
- `parse_post(path)`, `parse_album(path)`, `summary(path, kind)` — item hashes (with `version` = `file_version`, a SHA-1 prefix of the file) and sidebar rows
- `save_post(data, existing_path:, force_post:)`, `save_album(data, existing_path:)`, `check_version!(path, data)` — see Writes
- `post_front_matter(..., text:, extra:)`, `album_to_file(album, layout:, extra:)`, `one_line`, `text_fields`, `text_fields_to_frontmatter`, `yaml_quote`, `tag_scalar`, `resolve_date`, `extra_front_matter`, `find_post_path`, `post_url` (a draft without a date uses the file mtime, as Jekyll does)
- `extract_body_images(body)` — standalone `![alt](url)` lines + optional `*caption*` → `[{src, caption}]` (album entries); unwraps `{{ '/assets/...' | relative_url }}` (`unwrap_liquid`)
- `body_image_srcs(body)` — every `/assets/images/...` URL in a body (for delete cleanup)
- `merge_images`, `images_to_frontmatter`, `parse_images_from_data`, `parse_image_list`
- `promote_temp_images(body, images)` — moves uploads from `_editor_tmp/` into `assets/images/` and generates thumbnails
- `promote_draft_images(body, images)` → `[body, draft_srcs]`, `copy_image(src_abs, dest_abs)` — see Images when a post changes state
- `find_image_references(src, exclude_path:)`, `delete_image_if_orphaned(src, exclude_path:)` — reference check across posts, drafts, and albums (against both the given and the `canonical_src` spelling); deletion only inside `CONTENT_IMAGE_ROOTS` (`image_src_path`), never a variant on its own (`variant_file?`), always with variants and manifest entry
- `locked`, `parse_form_date` — write mutex; strict form dates (`BadDateError` → 422)
- `extract_base64_images(body, slug:, draft:)` — decodes inline base64 data-URL images into files
- `extract_base64_images(body, slug:, draft:)`: each `data:image/...;base64` image in a body is decoded to a temp file and stored through `ImagePipeline.store` like an upload (the extension comes from the sniffed bytes, never the claimed MIME type; SVGs sanitized, rasters stripped) as `embedded-<slug>-N.<ext>`; anything it refuses (an MVG/MSL script posing as a PNG, an SVG with bad UTF-8) stays inline in the text and is never written
- `generate_thumbnails_for(abs_path)` (writes the entry from `ImagePipeline.build_entry`: both variants, a first-frame thumb only for animated GIF/WebP, size only for SVG), `load_image_manifest`, `write_image_manifest`, `update_image_manifest`, `remove_image_manifest_entry`, `thumbnails_fresh?`, `variant_abs_path`, `image_meta_key`
- `git`, `git_out`, `git_changed_files`, `git_busy`, `annotate_files`, `git_state(fetch:)`, `stale_uploads`, `json_error`

**Image flow:** upload → (HEIC/AVIF/TIFF/BMP converted to JPEG, SVG sanitized) → `_editor_tmp/{posts|drafts|albums}/YYYYMMDDHHMMSS-filename.ext` → promoted to `assets/images/{posts|drafts|albums}/` on save, where `generate_thumbnails_for` writes `-thumb.jpg` / `-med.jpg` (see `_data/image_meta.yml` for what each format gets) and updates `_data/image_meta.yml`.

**Image formats and `scripts/image_pipeline.rb`:** one module shared by the server and `generate_thumbnails.rb`. `ImagePipeline`: `RASTER_EXTS` (.jpg .jpeg .png .gif .webp; get variants), `SOURCE_EXTS` (those plus .svg), `sniff(path)` (kind from magic bytes: jpeg, png, gif, webp, heif for any HEIC/HEIF/AVIF ftyp brand, tiff, bmp, svg), `store` (see `POST /images`; raises `UploadError` with a 415/422 `status`), `clean_raster` / `reencode` / `heif_to_jpeg` (sips → TIFF, which keeps the EXIF orientation and ICC profile, checked against QuickLook for a rotated HEIC; then one JPEG encode with `-auto-orient +profile '!icc,*' +set comment`), `metadata?` / `strip_in_place!` (the `--strip-metadata` backfill), `frame_count` / `expected_variants` / `variants_fresh?` (files only, no ImageMagick, since it runs on every save), `write_variant` (first frame: auto-orient, flatten on white, strip, resize, progressive, quality), `build_entry` (the manifest fields). **ImageMagick safety:** every call goes through mini_magick's `Tool::Magick` (IM7) or `Tool::Convert` (IM6) with an argument array, and every input is named with the coder of its sniffed kind (`coded`: `"jpeg:/path[0]"`, `png:`, `gif:`, `webp:`, `tiff:`, `bmp:`), so a file can never choose its decoder (an SVG, MVG or MSL script renamed `.png` fails as a broken PNG). The module sets `MAGICK_CONFIGURE_PATH` to `scripts/magick-policy/` on load, so every ImageMagick process the server or `generate_thumbnails.rb` starts uses `policy.xml`: MSL, MVG, SVG, MSVG, TEXT, TXT, URL, HTTP(S), FTP, EPHEMERAL, PS/EPS/PDF/XPS and similar coders denied, all delegates and `@file` paths denied, width/height 16KP, area 128MP, memory 512MiB, map/disk 1GiB, time 60 s. `SvgSanitizer.sanitize(xml)` → `[clean, removed]`: first cheap checks (at most 5 MB, valid UTF-8, at most 50,000 tags, a linear tag scan for nesting over 512), then REXML parses (never fetches external entities or DTDs; its expansion limits stop a billion-laughs file; any parse exception becomes `SvgSanitizer::Error`, so a 422, never a 500) and it writes a new document, carrying the namespace map down the tree instead of resolving it per node, with nesting over 256 and output over 10 MB refused: only SVG-namespace elements (an SVG without `xmlns` counts as SVG; Inkscape/RDF metadata is dropped), never `script`, `foreignObject`, `iframe`, `object`, `embed`, `handler`, `listener` or an animation element (`set`, `animate`, …) whose `attributeName` is `href` or `on*`; no `on*` attributes, `href`/`xlink:href` only as a local `#id` or a `data:image/(png|jpeg|gif|webp)` URL, `xml:space`/`xml:lang` kept and `xml:base` dropped, no attributes in other namespaces (`safe_attributes`); CSS is not rewritten: a declaration in `<style>` or `style=""` (split on `{`, `;`, `}` after comments are removed), or any other attribute value, that contains a backslash, `@import`, `image-set(` or a `url(` other than `url(#id)` is removed whole, so `fill="url(#gradient)"` from design tools keeps working; no DOCTYPE/ENTITY (internal entities are expanded into the text, external ones left as literal text), processing instructions (`xml-stylesheet`) or comments. An SVG with only a `viewBox` gets `width`/`height` from it. Limits: it removes known-bad parts of a parsed tree rather than keeping only known-good SVG features, so a feature it does not know about could get through; the API's CSP (and on :4000 the dev plugin's) is the second layer, and on the public site an `<img>` never runs SVG script. **Residual risk:** on GitHub Pages a saved SVG opened directly in a tab is served without a CSP, so there the sanitizer is the only layer (the public origin has no studio powers). `SvgSanitizer.size(xml)` gives the manifest `w`/`h`. Publishing a draft copies its `drafts/` images to `posts/` (variants and manifest entry included) as described above.

**Security (local only, but any web page you visit while it runs can reach 127.0.0.1):** a `before` filter answers 403 unless the `Host` header is `127.0.0.1:4001` or `localhost:4001` (`allowed_host?`, blocks DNS rebinding) and, for any non-OPTIONS request with an `Origin`, unless that Origin is exactly `http://127.0.0.1:4000` or `http://localhost:4000` (`allowed_origin?`; ports follow the env vars). A refused request from another `http://127.0.0.1:<port>` / `localhost` origin gets a readable 403 so the studio can explain; other sites get an opaque one. JSON routes require `Content-Type: application/json` (415 otherwise, 400 on bad JSON) via `json_body`; every path taken from a request goes through `confined_path`, and image deletion is limited to `assets/images/{posts,drafts,albums}/`. The git routes pass the same checks, `/git/publish` reads its body through `json_body`, and git only gets argument arrays. Keep these when adding routes.

### scripts/generate_thumbnails.rb (~165 lines)
Standalone CLI that backfills responsive JPEG variants for every image under `assets/images/{posts,albums,drafts}/` and regenerates `_data/image_meta.yml`. **Depends on:** `mini_magick` and ImageMagick on PATH (aborts with a clear error otherwise).

It uses `scripts/image_pipeline.rb`, so the rules match the server: for each source image (JPEG, PNG, WebP, GIF, SVG; skipping `-thumb.jpg` / `-med.jpg` siblings) it writes (an animated GIF/WebP gets only the thumb, of its first frame; an SVG gets no variants, only `w`/`h` in the manifest):
- `<basename>-thumb.jpg` — max 600w, quality 78, stripped metadata
- `<basename>-med.jpg`   — max 1600w, quality 82, stripped metadata

Every source is auto-oriented and flattened onto white (transparent PNG/GIF/WebP) before JPEG encoding. Images already smaller than a variant width are just resized to their own size (no upscaling). Idempotent — skips files that have a manifest entry and whose variants already exist and are newer than the source (unless `--force`). Preserves any existing `cf_id` field in the manifest.

Usage: `bundle exec ruby scripts/generate_thumbnails.rb [--force] [--only posts|albums|drafts] [--verbose] [--strip-metadata]`. `--strip-metadata` (opt-in, never run by anything else) rewrites existing raster originals that still carry EXIF/XMP/IPTC, a comment or a rotation tag the way uploads are stored now (orientation baked in, metadata removed, re-encoded at quality 92; animated GIF/WebP stripped only) and regenerates their variants; files without metadata are untouched, so a second run changes nothing. It rewrites committed originals, so review the diff first (as of 2026-10-02, 29 of the 71 originals in `posts/` and `albums/` carry such a profile, 6 with camera make/model/capture time, none with GPS). Safe to run repeatedly; primarily needed after externally added images or when adjusting variant sizes. Normal editor uploads generate variants automatically via `local_editor_server.rb`.

### scripts/get-spotify-refresh-token.py (152 lines)
One-time setup script for Spotify integration. Runs OAuth 2.0 authorization code flow:
1. Opens browser to Spotify auth page
2. Captures callback on `localhost:8888`
3. Exchanges code for refresh token
4. Prints token for GitHub Secrets setup

**Scope:** `user-read-recently-played`. **Dependencies:** Python stdlib only.

---

## GitHub Actions

### .github/workflows/deploy.yml
Jekyll build + GitHub Pages deploy. **Triggers:** push to `main`, manual `workflow_dispatch`. Nothing else dispatches it. Build job: `ruby/setup-ruby` (version from `.ruby-version`, `bundler-cache: true`, `BUNDLE_WITHOUT: development:test` at job level) → `jekyll build --config _config.yml,_config_prod.yml` with `JEKYLL_ENV: production` → upload Pages artifact → deploy. Pages source must be set to "GitHub Actions".

### .github/workflows/ci.yml
Runs on `pull_request` and `workflow_dispatch`: same Ruby setup (`BUNDLE_WITHOUT: development`, so html-proofer installs), production build, then `htmlproofer _site --disable-external --allow-missing-href --ignore-urls "/^\/albums\/some-cornell-propoganda\/$/"` (that URL is a redirect page). Add new redirect pages to the ignore list.

### .github/workflows/update-spotify.yml
Automated Spotify "recently played" sync that never touches `main`.

**Trigger:** cron every 30 min (`*/30 * * * *`, GitHub actually runs it every few hours) + manual `workflow_dispatch`. **Permissions:** `contents: write` only. Concurrency group `spotify-data`.

**Steps:**
1. Blob-less sparse checkout of `.github` (credentials only; the site's images are not downloaded)
2. Embedded Python script: exchanges refresh token → access token → `GET /v1/me/player/recently-played?limit=1` → extracts track metadata (name, URL, artists, played_at, context) → writes `$RUNNER_TEMP/now-playing.json`. A failed token refresh prints Spotify's error as a workflow annotation (and a hint to rerun `get-spotify-refresh-token.py` on `invalid_grant`) and exits 1.
3. Publish: fetches the `spotify-data` branch, compares only `track.played_at` (never `fetched_at`), and if it changed or the branch is missing, builds a parentless commit (`now-playing.json` + one-line `README.md`) in a temporary index with git plumbing and `git push --force origin <sha>:refs/heads/spotify-data` as `github-actions[bot]`.

The homepage and /projects/ (both through `_includes/spotify_line.html`) fetch `https://raw.githubusercontent.com/ryanmye/ryanmye.github.io/spotify-data/now-playing.json`. A repository ruleset that covers all branches would block the force-push; scope rulesets to `main`.

**Required secrets:** `SPOTIFY_CLIENT_ID`, `SPOTIFY_CLIENT_SECRET`, `SPOTIFY_REFRESH_TOKEN`

---

## Architecture & Data Flow

### Build Pipeline
`_config.yml` + `_config_prod.yml` (overlay) → Jekyll 3.10 on Ruby 3.3.6 → `_site/`. PRs run `ci.yml` (build + html-proofer); pushes to `main` run `deploy.yml`.

### Page Rendering
`page.md` → selects layout from front matter → layout includes `head.html`, `navbar.html`, `footer.html` → loads `theme.js` → Liquid reads from `_data/*.yml`

### Theme System
`head.html` bootstrap sets `data-theme` from localStorage before paint (or nothing) → `styles.css` resolves the palette from `data-theme` or `prefers-color-scheme` → `navbar.html`'s `#theme-toggle` click → `theme.js` flips `data-theme`, saves to `localStorage["theme"]`, updates the button's ARIA state.

### Spotify Widget
`update-spotify.yml` (cron) → Spotify API → pushes `now-playing.json` to the orphan `spotify-data` branch only when `played_at` changed → the inline JS in `_includes/spotify_line.html` (included by `index.md` and `projects.md`) fetches it from `raw.githubusercontent.com` → un-hides `#spotify-widget` and renders track info in `#spotify-now-playing`. No commit to `main`, no deploy.

### Local Editor System (the studio)
`bin/dev` starts `local_editor_server.rb` (4001) and `jekyll serve --livereload --drafts` (4000; its temporary config also sets `plugins_dir: [_plugins, bin/dev-plugins]`, so `bin/dev-plugins/svg_headers.rb` adds `Content-Security-Policy: default-src 'none'; style-src 'unsafe-inline'; img-src data:; sandbox` and `nosniff` to every `image/svg+xml` response from the dev server and nothing else, since that origin can call the API; production builds never load it) → `/editor/` (`editor.md`, layout `editor`) loads Toast UI Editor 3.2.2 + `editor.js` → `editor.js` calls the API for lists, CRUD, uploads, image deletion, and git → the server reads/writes `_posts/`, `_drafts/`, `_albums/`, stages uploads in `_editor_tmp/`, promotes them into `assets/images/` (with thumbnails + `_data/image_meta.yml`) on save, and on "Publish to site" commits the content paths and pushes `main`, which triggers `deploy.yml`. `/album-editor/` redirects to `/editor/#albums`.

**Running Jekyll with `--drafts`:** a draft without a `date` is dated by its file mtime, so its URL (`/blog/Y/M/D/slug/`) moves to the day of the last save; the API computes draft URLs the same way (a draft that keeps a date uses it). With `--drafts`, drafts also join `site.posts` in dev: they appear on `/blog/` (dated by mtime, so usually at the top), on `/gallery/` if they have `images` (gallery only filters `draft` on albums), in post prev/next links, and in the dev feed/sitemap. `page.draft` is `true` on them. Nothing changes in production, which never passes `--drafts`.

### Photo Gallery
`gallery.md` (linked from blog page) iterates both `site.posts` and `site.albums` → renders album cards (cover, title, date, count) only. Post-album cards link to the post URL (the photos not already in the body are rendered at the bottom of the post page). Standalone album cards link to `/albums/:slug/` (dedicated detail page). Both use the same frameless `.album-photo` grid + shared lightbox. Draft standalone albums (`draft: true`) excluded from gallery.

**Image sources for post albums:**
1. **Auto-detected:** server extracts `![alt](url)` patterns from post body on save → merged into `images` frontmatter
2. **Studio Photos panel:** extra images with captions on the post, saved with the post via `PUT /posts/:kind/:slug`

**Standalone albums:** `_albums/` collection with `output: true`. Each `.md` file has frontmatter: `title`, `date`, `description` (max 500 chars), optional `album_caption` (one line on the gallery card; default: the first sentence of `description`), `draft`, `images: [{src, caption}]`. Layout: `album.html`. Images stored in `assets/images/albums/`.

**Image deletion security:** removing an image from an album calls `POST /images/delete` (after the 5 s undo window) → server checks all posts, drafts, and albums for references → only deletes if orphaned, and only under `assets/images/{posts,drafts,albums}/`. Deleting a post/album also cleans up orphaned images. Draft images in `assets/images/drafts/` are gitignored and won't be published.

### Image Optimization

All album / gallery images flow through a two-tier system (the site builds in Actions, so plugins are allowed; this design just keeps the build dependency-free):

1. **Generation** — `scripts/generate_thumbnails.rb` (CLI backfill) and `scripts/local_editor_server.rb` (on upload / delete) use `mini_magick` to emit two JPEG variants next to every source image under `assets/images/{posts,albums,drafts}/`:
   - `<basename>-thumb.jpg` — 600w max, quality 78 — rendered in grid contexts (an animated GIF/WebP: its first frame, and no med; an SVG: no variants at all)
   - `<basename>-med.jpg`   — 1600w max, quality 82 — rendered in the lightbox
   Both variants plus their pixel dimensions are committed to `_data/image_meta.yml`, which also reserves a `cf_id` field for future Cloudflare Images integration. Originals stay untouched and remain linkable via `data-original-src`.

2. **URL resolution** — `_includes/photo_card.html` builds the cards and delegates every URL construction to `_includes/image_src.html`, which returns a per-variant URL based on `site.images.source`:
   - `local` (default) — uses the manifest to return `/assets/images/...-thumb.jpg` / `-med.jpg`, falling back to the original when no entry exists
   - `cloudflare_resize` — emits `/cdn-cgi/image/width=<W>,quality=<Q>,format=auto/<original>` (requires the zone to have Image Resizing enabled)
   - `cloudflare_images` — emits `https://imagedelivery.net/<account_hash>/<cf_id>/<variant>` (requires `cf_id` in the manifest and `account_hash` in `_config.yml`)

3. **Client-side** — `assets/js/album-lightbox.js` uses the `-med` variant when opening, preloads both neighbors (next + previous) after every navigation, and sets `fetchPriority = 'high'` + `decoding = 'async'` on the lightbox `<img>`. Grid `<img>` elements get `loading="lazy"`, `decoding="async"`, `fetchpriority="low"`, plus intrinsic `width`/`height` from the manifest to prevent CLS.

Switching delivery backends is purely a config flip — no template edits required. Flipping to `cloudflare_resize` skips the committed variants entirely; flipping to `cloudflare_images` relies on populated `cf_id` fields and gracefully falls back to local for any image that has not been uploaded yet.

---

## Conventions & Patterns

- **Post filenames:** `YYYY-MM-DD-slug.md` in `_posts/`, `slug.md` in `_drafts/`
- **Page front matter (root pages):** `layout: default`, `title: "..."`, `permalink: /slug/`, `description: "..."` (SEO meta description, ~150 chars)
- **Post front matter:** `layout: post` (applied by default), `title: "..."`, `date: YYYY-MM-DD` (or ISO 8601), `tags: [array]`, optional `description: "..."` (SEO meta description), optional `excerpt: "..."` (blog index line), optional `album_title` / `album_caption` (gallery card), optional `images: [{src, caption?}]` (photo album, max 25). The `caption` key on each image is optional.
- **Album filenames:** `slug.md` in `_albums/`
- **Album front matter:** `layout: album` (applied by default), `title: "..."`, `date: YYYY-MM-DD`, `description: "..."` (max 500 chars), optional `album_caption: "..."`, optional `draft: true` + `published: false` (always together), `images: [{src, caption?}]`
- **Image naming:** `YYYYMMDDHHMMSS-originalname.ext` (timestamp prefix, set by editor server; a HEIC/AVIF/TIFF/BMP upload ends in `.jpg`)
- **Image formats:** JPEG, PNG, WebP and GIF are stored in their own format (animation kept), with the orientation baked in and EXIF/XMP/IPTC (GPS, camera, capture time) removed; SVG is sanitized; HEIC/HEIF/AVIF and TIFF/BMP become stripped JPEGs on upload. Anything else is refused. Upload names lose a trailing `-thumb`/`-med` and are cut to 80 characters.
- **CSS theming:** always use `var(--name)` for colors; never hardcode hex in component styles
- **Data access:** `_data/` files accessed as `site.data.filename` in Liquid
- **Conditional editor:** nav link + page only appear when `site.local_editor == true` AND `jekyll.environment == "development"`
- **External deps:** Toast UI Editor 3.2.2 (studio only, pinned). Fonts are self-hosted in `assets/fonts/` (from @fontsource, SIL OFL; keep the license files); no Google Fonts. Icons are inline SVGs via `_includes/icon.html` — do not reintroduce Font Awesome.
- **Blog post images:** use markdown `![caption](url)` followed by `*caption*` on the next line (styled by CSS `:has()` selector). Avoid `<figure>` HTML — Toast UI Editor strips it during round-trip.
- **Post headings:** start at `##` (h2) inside a post; the title is the h1.
- **Links:** all external links use `target="_blank" rel="noopener noreferrer"`; internal links to pages use trailing slashes (`/research/`) to avoid a 301 on GitHub Pages
- **No inline styles in pages:** use the components in `styles.css`: `.page-head` (+ `.page-lede`, `.page-links`), `.page-section` / `.home-section`, `.section-head` + `h2.section-title` (+ `.section-more`), `.rows`/`.row` with `.row-date` for anything dated, `details.more` for detail on demand, `.eyebrow`. No tag pills, no result numerals; the homepage research cards are the only boxes.
- **Copy style:** result-first, no hype adjectives, no em dashes in prose, never overclaim team work, flag unverified numbers rather than guess. Matches Ryan's master resume.
- **Anti-AI defense:** See dedicated section below. All 4 layers must be maintained when adding new pages or layouts.

---

## Anti-AI Defense

> **LLM instruction:** This section is a hard requirement. Every time you create or modify a page, layout, or include, verify ALL checklist items below are satisfied. Do not treat this as optional.

The site uses 4 independent layers to block AI crawlers and opt out of AI training data collection. Each layer targets a different mechanism; all four must remain intact.

### Layer 1 — `robots.txt` (crawler-level block)

**File:** [`robots.txt`](robots.txt)

Blocks 20+ known AI training crawlers by `User-Agent`. Legitimate search engines (Googlebot, Bingbot, DuckDuckBot, Applebot) are explicitly allowed. All other crawlers default to allowed (so standard SEO indexing works).

**Blocked agents include:** GPTBot, ChatGPT-User, Google-Extended, anthropic-ai, Claude-Web, CCBot, Bytespider, PerplexityBot, Applebot-Extended, Meta-ExternalAgent, FacebookBot, Amazonbot, Cohere-ai, AI2Bot, Diffbot, img2dataset, and more.

**LLM instruction:** When new major AI crawlers become publicly identified, add a `User-agent: <BotName> / Disallow: /` block to `robots.txt`. Do not remove any existing entries.

### Layer 2 — `<meta name="robots">` (page-level signal)

**File:** [`_includes/head.html`](_includes/head.html)

Every page rendered through any layout that includes `head.html` automatically gets:
```html
<meta name="robots" content="noai, noimageai">
```

- `noai` — signals that page text should not be used for AI training
- `noimageai` — signals that images should not be used for AI training

**LLM instruction:** `head.html` is included in ALL layouts (`default.html`, `post.html`, `album.html`, `editor.html`). `album-editor.md` is a `layout: null` redirect with both meta tags written by hand. Any new layout you create MUST include `{% include head.html %}`. Never create a layout that bypasses `head.html` — doing so removes this protection from that page type.

### Layer 3 — `<meta name="tdm-reservation">` (W3C TDM protocol)

**File:** [`_includes/head.html`](_includes/head.html)

Every page also gets:
```html
<meta name="tdm-reservation" content="1">
```

This implements the [W3C Text and Data Mining Reservation Protocol](https://www.w3.org/2022/tdmrep/). A value of `1` reserves all rights — the site owner has not granted permission for text/data mining (including AI training). This is a formal machine-readable rights declaration, separate from `robots.txt`.

**LLM instruction:** Same as Layer 2 — covered automatically by `head.html`. Do not remove this meta tag from `head.html`.

### Layer 4 — `ai.txt` (Spawning.ai standard)

**File:** [`ai.txt`](ai.txt)

A machine-readable opt-out following the [Spawning.ai `ai.txt` standard](https://site.spawning.ai/spawning-ai-txt). Declares that no content (text, images, media) from this site may be used for AI/ML training. Format mirrors `robots.txt` syntax.

Current content disallows all user-agents:
```
User-Agent: *
Disallow: /
```

**LLM instruction:** This file covers the whole site by default. No per-page action needed. Do not modify the `Disallow` directive.

### LLM Checklist — New Page or Layout

When you create a **new layout file** (`_layouts/*.html`):
- [ ] It must contain `{% include head.html %}` — this automatically adds Layers 2 and 3

When you create a **new root page** (`*.md` or `*.html` with a layout):
- [ ] Verify it uses a layout that includes `head.html` (all current layouts do)
- [ ] No special action needed if using an existing layout

When you create a **new standalone HTML file** (no Jekyll layout, rare):
- [ ] Manually add both meta tags to the `<head>`:
  ```html
  <meta name="robots" content="noai, noimageai">
  <meta name="tdm-reservation" content="1">
  ```

When you **add a new prominent AI crawler** to block:
- [ ] Add to `robots.txt` under the "Block AI training crawlers" section:
  ```
  User-agent: NewBotName
  Disallow: /
  ```

### Summary Table

| Layer | File | Scope | Mechanism |
|-------|------|-------|-----------|
| 1 | `robots.txt` | Crawl-time | User-Agent blocklist |
| 2 | `_includes/head.html` | Every rendered page | `<meta name="robots" content="noai, noimageai">` |
| 3 | `_includes/head.html` | Every rendered page | `<meta name="tdm-reservation" content="1">` (W3C TDM) |
| 4 | `ai.txt` | Whole site | Spawning.ai opt-out standard |
