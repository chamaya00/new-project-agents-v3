# Projects and posts: listings, recent entries, and empty states

Spec for issue #12, part of the portfolio site objective (#3). Covers the
Projects listing page, the Posts listing page, the "recent entries" area
added to Home, and the empty state each of those three shows with no content
yet.

This spec follows the mobile-first / 640px-breakpoint conventions already
set in `docs/design/portfolio-shell.md` (#5) — it references those rules
below rather than restating them, so the new pages and the Home addition
read as the same site.

## Reconciliation with the research finding (#11)

The researcher's `docs/research/content-listing.md` (#11) recommends
building Projects and Posts as Jekyll collections (`_projects/`, `_posts/`)
with a front-matter schema of `title`, `date` (posts take theirs from the
filename, `YYYY-MM-DD-slug.html`, per Jekyll convention; projects carry an
explicit `date` field), `layout`, and an optional `summary`/`excerpt`. That
ADR is still `proposed` — accepting it is a human decision, not this spec's
to make — but the schema is stable enough to design against, and the Entry
component below is built directly on it. If the accepted mechanism ends up
different, only the Entry component's field list needs revisiting; nothing
else here depends on Jekyll specifically.

## Happy path

1. Visitor is on Home. Below the existing fixed content (name, one-liner,
   optional contact links — per `docs/design/portfolio-shell.md`), they see
   a **Recent** area: up to three recent projects, then up to three recent
   posts (see Home placement).
2. Visitor taps/clicks **Projects** in the nav (see Navigation). The
   Projects page loads: a single-column list of Entry cards, most-recent
   first.
3. Visitor taps/clicks an entry's title. They land on that project's full
   page (out of scope here — an individual entry's full-page layout belongs
   to the engineering child, #13, once the content mechanism is built).
4. Visitor taps/clicks **Posts** in the nav. Same structure as Projects,
   for posts.

Every step holds at any viewport width — mobile vs. wider viewports is
presentation only, per portfolio-shell.md's Mobile layout / Wider viewports
sections, referenced rather than restated throughout this doc.

## Navigation

Extends portfolio-shell.md's Nav band component, which currently lists Home
and About only. It gains two more links, in this order: **Home**, **Projects**,
**Posts**, **About** — content pages grouped together between the two
identity pages. Everything else about the nav band (name on the left, links
on the right, relative links with no leading slash, `aria-current="page"` on
whichever is current, 44px tap targets, no hamburger menu) is unchanged;
only the link count and current-page options grow from two to four. This
doc doesn't restate those rules — see portfolio-shell.md's Navigation
section.

## Entry (component)

Purpose: represent one project or one post, identically wherever it
appears — a listing page or Home's Recent area. One component, two content
types feeding it, not two components.

Fields, per the researcher's schema (#11):

- **Title** (required, from front matter `title`). Also the entry's link:
  the whole title is the tap target to the entry's full page. No separate
  "read more" link.
- **Date** (required; posts derive theirs from the filename, projects carry
  it in front matter — the researcher's finding, not a choice made here).
  Rendered as a readable date (e.g. "8 September 2026"), never the raw
  `YYYY-MM-DD` value and never the filename.
- **Summary** (optional, from front matter `summary`/`excerpt`). Shown as a
  short line under the title/date when present. When absent, the field is
  fully absent — no empty box, no "no summary yet" placeholder — same rule
  portfolio-shell.md applies to Home's optional contact links.

States: normal only. Building the site (Jekyll or whatever mechanism is
accepted) happens before anything ships, so there's no loading state and no
network call that can fail at render time — same reasoning portfolio-shell.md
gives for its Page content area component.

Must never: show a raw filename or ISO date string as the visible date;
render an empty summary placeholder when `summary` is absent; wrap the
title in anything but a single link.

## Projects

Purpose: list every project, most recent first, so a visitor can see the
range and depth of someone's work.

Content, top to bottom:

1. Nav band (Home, Projects current, Posts, About).
2. Heading — "Projects".
3. A single-column list of Entry components, most-recent-first by date. No
   pagination, no filtering, no category grouping — out of scope until a
   future issue needs it for volume this objective doesn't yet have.

Layout: single column at any width, per portfolio-shell.md's Mobile layout;
640px max content width, centered, above the breakpoint, per its Wider
viewports section. No new layout rule here — this page is Home/About's page
content area with a list of Entry components in place of body text.

### Empty state

Given zero project files exist:

- **Projects page** shows the heading and nav as normal, and in place of
  the list, one line of static text: "No projects yet." No empty list
  container, no "0 results" count, no pagination controls that would imply
  there's something to page through.
- **Home's Recent projects area** (see Home placement) is fully absent —
  not an empty box, not a "no projects yet" message competing for space
  with the fixed content above it. This matches portfolio-shell.md's rule
  for Home's optional contact links: an empty section doesn't render, it
  disappears. The distinction from the Projects page itself is deliberate —
  a visitor who navigated to Projects asked to see it and gets told why
  it's empty; a visitor scanning Home did not ask for that section
  specifically.

## Posts

Purpose: list every post, most recent first — same structure as Projects,
different content type.

Content, top to bottom:

1. Nav band (Home, Projects, Posts current, About).
2. Heading — "Posts".
3. A single-column list of Entry components, most-recent-first by date.
   Same no-pagination / no-filtering scope limit as Projects.

Layout: identical rules to Projects above — single column, 640px max
content width above the breakpoint, per portfolio-shell.md.

### Empty state

Given zero post files exist, the same two rules as Projects' empty state
apply, substituted for posts:

- **Posts page** shows the heading and nav as normal, and one line of
  static text in place of the list: "No posts yet."
- **Home's Recent posts area** is fully absent, for the same reason given
  under Projects' empty state.

## Home placement

Home's existing content (nav band, name, one-liner, optional contact links)
is unchanged by this issue — this section only defines what gets added
below it, per portfolio-shell.md's explicit scoping-out of listings.

Top to bottom, appended after Home's existing content:

1. **Recent projects** — heading "Recent projects", then up to three Entry
   components, most-recent-first. Absent entirely if zero projects exist
   (Projects' empty state, above).
2. **Recent posts** — heading "Recent posts", then up to three Entry
   components, most-recent-first. Absent entirely if zero posts exist
   (Posts' empty state, above).

Two labeled subsections rather than one merged, date-sorted feed, because
"recent projects" and "recent posts" answer different questions for a
visitor (what have they built vs. what have they written) and merging them
would require picking one sort order across two content types that don't
otherwise compete for rank. If both are empty, both subsections are absent
and Home ends at its existing fixed content — no visible trace that a
Recent area exists at all, consistent with each subsection's own empty-state
rule.

Each Recent subsection uses the same single-column layout and 640px max
content width as the rest of Home — no separate layout rule for this area.

## States beyond the happy path

- **Zero projects, zero posts**: Home shows only its existing fixed content
  (no Recent area at all); Projects and Posts each show their own empty
  state.
- **Fewer than three entries of a type**: the Recent subsection for that
  type shows however many exist (one or two), not padded with placeholders
  and not hidden until three exist.
- **A post or project with no summary**: its Entry renders title and date
  only, per the Entry component's optional-field rule above.
- **Very long title**: wraps within the Entry's width rather than
  truncating — consistent with portfolio-shell.md's rule for a long owner
  name in the nav band (wrap, don't truncate or overlap).

## Open questions

1. **Entry field list is contingent on ADR 0001 (#11) being accepted.** If
   a human picks a different content mechanism than Jekyll, the front-matter
   field names in the Entry component may change; the component's shape
   (title, date, optional summary, single link) should not.
2. **Exact empty-state copy** ("No projects yet." / "No posts yet.") is
   placeholder text, not a fixed requirement — same status as Home's
   contact-links wording in portfolio-shell.md. The engineering child can
   swap the exact wording without changing the structural rule (one line of
   static text, no list container, section fully absent on Home).
