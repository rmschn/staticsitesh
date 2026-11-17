---
Title: Posting Images and Code
Date: 2026-10-12
Description: How images and code blocks look inside a blog entry.
---

This post has no `<!--more-->` marker, so the snippet is just the first
paragraph. That is the default behaviour, and it is usually all you need.

## Images in the body

Any image you drop into `assets/images/` can be used by name:

![A sample image](blog-welcome.svg)

The path is rewritten automatically, so you never have to worry about whether
the page is one folder deep or at the root.

## Code

Fenced code blocks are rendered as-is:

```sh
./build.sh
```

Inline code like `config.sh` is styled subtly so it does not distract.

> Quotes are supported too, and pick up an accent border from your theme.

That is the whole toolbox. Everything here is optional — write as little as a
title and a sentence if that is all you want.
