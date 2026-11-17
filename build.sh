#!/usr/bin/env bash
#
# build.sh — generates the static site into $OUTPUT_DIR (default: docs/).
#
# There is no external dependency beyond bash, awk, sed, coreutils and date.
# Run it after editing anything in config.sh or content/.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

if [ ! -f config.sh ]; then
  echo "error: config.sh not found next to build.sh" >&2
  exit 1
fi
# shellcheck source=config.sh
source ./config.sh

SITE_TITLE="${SITE_TITLE:-My Site}"
SITE_TAGLINE="${SITE_TAGLINE:-}"
SITE_LANG="${SITE_LANG:-en}"
FOOTER_NOTE="${FOOTER_NOTE:-}"
OUTPUT_DIR="${OUTPUT_DIR:-docs}"
CONTENT_DIR="${CONTENT_DIR:-content}"
ASSETS_DIR="${ASSETS_DIR:-assets}"
SNIPPET_LENGTH="${SNIPPET_LENGTH:-240}"
HOME_IMAGE="${HOME_IMAGE:-}"
HOME_IMAGE_ALT="${HOME_IMAGE_ALT:-$SITE_TITLE}"
MENU_ABOUT_TEXT="${MENU_ABOUT_TEXT:-About this site.}"
MENU_BLOG_TEXT="${MENU_BLOG_TEXT:-Posts, newest first.}"
MENU_PROJECTS_TEXT="${MENU_PROJECTS_TEXT:-Projects and builds.}"

case "$OUTPUT_DIR" in
  ""|"."|".."|/*) echo "error: refusing to use OUTPUT_DIR='$OUTPUT_DIR'" >&2; exit 1 ;;
esac

OUT="$ROOT/$OUTPUT_DIR"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------

html_escape() {
  printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'
}

# resolve_image SRC PREFIX -> path usable from a page at PREFIX depth
resolve_image() {
  local src="$1" prefix="$2"
  case "$src" in
    http://*|https://*|//*|/*|data:*|\#*) printf '%s' "$src" ;;
    */*) printf '%s%s' "$prefix" "$src" ;;
    *)   printf '%s%s/images/%s' "$prefix" "$ASSETS_DIR" "$src" ;;
  esac
}

human_date() {
  local d="$1"
  date -d "$d" '+%B %-d, %Y' 2>/dev/null || printf '%s' "$d"
}

date_from_name() {
  printf '%s' "$1" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}' || true
}

title_from_slug() {
  printf '%s' "$1" | sed -E 's/[-_]+/ /g; s/(^|[[:space:]])([a-z])/\1\u\2/g'
}

markdown_html() {
  local prefix="$1" body="$2"
  awk -v PREFIX="$prefix" -f lib/markdown.awk "$body"
}

# read_frontmatter FILE BODY_OUT — sets global META, writes markdown body
read_frontmatter() {
  local file="$1" body_out="$2"
  META=""
  if [ "$(head -n1 "$file" | tr -d '\r')" = "---" ]; then
    META="$(awk 'NR==1{next} /^---[ \t]*$/{exit} {sub(/\r$/,""); print}' "$file")"
    awk 'NR==1{next} /^---[ \t]*$/{f=1; next} f{sub(/\r$/,""); print}' "$file" > "$body_out"
  else
    cat "$file" > "$body_out"
  fi
}

# meta_get KEY [DEFAULT] — reads from global META
meta_get() {
  local key="$1" def="${2:-}" line val
  line="$(printf '%s\n' "$META" | grep -i -m1 "^${key}[[:space:]]*:" || true)"
  if [ -z "$line" ]; then printf '%s' "$def"; return 0; fi
  val="${line#*:}"
  val="${val#"${val%%[![:space:]]*}"}"
  val="${val%"${val##*[![:space:]]}"}"
  printf '%s' "$val"
}

# make_snippet BODY_FILE -> escaped plain-text teaser
make_snippet() {
  local body="$1" part text out
  part="$(awk '
    /<!--more-->/   { exit }
    /^[[:space:]]*$/ { if (started) exit; next }
    /^#/            { if (started) exit; next }
    { started = 1; print }
  ' "$body")"

  text="$(printf '%s\n' "$part" | sed -E \
    -e 's/!\[[^]]*\]\([^)]*\)//g' \
    -e 's/\[([^]]*)\]\([^)]*\)/\1/g' \
    -e 's/\*\*([^*]*)\*\*/\1/g' \
    -e 's/\*([^*]*)\*/\1/g' \
    -e 's/`([^`]*)`/\1/g' \
    -e 's/^[[:space:]]*#+[[:space:]]*//' \
    -e 's/^[[:space:]]*>[[:space:]]*//' \
    -e 's/^[[:space:]]*[-*][[:space:]]+//' \
    | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"

  [ -n "$text" ] || return 0

  out="$(printf '%s' "$text" | awk -v n="$SNIPPET_LENGTH" '
    {
      s = $0
      if (length(s) <= n) { print s; exit }
      s = substr(s, 1, n)
      if (s ~ / [^ ]*$/) sub(/ [^ ]*$/, "", s)
      printf "%s…", s
    }')"
  html_escape "$out"
}

# nav_html PREFIX ACTIVE_ID
nav_html() {
  local prefix="$1" active="$2"
  local ids=(home about blog projects)
  local labels=(Home About Blog Projects)
  local hrefs=("${prefix}index.html" "${prefix}about.html" "${prefix}blog/index.html" "${prefix}projects/index.html")
  local i cls
  printf '<nav class="site-nav" aria-label="Main navigation"><ul>\n'
  for i in "${!ids[@]}"; do
    cls=""
    if [ "${ids[$i]}" = "$active" ]; then cls=' class="active" aria-current="page"'; fi
    printf '        <li><a%s href="%s">%s</a></li>\n' "$cls" "${hrefs[$i]}" "${labels[$i]}"
  done
  printf '      </ul></nav>'
}

# render_page OUTFILE TITLE ACTIVE PREFIX CONTENT_FILE [DESCRIPTION]
render_page() {
  local outfile="$1" title="$2" active="$3" prefix="$4" content="$5" desc="${6:-}"
  [ -n "$desc" ] || desc="$SITE_TAGLINE"
  local full
  if [ "$title" = "$SITE_TITLE" ]; then full="$SITE_TITLE"; else full="$title · $SITE_TITLE"; fi
  mkdir -p "$(dirname "$outfile")"
  {
    cat <<HTML
<!DOCTYPE html>
<html lang="$(html_escape "$SITE_LANG")">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$(html_escape "$full")</title>
  <meta name="description" content="$(html_escape "$desc")">
  <meta name="generator" content="build.sh">
  <link rel="stylesheet" href="${prefix}assets/css/style.css">
  <link rel="stylesheet" href="${prefix}assets/css/theme.css">
</head>
<body>
  <a class="skip-link" href="#main">Skip to content</a>
  <header class="site-header">
    <div class="container header-inner">
      <a class="site-title" href="${prefix}index.html">$(html_escape "$SITE_TITLE")</a>
      $(nav_html "$prefix" "$active")
    </div>
  </header>
  <main id="main" class="container">
HTML
    cat "$content"
    cat <<HTML
  </main>
  <footer class="site-footer">
    <div class="container">
      <p>&copy; $(date +%Y) $(html_escape "$SITE_TITLE"). $(html_escape "$FOOTER_NOTE")</p>
    </div>
  </footer>
</body>
</html>
HTML
  } > "$outfile"
}

# ---------------------------------------------------------------------------
# Build: assets + theme
# ---------------------------------------------------------------------------

echo "→ cleaning $OUTPUT_DIR/"
mkdir -p "$OUT"
find "$OUT" -mindepth 1 -maxdepth 1 -exec rm -rf {} +

if [ -d "$ASSETS_DIR" ]; then
  mkdir -p "$OUT/assets"
  cp -R "$ASSETS_DIR/." "$OUT/assets/"
fi
mkdir -p "$OUT/assets/css" "$OUT/assets/images"

cat > "$OUT/assets/css/theme.css" <<CSS
/* Generated from config.sh — edit config.sh, not this file. */
:root {
  --bg: ${COLOR_BG};
  --surface: ${COLOR_SURFACE};
  --text: ${COLOR_TEXT};
  --muted: ${COLOR_MUTED};
  --primary: ${COLOR_PRIMARY};
  --primary-contrast: ${COLOR_PRIMARY_CONTRAST};
  --link: ${COLOR_LINK};
  --border: ${COLOR_BORDER};
  --header-bg: ${COLOR_HEADER_BG};
  --radius: ${CORNER_RADIUS};
  --content-width: ${CONTENT_WIDTH};
  --font-body: ${FONT_BODY};
  --font-heading: ${FONT_HEADING};
}
CSS

pages=0

# ---------------------------------------------------------------------------
# Home
# ---------------------------------------------------------------------------

home_content="$TMP/home.html"
hero_img=""
if [ -n "$HOME_IMAGE" ]; then
  hero_img="<img src=\"$(resolve_image "$HOME_IMAGE" "")\" alt=\"$(html_escape "$HOME_IMAGE_ALT")\">"
fi

cat > "$home_content" <<HTML
    <section class="hero">
      <div class="hero-image">$hero_img</div>
      <div class="hero-text">
        <h1>$(html_escape "$SITE_TITLE")</h1>
        <p class="tagline">$(html_escape "$SITE_TAGLINE")</p>
      </div>
    </section>
    <section class="menu" aria-label="Site sections">
      <a class="card" href="about.html">
        <h2>About</h2>
        <p>$(html_escape "$MENU_ABOUT_TEXT")</p>
      </a>
      <a class="card" href="blog/index.html">
        <h2>Blog</h2>
        <p>$(html_escape "$MENU_BLOG_TEXT")</p>
      </a>
      <a class="card" href="projects/index.html">
        <h2>Projects</h2>
        <p>$(html_escape "$MENU_PROJECTS_TEXT")</p>
      </a>
    </section>
HTML
render_page "$OUT/index.html" "$SITE_TITLE" home "" "$home_content" "$SITE_TAGLINE"
pages=$((pages + 1))

# ---------------------------------------------------------------------------
# About
# ---------------------------------------------------------------------------

about_src="$CONTENT_DIR/about.md"
if [ -f "$about_src" ]; then
  about_body="$TMP/about.body"
  about_content="$TMP/about.html"
  read_frontmatter "$about_src" "$about_body"
  markdown_html "" "$about_body" > "$about_content"
  render_page "$OUT/about.html" "$(meta_get Title About)" about "" "$about_content" "$(meta_get Description "$SITE_TAGLINE")"
  pages=$((pages + 1))
else
  echo "warning: $about_src not found, skipping About page" >&2
fi

# ---------------------------------------------------------------------------
# Blog and Projects (same engine, different folders)
# ---------------------------------------------------------------------------

build_section() {
  local dir="$1" slug="$2" label="$3"
  local src="$CONTENT_DIR/$dir"
  local list="$TMP/$dir.list.html"
  local count=0
  : > "$list"
  mkdir -p "$OUT/$dir"

  local files=()
  if [ -d "$src" ]; then
    shopt -s nullglob
    files=("$src"/*.md "$src"/*.markdown "$src"/*.txt)
    shopt -u nullglob
  fi
  if [ ${#files[@]} -gt 0 ]; then
    mapfile -t files < <(printf '%s\n' "${files[@]}" | sort -r)
  fi

  local f base slugname title date desc image image_alt body detail snippet meta_line
  for f in "${files[@]:-}"; do
    [ -n "$f" ] || continue
    body="$TMP/entry.body"
    read_frontmatter "$f" "$body"

    base="$(basename "$f")"; base="${base%.*}"
    slugname="$(printf '%s' "$base" | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}-//')"
    title="$(meta_get Title "")"
    [ -n "$title" ] || title="$(title_from_slug "$slugname")"
    date="$(meta_get Date "")"
    [ -n "$date" ] || date="$(date_from_name "$base")"
    desc="$(meta_get Description "")"
    image="$(meta_get Image "")"
    image_alt="$(meta_get ImageAlt "$title")"

    # --- full entry page ---
    detail="$TMP/entry.html"
    {
      printf '    <article class="entry entry-full">\n'
      printf '      <h1 class="entry-title">%s</h1>\n' "$(html_escape "$title")"
      if [ -n "$date" ]; then
        printf '      <p class="meta"><time datetime="%s">%s</time></p>\n' "$(html_escape "$date")" "$(html_escape "$(human_date "$date")")"
      fi
      if [ -n "$image" ]; then
        printf '      <figure class="entry-cover"><img src="%s" alt="%s"></figure>\n' "$(resolve_image "$image" "../")" "$(html_escape "$image_alt")"
      fi
      printf '      <div class="entry-body">\n'
      markdown_html "../" "$body"
      printf '      </div>\n'
      printf '      <p class="back-link"><a href="index.html">&larr; Back to %s</a></p>\n' "$label"
      printf '    </article>\n'
    } > "$detail"
    render_page "$OUT/$dir/$slugname.html" "$title" "$slug" "../" "$detail" "${desc:-$SITE_TAGLINE}"
    pages=$((pages + 1))

    # --- list item ---
    snippet="$(make_snippet "$body")"
    if [ -z "$snippet" ] && [ -n "$desc" ]; then snippet="$(html_escape "$desc")"; fi
    {
      printf '    <article class="entry">\n'
      printf '      <h2 class="entry-title"><a href="%s.html">%s</a></h2>\n' "$slugname" "$(html_escape "$title")"
      if [ -n "$date" ]; then
        printf '      <p class="meta"><time datetime="%s">%s</time></p>\n' "$(html_escape "$date")" "$(html_escape "$(human_date "$date")")"
      fi
      if [ -n "$image" ]; then
        printf '      <figure class="entry-cover"><img src="%s" alt="%s"></figure>\n' "$(resolve_image "$image" "../")" "$(html_escape "$image_alt")"
      fi
      if [ -n "$desc" ]; then
        printf '      <p class="description">%s</p>\n' "$(html_escape "$desc")"
      fi
      if [ -n "$snippet" ]; then
        printf '      <p class="snippet">%s</p>\n' "$snippet"
      fi
      printf '      <p><a class="read-more" href="%s.html">Continue Reading &rarr;</a></p>\n' "$slugname"
      printf '    </article>\n'
    } >> "$list"
    count=$((count + 1))
  done

  if [ "$count" -eq 0 ]; then
    printf '    <p class="empty">Nothing here yet. Add a Markdown file to %s/%s/ and run ./build.sh.</p>\n' "$CONTENT_DIR" "$dir" >> "$list"
  fi

  local index="$TMP/$dir.index.html"
  {
    printf '    <header class="section-header">\n'
    printf '      <h1>%s</h1>\n' "$label"
    printf '    </header>\n'
    cat "$list"
  } > "$index"
  render_page "$OUT/$dir/index.html" "$label" "$slug" "../" "$index" "$SITE_TAGLINE"
  pages=$((pages + 1))

  echo "   $label: $count entr$([ "$count" -eq 1 ] && echo y || echo ies)"
}

build_section blog blog Blog
build_section projects projects Projects

echo "✓ built $pages pages into $OUTPUT_DIR/"
