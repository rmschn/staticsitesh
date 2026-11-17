#!/usr/bin/env bash
# config.sh — every knob for the site lives here.
# Edit this file, then run ./build.sh to regenerate the site.

# --- Identity ---------------------------------------------------------------
SITE_TITLE="My Personal Site"
SITE_TAGLINE="Notes, writing, and projects — no framework required."
SITE_LANG="en"
FOOTER_NOTE="Hand-written content, built with a small shell script."

# --- Home page --------------------------------------------------------------
# A bare filename (no slash) is looked up in assets/images/.
HOME_IMAGE="home.svg"
HOME_IMAGE_ALT="A friendly placeholder illustration"

MENU_ABOUT_TEXT="Who I am, what this site is, and how to get in touch."
MENU_BLOG_TEXT="A continuous stream of posts, newest first."
MENU_PROJECTS_TEXT="Things I have built, am building, or want to build."

# --- Output -----------------------------------------------------------------
# "docs" works with GitHub Pages (publish from the /docs folder) out of the box.
OUTPUT_DIR="docs"
CONTENT_DIR="content"
ASSETS_DIR="assets"

# --- Blog / projects --------------------------------------------------------
# Number of characters shown in the home-page snippet before "Continue Reading".
SNIPPET_LENGTH=240

# --- Color scheme and typography -------------------------------------------
COLOR_BG="#ffffff"
COLOR_SURFACE="#f6f8fa"
COLOR_TEXT="#1f2937"
COLOR_MUTED="#5b6472"
COLOR_PRIMARY="#2563eb"
COLOR_PRIMARY_CONTRAST="#ffffff"
COLOR_LINK="#1d4ed8"
COLOR_BORDER="#dfe3e8"
COLOR_HEADER_BG="#ffffff"

CORNER_RADIUS="10px"
CONTENT_WIDTH="72rem"
FONT_BODY="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif"
FONT_HEADING="inherit"
