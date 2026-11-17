# markdown.awk — a tiny Markdown -> HTML converter used by build.sh
#
# Usage: awk -v PREFIX="../" -f lib/markdown.awk BODY.md
#
# PREFIX is prepended to relative links and images so that pages living in
# sub-folders (blog/, projects/) still resolve things correctly.
#
# Supported syntax:
#   # H1 .. ###### H6      headings
#   paragraphs             blank-line separated
#   - item / * item        bullet lists
#   > quote                block quote
#   ---                    horizontal rule
#   **bold**  *italic*  `code`
#   [text](url)            links
#   ![alt](image)          images (bare filename -> assets/images/)
#   ``` ... ```            fenced code block

function hesc(s) {
  gsub(/&/, "\\&amp;", s)
  gsub(/</, "\\&lt;", s)
  gsub(/>/, "\\&gt;", s)
  gsub(/"/, "\\&quot;", s)
  return s
}

function is_absolute(u) {
  return (u ~ /^[A-Za-z][A-Za-z0-9+.-]*:/ || u ~ /^\/\// || u ~ /^\// || u ~ /^#/)
}

function img_uri(u) {
  if (is_absolute(u)) return u
  if (u ~ /\//) return PREFIX u
  return PREFIX "assets/images/" u
}

function link_uri(u) {
  if (is_absolute(u)) return u
  return PREFIX u
}

function inline(t,   s, pos, label, uri) {
  t = hesc(t)

  while (match(t, /!\[[^]]*\]\([^)]*\)/)) {
    s   = substr(t, RSTART, RLENGTH)
    pos = index(s, "](")
    label = substr(s, 3, pos - 3)
    uri   = substr(s, pos + 2, length(s) - pos - 2)
    t = substr(t, 1, RSTART - 1) "<img src=\"" img_uri(uri) "\" alt=\"" label "\">" \
        substr(t, RSTART + RLENGTH)
  }

  while (match(t, /\[[^]]*\]\([^)]*\)/)) {
    s   = substr(t, RSTART, RLENGTH)
    pos = index(s, "](")
    label = substr(s, 2, pos - 2)
    uri   = substr(s, pos + 2, length(s) - pos - 2)
    t = substr(t, 1, RSTART - 1) "<a href=\"" link_uri(uri) "\">" label "</a>" \
        substr(t, RSTART + RLENGTH)
  }

  while (match(t, /\*\*[^*]+\*\*/)) {
    inner = substr(t, RSTART + 2, RLENGTH - 4)
    t = substr(t, 1, RSTART - 1) "<strong>" inner "</strong>" substr(t, RSTART + RLENGTH)
  }

  while (match(t, /\*[^*]+\*/)) {
    inner = substr(t, RSTART + 1, RLENGTH - 2)
    t = substr(t, 1, RSTART - 1) "<em>" inner "</em>" substr(t, RSTART + RLENGTH)
  }

  while (match(t, /`[^`]+`/)) {
    inner = substr(t, RSTART + 1, RLENGTH - 2)
    t = substr(t, 1, RSTART - 1) "<code>" inner "</code>" substr(t, RSTART + RLENGTH)
  }

  return t
}

function flush_p() {
  if (p != "") { print "<p>" inline(p) "</p>"; p = "" }
}

function flush_li() {
  if (inli) { print "</ul>"; inli = 0 }
}

{
  line = $0
  sub(/\r$/, "", line)

  if (incode) {
    if (line ~ /^[ \t]*```/) { print "</code></pre>"; incode = 0 }
    else                     { print hesc(line) }
    next
  }

  if (line ~ /^[ \t]*```/) { flush_p(); flush_li(); print "<pre><code>"; incode = 1; next }
  if (line ~ /^[ \t]*$/)   { flush_p(); flush_li(); next }
  if (line ~ /^[ \t]*<!--more-->[ \t]*$/) { flush_p(); flush_li(); next }

  if (line ~ /^#+[ \t]/) {
    flush_p(); flush_li()
    match(line, /^#+/)
    n    = RLENGTH
    text = substr(line, n + 2)
    sub(/[ \t]+#+[ \t]*$/, "", text)
    print "<h" n ">" inline(text) "</h" n ">"
    next
  }

  if (line ~ /^(---|\*\*\*)[ \t]*$/) { flush_p(); flush_li(); print "<hr>"; next }

  if (line ~ /^[ \t]*[-*][ \t]/) {
    flush_p()
    if (!inli) { print "<ul>"; inli = 1 }
    item = line
    sub(/^[ \t]*[-*][ \t]+/, "", item)
    print "<li>" inline(item) "</li>"
    next
  }

  if (line ~ /^>[ \t]?/) {
    flush_p(); flush_li()
    q = line
    sub(/^>[ \t]?/, "", q)
    print "<blockquote><p>" inline(q) "</p></blockquote>"
    next
  }

  if (inli) flush_li()
  if (p == "") p = line
  else         p = p " " line
}

END {
  flush_p()
  flush_li()
  if (incode) print "</code></pre>"
}
