# Entry page: an entry's own full page

Spec for issue #67, a child of the objective (#66). Covers what a visitor
sees when they land on one project's or one post's own page — the page
`_includes/entry.html` currently links to but that today renders as an
unstyled fragment with no shell around it, per #66's problem statement.

This spec follows the mobile-first / 640px-breakpoint conventions already
set in `docs/design/portfolio-shell.md` and extends the field list and
naming `docs/design/projects-and-posts.md` set for the Entry component — it
references both rather than restating them, so an entry's own page reads as
the same site as everything else. #66's "Out of scope" list and this issue's
own scope both exclude the URL an entry resolves to (dated vs. a stable
permalink) and whether Home/About/Projects/Posts convert to a shared layout —
this spec covers only what renders once a visitor is on the page, at
whatever URL that turns out to be.

## Happy path

1. Visitor is on Projects, Posts, Home's Recent area, or a tag page, and
   taps/clicks an entry's title. They land on that entry's own page.
2. The page loads: nav band first (see Navigation), then the entry's title
   and readable date, then its tags if it has any (see Tags), then its body
   content.
3. Visitor reads to the end of the body content. Immediately below it is a
   link back to the entry's own listing — Projects for a project, Posts for
   a post (see Closing link).
4. Visitor taps/clicks that link and returns to the listing they came from,
   or to the correct one even if they didn't (see States beyond the happy
   path).

Every step holds at any viewport width, per portfolio-shell.md's Mobile
layout / Wider viewports sections, referenced rather than restated
throughout this doc.

## Content, top to bottom

1. **Nav band.** Same structure as everywhere else on the site: owner name
   on the left, Home / Projects / Posts / About on the right. The current-page
   signal lands on **Projects** if the entry is a project, **Posts** if it's
   a post — not on a fifth "entry" state, because there is no nav link for an
   individual entry to claim. This is the nav band recognising which section
   the page belongs to, the same way About recognises itself when reached
   directly (portfolio-shell.md's Direct entry state) — no new nav state, no
   new nav rule.
2. **Title.** The entry's `title` field, as the page's heading. Unlike its
   appearance in the Entry component on a listing, it is not a link here —
   this page is what that link points to; wrapping the heading in a link to
   itself would go nowhere useful.
3. **Date.** Rendered readable, per the Entry component's existing rule:
   never the raw front-matter value, never the filename. Same format as the
   listing row, so a visitor sees the same date whether they read it on
   Projects or on the entry itself.
4. **Tags**, if the entry has any. See Tags, below, for whether these render
   at all and why.
5. **Body content.** The hand-authored HTML the owner wrote in the entry's
   file — the paragraphs (and whatever else, per Body content states below)
   that are the actual reason the visitor is on this page.
6. **Closing link** back to the entry's own listing. See Closing link,
   below.

Nothing else. No comments, no related-entries list, no share buttons — none
of that is asked for by #66 or this issue, and adding it would be guessing
at content the same way portfolio-shell.md declined to guess at Home's
contact-link set.

## Tags

**Decision: an entry's own page renders its tags, the same way the Entry
component does on a listing — each tag name, linked to that tag's page.**

ADR 0002 (#39/#40) accepts a real cost for tags: a tag used for the first
time needs a hand-authored stub file under `_tags/`, and a tag that loses
its last entry needs that stub deleted in the same commit, or the tag page
survives as a permanently-empty page nothing catches. That cost is incurred
the moment `tags: [...]` is added to an entry's front matter — it does not
grow or shrink based on how many places on the site *display* that entry's
tags afterward. An entry page rendering the tags its front matter already
declares adds no new stub, no new maintenance step, and no new failure mode
beyond what ADR 0002 already accepted.

Against that near-zero marginal cost, not rendering tags here would be a
real loss: the entry's own page is the one place a reader can reach directly
(a shared link, a search result, a tag page's own listing) without ever
passing through Projects or Posts. If that page doesn't show the entry's
tags, a reader who lands there first has no way to discover the entry is
tagged at all, and no path to the tag page that would show them everything
else tagged the same way — despite that page already existing per ADR 0002.
Showing tags here is what makes the tag mechanism reachable from every entry
point, not just the listing ones.

Placement: directly under the date, before the body content — grouped with
the entry's other metadata (title, date, tags) rather than after the body,
so a visitor sees what the entry is tagged as before committing to reading
it, same ordering `_includes/entry.html` already uses for date-then-tags
relative to a listing row's title.

If the entry has no tags, this element is fully absent — no empty "Tags:"
label, no placeholder — the same optional-field rule the Entry component
already applies to its summary field.

## Reuse of `_includes/entry.html`

**Decision: the entry page does not include or extend `_includes/entry.html`.
That partial is left exactly as it is, and the entry page's markup is
written directly in its own layout.**

`_includes/entry.html` has one job: render a listing row. Its title is a
link (to this very page); its date and tags are rendered inline inside an
`<li>` meant to sit inside a `<ul class="entry-list">`. Every one of those
is wrong for the entry's own page — the title isn't a link there (Content,
top to bottom, above), and the page isn't a list item competing for space
with siblings, it's the whole page. Reusing the partial as-is would require
it to grow a mode flag (listing-row vs. full-page), and that flag is exactly
the "grow it to do both jobs" outcome this issue's third acceptance
criterion rules out — the failure it invites is a future edit to one mode
quietly changing the markup the other mode also depends on, with no test
that would say which of the two changed.

The date-and-tags rendering the entry page needs is structurally similar to
what `_includes/entry.html` already does, but similar is not shared: two
small, independent pieces of markup that happen to look alike cost less,
long-term, than one shared piece of markup with a conditional inside it, on
a site with exactly two places that would ever call it.

## Layout

Follows portfolio-shell.md's Mobile layout and Wider viewports sections
exactly — single column at any width, 640px max content width centered
above the breakpoint, 16px+ side margin, no fixed-pixel-width element wider
than its container. No new layout rule. The entry page is Home/About's page
content area (per portfolio-shell.md's Page content area component) with
the Content, top to bottom list above in place of Home's or About's own
content.

The one thing this page adds that Home/About/Projects/Posts don't have is
body content of unpredictable shape — a `<code>` block, a longer paragraph
run, whatever the owner wrote (the `linkrot` and `static-by-choice` entries
already show `<p>` and `<code>` today). None of that changes the layout
rule: it still fits inside the single 640px column, wrapping rather than
overflowing it, the same as About's body text does today.

## Closing link

The last thing on the page, immediately after the body content, is a link
back to the entry's own listing: **"← Back to Projects"** for a project,
**"← Back to Posts"** for a post, pointing at `projects.html` / `posts.html`
respectively (relative, no leading slash, matching the rest of the site's
hand-authored pages, per ADR 0001). This is a fixed structural requirement —
every entry page ends with a link to its own listing, never to the other
one, never to Home. The exact copy ("← Back to Projects" vs. "Back to all
projects" vs. something else) is placeholder text, the same status
projects-and-posts.md gives its empty-state copy — the engineering child can
adjust the wording without changing which page it must point to or that it
must exist.

## States beyond the happy path

- **Direct entry** (a visitor's first hit on the site is an entry's URL, not
  a listing): the page renders exactly as it does when reached via a
  listing — full nav band, correct current-section signal, closing link
  present. No entry page assumes it's only ever reached by clicking through
  from Projects or Posts, the same rule portfolio-shell.md states for direct
  entry to About.
- **No tags**: the Tags element is absent (see Tags, above); nothing else
  about the page changes.
- **Very long title**: wraps within the page's width rather than truncating
  or overlapping the date below it — same rule portfolio-shell.md gives a
  long owner name in the nav band.
- **Body content wider than the column** (a long code line, a wide inline
  element): scales or wraps to the 640px/viewport column like any other
  content on the site: no element is wider than its container, per Layout,
  above. This spec does not add a horizontal-scroll allowance for code the
  way some sites do — out of scope unless a future issue's content actually
  needs it.
- **A project vs. a post**: structurally identical pages. Only two things
  differ, both driven by which collection the entry belongs to: which nav
  link shows as current, and which listing the closing link points to.
  Nothing else about the Content, top to bottom list branches on collection.

## Components

**Entry page**
- Purpose: render one project's or one post's full content as a real page —
  same shell as every other page on the site, distinct from the Entry
  component's listing-row rendering of the same entry.
- Inputs: the entry's `title`, `date`, optional `tags`, and body content;
  which collection it belongs to (drives current-nav and closing-link
  target, per States beyond the happy path).
- States: normal only. Building the site happens before anything ships, so
  there is no loading state and no network call that can fail at render
  time — same reasoning projects-and-posts.md gives the Entry component.
- Must never: link the title to itself; omit the nav band or closing link;
  show a raw filename or ISO date string as the visible date; render an
  empty "Tags:" label when an entry has none; reuse or extend
  `_includes/entry.html` (see Reuse of `_includes/entry.html`, above).

## Open questions

1. **The URL an entry resolves to is out of scope here and decided
   elsewhere.** #66 names moving posts off Jekyll's dated default as its own
   schema change needing its own ADR. This spec's closing link and nav
   current-state logic are written against *which collection an entry
   belongs to*, not its URL shape, so they hold regardless of how that
   question is resolved.
2. **Whether Home, About, Projects, and Posts convert to this same shared
   layout mechanism is a separate, later call**, per this issue's own Out of
   scope section and #66's second numbered risk. Nothing in this spec
   requires that conversion — the new layout only needs to exist and be
   declared by `_posts`/`_projects` files, which is how they've been
   designed to load a `layout` value since `docs/design/projects-and-posts.md`
   (#11's schema already includes `layout`, so no front-matter field is new
   here — no ADR is required for this diff.)
3. **Exact closing-link copy** ("← Back to Projects" / "← Back to Posts") is
   placeholder text, not a fixed requirement — see Closing link, above.
