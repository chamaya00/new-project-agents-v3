# ADR 0004: Give posts a stable, non-dated permalink

Date: 2026-09-11
Status: accepted

## Context

Projects resolve to `/projects/<slug>/`, a stable URL set by the `permalink`
Jekyll gives that collection in `_config.yml`. Posts have no equivalent line,
so they fall back to Jekyll's built-in default and resolve to a dated path
such as `/2026/08/20/writing-html-by-hand-again.html`. The two collections
are meant to read as one system (`_includes/entry.html` renders both
identically, per `docs/design/projects-and-posts.md`), and a post's URL
should not encode a fact - its publish date - that a project's URL does not.

## Decision

Give posts a `permalink: /posts/:title/` default in `_config.yml`, scoped to
`type: posts` through Jekyll's `defaults` mechanism rather than set as the
top-level `permalink` key. `:title` resolves to the post's slug - the
filename with its leading date and extension stripped - giving
`/posts/<slug>/`, the same directory-plus-`index.html` shape
`/projects/<slug>/` already has. No page hand-types a post path -
`_includes/entry.html` already links every entry through
`entry.url | relative_url` - so `entry.html`, `posts.html`, and `index.html`
need no change to keep linking correctly.

The top-level `permalink` key was tried first and rejected: it also sets
Jekyll's site-wide `permalink_style`, which changes how plain `Page` objects
resolve their own URLs, not just posts. With it set, `jekyll build` moved
`posts.html` and `projects.html` themselves to `posts/index.html` and
`projects/index.html`, breaking the listing pages outright - caught by
watching the rewritten `tests/check.sh` assertions fail for the wrong reason
before switching to the `defaults`-scoped form, which touches only documents
of `type: posts`.

## Consequences

Every post's URL drops its date segment and stabilizes: publishing an entry
no longer bakes its publish date into the link people share, and re-dating a
post's front matter (if that ever happens) no longer moves its URL. The old
dated URLs - `/2026/08/20/writing-html-by-hand-again.html` and the like -
stop resolving outright; this repo publishes no redirect from the old shape
to the new one, so any link already shared against the dated form breaks.
That is judged acceptable here: the site has no history of publishing posts
under the old scheme (this change lands before any real-world traffic could
depend on it), and adding a redirect mechanism is out of scope for a
same-diff URL change with no JavaScript and no server to run one.

## Alternatives rejected

- **Keep the dated default and link to it as-is**: rejected because it is
  the problem this ADR exists to fix - it leaves posts inconsistent with
  projects' stable `/projects/<slug>/` and bakes a date into every post's
  shareable link.
- **Emit per-post redirect stub pages at the old dated paths**: rejected as
  unnecessary scope for this issue - the site has published nothing under
  the old scheme yet, so there is no live link to preserve, and a redirect
  mechanism can be added later, under its own issue and ADR, if that
  changes.
