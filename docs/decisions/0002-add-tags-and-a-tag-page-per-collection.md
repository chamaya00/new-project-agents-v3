# ADR 0002: Add a `tags` field and a stub-file-per-tag `_tags` collection

Date: 2026-09-09
Status: accepted

## Context

Objective #39 requires a page per tag in use across `_posts` and
`_projects`, with no custom Jekyll plugin, no `.github/workflows/` edit, and
no change to this repo's Pages publishing source — the same constraints
`docs/research/content-listing.md` (issue #11) checked its own options
against. `docs/research/tag-pages.md` (issue #40) establishes that core
Jekyll cannot discover front-matter values across files and mint an output
page per distinct value on its own — that's a Generator plugin's job, and
`safe: true` on GitHub Pages' build disables custom plugins outright — and
compares the smallest mechanism that stays inside the constraint against the
alternatives.

## Decision

Add an optional `tags` field (a YAML list of strings) to `_posts` and
`_projects` front matter, alongside the existing `title`/`date`/`layout`/
`summary` fields. Add a new `_tags` collection (declared in `_config.yml`,
`output: true`), containing one hand-authored stub file per tag currently in
use, each carrying only `layout: tag` and `tag: <name>`. A new `tag` layout
renders each stub's matching entries by combining `site.posts` and
`site.projects` with Liquid's `concat` filter, filtering with `where_exp`
for `entry.tags contains page.tag`, and rendering each match through the
existing `_includes/entry.html` partial — all three of `concat`, `where_exp`,
and `entry.html` already exist or ship with Jekyll/Liquid core, so no new
gem is added.

## Consequences

Adding `tags: [...]` to an entry that carries an *already-existing* tag
needs no other edit — the tag page picks it up on the next push, same as
adding a file to `_projects`/`_posts` today. Using a tag for the first time
needs one additional one-line stub file under `_tags/`, and dropping the
last entry that uses a tag needs that stub file deleted in the same commit —
a maintenance step this mechanism cannot enforce on its own, since a stub
file's presence, not its filtered entry count, is what makes Jekyll emit its
page. Left unmaintained, this drifts into a real, reachable, permanently-empty
page for a tag nobody uses, which is the specific failure #39's acceptance
bar rules out; catching that drift would need a check added to
`tests/check.sh` that compares `_tags/` stub files against tags actually
found in `_posts`/`_projects`, which is not part of this decision. No gem,
`Gemfile`, or plugin is added — CLAUDE.md's Stack section needs no further
change beyond what ADR 0001 already made true.

## Alternatives rejected

- **A single tags index page with in-page anchors instead of per-tag
  files**: rejected because it doesn't produce a page per tag at all — an
  anchor on a shared page can't be linked, bookmarked, or crawled
  independently, which fails the plain reading of #39 and this issue's own
  title, even though it would need zero per-tag file maintenance.
- **A custom Jekyll Generator plugin that discovers tags and mints pages
  with no stub files** (the mechanism `jekyll-archives` itself uses):
  rejected outright, not on cost grounds — GitHub Pages' build runs with
  `safe: true` fixed and does not build sites using unsupported plugins, so
  no version of this option runs on the infrastructure this repo is built
  on today.
