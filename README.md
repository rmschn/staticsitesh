# Personal Static Site

A small, dependency-free static website with four sections — **Home**, **About**,
**Blog**, and **Projects** — plus a tiny static site generator written in shell
script (`build.sh`) so there is no framework, no `node_modules`, and nothing to
keep running.

## Quick start

```sh
./build.sh                 # generate the site into docs/
python3 -m http.server -d docs 8000   # preview at http://localhost:8000
```

Open `docs/index.html` directly in a browser if you prefer.

## What is here

```
config.sh            every setting: title, colors, dimensions, output folder
build.sh             the generator (bash + awk)
lib/markdown.awk     minimal Markdown -> HTML converter
content/
  about.md           the About page
  blog/*.md          one file per blog post
  projects/*.md      one file per project
assets/
  css/style.css      layout; colors come from theme.css
  images/*           images you can use in posts, projects, and the home page
docs/                GENERATED output — do not edit by hand
```

## Editing the site

| I want to... | Do this |
| --- | --- |
| Change the site title / tagline | edit `config.sh`, run `./build.sh` |
| Change colors or fonts | edit the color block in `config.sh`, run `./build.sh` |
| Edit the About page | edit `content/about.md`, run `./build.sh` |
| Add a blog post | add `content/blog/YYYY-MM-DD-name.md`, run `./build.sh` |
| Add a project | add `content/projects/YYYY-MM-DD-name.md`, run `./build.sh` |
| Remove an entry | delete its Markdown file, run `./build.sh` |
| Add an image | drop it in `assets/images/`, reference it by name |

Posts and projects are sorted **newest first** using the `YYYY-MM-DD-` prefix in
the filename, so keep that prefix to control ordering.

## Writing a blog post or project

Each file is plain Markdown with a short header:

```markdown
---
Title: My Post
Date: 2026-10-20
Description: One sentence shown in the list.
Image: my-photo.svg        # optional cover image; bare name means assets/images/
ImageAlt: What the image shows
---

Opening paragraph shown as the snippet on the index page.

<!--more-->

Everything after the marker only appears on the full post page.
```

- Without a `<!--more-->` marker the snippet is just the first paragraph.
- `Title`, `Date`, and `Description` are all optional; sensible defaults are
  derived from the filename.

### Markdown supported

Headings (`#`, `##`, ...), **bold**, *italic*, `inline code`, [links](about.html),
images `![alt](my-photo.svg)`, bullet lists, block quotes, `---` rules, and
fenced code blocks.

Image paths and links are rewritten automatically, so you can write
`![alt](my-photo.svg)` or `[text](projects/index.html)` from any page and they
resolve correctly whether the page is at the root or one folder deep.

## How it works

1. `build.sh` reads `config.sh`.
2. It writes `docs/assets/css/theme.css` from your color settings.
3. It copies `assets/` into the output.
4. For `about.md`, and every file in `content/blog/` and `content/projects/`, it
   renders a full page plus, for blog/projects, an index entry with a snippet and
   a **Continue Reading** link.
5. The header navigation (Home / About / Blog / Projects) is included on every
   page.

The output is plain HTML/CSS/SVG — nothing else is required to serve it.

## Theming

Colors, corner radius, content width, and fonts are set in the `Color scheme and
typography` block of `config.sh`. They are written to `docs/assets/css/theme.css`
as CSS custom properties, so changing one value and re-running `./build.sh`
restyles the whole site. `assets/css/style.css` holds the layout and only reads
those variables.

## Responsive behavior

Every page has a proper viewport meta tag. The layout uses a two-column hero and
an auto-fitting card grid that collapse to a single column below 720px, and the
navigation wraps neatly on small screens.

## Deploying

The site is fully static, so anything that serves files works.

**GitHub Pages (recommended):** the output directory defaults to `docs/`.
Commit the repository, then in *Settings → Pages* choose
*Deploy from a branch* → your branch → `/docs`. The generated files must be
committed for this to work.

**DigitalOcean / Netlify / any static host:** point the host at the folder
`OUTPUT_DIR` produces (`docs/` by default) as the publish directory.

To build somewhere else (for example a `site/` folder that you `.gitignore`),
change `OUTPUT_DIR` in `config.sh`.

## Notes

- No third-party tools or services are used. Requires only `bash`, `awk`, `sed`,
  `find`, and GNU `date` (present on Linux and macOS with `gdate`, or edit
  `human_date` in `build.sh`).
- `docs/` is generated: edit files in `content/` and `assets/`, never the output.
