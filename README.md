# ryanmye.github.io

Personal website and blog of Ryan Ye (CS @ Cornell), live at https://ryanmye.github.io.
It is a Jekyll 3.10 site: homepage, research, projects, publications, CV, blog, photo
albums and gallery, plus a "last played on Spotify" line on the homepage. Most page
content lives in YAML under `_data/`. A local-only editor (the studio, backed by Sinatra) writes posts and albums.

`CLAUDE.md` is a detailed codebase index for LLM tools. This file is the human guide.

## Fresh machine setup (macOS)

1. Install Homebrew tools:
   ```bash
   brew install rbenv ruby-build imagemagick
   ```
   ImageMagick is only needed for image thumbnails (editor server and `generate_thumbnails.rb`).
2. Install the Ruby version pinned in `.ruby-version` (currently 3.3.6). With rbenv:
   ```bash
   echo 'eval "$(rbenv init - zsh)"' >> ~/.zshrc && exec zsh
   rbenv install "$(cat .ruby-version)"   # run inside the repo; rbenv then picks it up automatically
   ruby -v                                # should print 3.3.6
   ```
   asdf works too: `asdf plugin add ruby && asdf install ruby "$(cat .ruby-version)"`.
   Do not use the macOS system Ruby (2.6); the lockfile needs Ruby 3.3.
3. Install gems from the committed `Gemfile.lock`:
   ```bash
   bundle install
   ```
   Gem groups: default (Jekyll), `development` (sinatra, mini_magick for the editor),
   `test` (html-proofer for link checks). CI skips `development`.

## Running locally

```bash
bin/dev
```

That starts the editor API on port 4001 and `jekyll serve --livereload --drafts` on port 4000,
prints http://127.0.0.1:4000/editor/, and stops the API when you press Ctrl+C. It puts Homebrew's
Ruby 3.3 on `PATH` first, warns loudly if something already holds port 4001 (and uses it), and
prints the end of the API log if the API crashes. `STUDIO_SITE_PORT=4010 STUDIO_API_PORT=4011 bin/dev`
moves Jekyll and the API to other ports (the studio page is built to call that API port; by hand,
`/editor/?api=4011` does the same). The site alone, without the editor:

```bash
bundle exec jekyll serve --livereload --baseurl ""
```

Open http://localhost:4000. To build exactly what production serves:

```bash
JEKYLL_ENV=production bundle exec jekyll build --config _config.yml,_config_prod.yml
bundle exec htmlproofer _site --disable-external --allow-missing-href \
  --ignore-urls "/^\/albums\/some-cornell-propoganda\/$/"
```

`_config_prod.yml` turns off the editor and excludes the editor pages, `editor.js`, `editor.css`,
and `bin/`.
Jekyll replaces `exclude:` lists instead of merging them, so both config files carry the full
list. If you add an exclusion, add it to both.

## Studio (local editor)

http://127.0.0.1:4000/editor/ is one page for posts, drafts, and albums (the old
`/album-editor/` URL redirects there). It only exists in development builds.

- **Library** on the left: search (titles, slugs, tags, descriptions, excerpts, album captions), Posts / Drafts / Albums, `+ New post`, `+ New album`.
- **Posts:** title, date, tag chips (Enter or comma adds, Backspace removes), SEO description,
  Excerpt (`excerpt:`, the one line on the blog list; the counter flags past 160 but cuts nothing),
  Draft switch, and the Toast UI editor (WYSIWYG or Markdown). Turning a post back into a draft
  keeps its date, so publishing it again keeps its URL; a draft without a date is dated when
  published. Paste or drop an image into the
  text to upload it in place. The **Photos** panel holds the post's album (`images:`): drop or
  browse several files, add captions, drag to reorder, "Insert in body". Photos already in the
  text show dimmed. Its **Album title** / **Album caption** fields (`album_title:`,
  `album_caption:`) set how the post's card reads on `/gallery/` (the title defaults to the post
  title); they only show there once the post has photos, but can be filled in any time.
- **Albums:** title, date, description (500 max), Album caption (`album_caption:`, one line on the
  gallery card; flagged past 120), Draft switch (writes `draft: true` and `published: false`),
  photos with captions, drag to reorder, "Use as cover".
- Excerpt, album title, and album caption are single lines: an empty field removes the key from
  the front matter, and a save that does not send one (a script, an older tab) keeps what the file
  has.
- **Top bar:** Saved / Unsaved status, Save (Cmd/Ctrl+S), Preview (opens the page on
  port 4000; drafts need `--drafts`, which `bin/dev` passes), Publish draft, and a menu with
  Delete (type the slug to confirm), Copy markdown (the front matter fields, then the body or the
  photo list), the file path, and "Clean up abandoned
  uploads" (unsaved uploads older than a day). Press `?` for shortcuts.
- Unsaved edits are backed up in the browser and offered back ("Restore") after a reload or crash.
  Anything typed while a save is running stays marked unsaved until the next save.
  If the file changed on disk since you opened it (another tab, git, a text editor), Save asks
  whether to reload it or overwrite it. Saves are serialized on the server, and a date that is not
  a real date is refused rather than written. A file whose front matter does not parse is never opened
  or overwritten; the studio shows the YAML error.
  Removing a photo has a 5-second Undo; the file is deleted only after that and once nothing
  saved still references it.
- **Publish to site** commits the changed content files (`_posts/`, `_albums/`,
  `assets/images/posts/`, `assets/images/albums/`, `_data/image_meta.yml`) and pushes `main`,
  which deploys the site. It first fetches from GitHub, then refuses on other branches, during a
  merge or rebase, when the fetch fails, when `main` is behind GitHub (run
  `git pull --rebase`), while the studio has unsaved changes, or without a message. It never
  stages anything outside those paths. Draft albums and photos only they use start unticked in a
  "Drafts (not recommended)" group. If `main` has older unpushed commits, they go out too (the
  panel lists them). If GitHub rejects the push, the commit stays local and the button becomes
  "Push N commits".

To run the API by hand (from the repo root, Ruby 3.3):

```bash
ruby -rbundler/setup scripts/local_editor_server.rb   # listens on 127.0.0.1:4001
```

Use `ruby -rbundler/setup`, not `bundle exec ruby`: the repo path contains a space, and bundler
passes it through `RUBYOPT`, which Ruby splits on spaces.

Uploads go to `_editor_tmp/` first and move into `assets/images/{posts,drafts,albums}/` on save,
which also creates thumbnails and updates `_data/image_meta.yml`. The studio keeps JPEG, PNG, GIF
and WebP in their own format (animated GIFs stay animated), turns HEIC/HEIF/AVIF (iPhone photos,
with macOS `sips`) and TIFF/BMP into JPEG, and cleans SVGs of scripts, event handlers and outside
links. Every photo is stored with its rotation applied and its EXIF, XMP and IPTC data removed, so
location, camera and capture time never reach the site. Other types are refused with a message. The server only answers requests
addressed to `127.0.0.1:4001` / `localhost:4001` and only accepts browser requests from
`http://127.0.0.1:4000` or `http://localhost:4000`, requires `Content-Type: application/json` on
JSON routes, refuses file paths outside `assets/images/` and `_editor_tmp/`, only deletes images
under `assets/images/{posts,drafts,albums}/`, and runs git with argument lists (never a shell).

## Adding content

| What | Where |
| --- | --- |
| Blog post | Studio, or add `_posts/YYYY-MM-DD-slug.md` with `layout: post`, `title`, `date`, `tags`, optional `description` and `images:` list |
| Draft post | Studio, or `_drafts/slug.md` (gitignored, never deployed) |
| Standalone album | Studio, or `_albums/slug.md` with `title`, `date`, `description`, `images:` (each `src`, optional `caption`). Hide one with `draft: true` plus `published: false` |
| Publication | `_data/research.yml` under `publications:` (`selected: true` shows it on the homepage) |
| Research position | `_data/research.yml` under `positions:` |
| Project | `_data/projects.yml` (`cv: true` also lists it on the CV) |
| Bio, education, skills | `_data/about.yml` |

Images belong in `assets/images/posts/` or `assets/images/albums/`; reference them as
`/assets/images/...`. After editing `assets/css/styles.css`, bump `css_version` in `_config.yml`.

## Thumbnails

Albums and the gallery load `-thumb.jpg` (600px) and `-med.jpg` (1600px) variants listed in
`_data/image_meta.yml`. The editor server makes them on save. An animated GIF or WebP gets only a
thumb of its first frame (the page and lightbox show the animated file), and an SVG gets no variants
(it is always shown as is). For images added by hand:

```bash
bundle exec ruby scripts/generate_thumbnails.rb            # only missing or stale ones
bundle exec ruby scripts/generate_thumbnails.rb --force    # regenerate everything
bundle exec ruby scripts/generate_thumbnails.rb --only albums --verbose
bundle exec ruby scripts/generate_thumbnails.rb --strip-metadata  # also strip EXIF/GPS from older originals
```

`--strip-metadata` rewrites originals added before uploads were stripped (only the ones that still
carry metadata or a rotation tag), so check the diff before publishing.

Commit the source image, both variants, and `_data/image_meta.yml` together.

## Spotify "last played"

`.github/workflows/update-spotify.yml` runs every 30 minutes (and on manual dispatch). It
asks the Spotify API for the most recently played track and force-pushes a single commit
containing `now-playing.json` to the orphan branch `spotify-data`, but only when the track's
`played_at` changed. It never commits to `main` and never triggers a deploy. The homepage
fetches the file directly:

    https://raw.githubusercontent.com/ryanmye/ryanmye.github.io/spotify-data/now-playing.json

Do not merge, rebase, or delete the `spotify-data` branch; the workflow recreates it if it is missing.

Setup (one time):

1. Create an app at https://developer.spotify.com/dashboard and add the redirect URI
   `http://127.0.0.1:8888/callback`.
2. Run `python3 scripts/get-spotify-refresh-token.py`, enter the client ID and secret, and
   approve access in the browser. It prints a refresh token.
3. In GitHub, Settings > Secrets and variables > Actions, add `SPOTIFY_CLIENT_ID`,
   `SPOTIFY_CLIENT_SECRET`, and `SPOTIFY_REFRESH_TOKEN`.
4. Run the workflow once from the Actions tab to check it.

If the secrets are missing, the workflow skips quietly. If the token is revoked or expired
(for example after changing your Spotify password or removing the app's access), the run fails
with "Refresh token is revoked/expired". Fix it by running step 2 again and replacing the
`SPOTIFY_REFRESH_TOKEN` secret. The homepage keeps showing the last track until then.

## Deployment

- Settings > Pages > Build and deployment > Source must be **GitHub Actions** (not "Deploy from a branch").
- Every push to `main` runs `.github/workflows/deploy.yml`: Ruby from `.ruby-version`, gems from
  `Gemfile.lock` (without `development` and `test`), production build, Pages deploy.
- Pull requests (and manual runs) run `.github/workflows/ci.yml`: the same build plus html-proofer
  on internal links and images. Nothing is deployed from a PR.
- `Gemfile.lock` is committed and locked for `arm64-darwin` and `x86_64-linux`. After changing
  the Gemfile, run `bundle install` and commit the lockfile. If you work on a new platform, run
  `bundle lock --add-platform <platform>`.

## Resume PDF

`resume.pdf` at the repo root is served at `/resume.pdf` and linked from the CV page. Its
source is `resume/resume.tex` (one page, SWE-internship focus, no phone number). Facts must
match `_data/*.yml`; update both when something changes. Rebuild with Tectonic
(`brew install tectonic`):

```bash
tectonic resume/resume.tex && mv resume/resume.pdf resume.pdf
```

The `resume/` folder is excluded from the Jekyll build in both config files.

## Anti-AI policy

`robots.txt` blocks known AI crawlers, every page carries `noai, noimageai` and
`tdm-reservation` meta tags, and `ai.txt` declares a site-wide opt-out. New pages must keep these.

## License

MIT. Feel free to use this as a template for your own site.
