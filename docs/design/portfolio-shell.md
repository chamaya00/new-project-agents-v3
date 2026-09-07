# Portfolio shell: layout and navigation

Spec for issue #5, part of the portfolio site objective (#2). Covers the two
in-scope pages (Home, About) and the navigation between them. Projects and
posts are a separate objective (#3) and are out of scope here — Home must not
grow a listing for either.

## Happy path

1. Visitor opens the site's root URL. They land on **Home**: a single page,
   nav visible at the top, no scrolling needed to see the nav or know where
   they are.
2. Visitor taps/clicks **About** in the nav. The About page loads. The nav is
   still at the top, in the same position, with **About** now marked as the
   current page.
3. Visitor taps/clicks **Home** in the nav (or a logo/name element that also
   links home). They return to Home, which is marked as current again.

Every step above holds at any viewport width — the difference between mobile
and wider viewports (below) is presentation, not what the visitor can do.

## Mobile layout

Target: phone-width viewports (≈320–480px), single column, no horizontal
scroll anywhere on either page.

- The page is one vertical column: nav band first, then page content below
  it, full width minus a small side margin (16px is enough to keep text off
  the screen edge).
- The nav band holds two elements only: the site/owner name (links to Home)
  and the nav links (Home, About). At this width they stack as a single
  horizontal row: name on the left, links on the right, wrapping to a second
  line only if the name is long enough to force it — never truncated, never
  hidden behind a menu button. Two links do not need a hamburger menu; adding
  one would hide navigation behind an extra tap for no reason at this scale.
- Nothing on the page — text, the nav row, images — is wider than the
  viewport. No element sets a fixed pixel width greater than 100% of the
  viewport; anything wider (e.g. a photo) scales down to fit.
- Tap targets in the nav are at least 44px tall, per usual mobile touch-target
  guidance, so the two links are easy to hit without zooming.

## Home

Purpose: say who the site owner is and what they do, in a few seconds of
reading, then get the visitor to About or back out to wherever they came
from (email, a resume link, etc. — see open question below).

Content, top to bottom:

1. Nav band (see Navigation).
2. Name / heading — who this is.
3. One short line or paragraph — role or focus, in plain language.
4. Optional: a small set of contact/external links (email, GitHub, LinkedIn
   — whichever the owner has). These are plain links, not a component with
   states, since they point off-site.

Nothing else. No project list, no post list, no pagination — that content
belongs to objective #3 and its own child issues when they exist.

## About

Purpose: a longer version of Home's second line — background, how the
visitor got here, what they're looking for.

Content, top to bottom:

1. Nav band (see Navigation).
2. Heading — "About" or the owner's name again, for a visitor who landed
   here directly rather than via Home.
3. Body text — one or more paragraphs. No fixed length; this is copy, not
   layout, and isn't this issue's concern beyond fitting the single-column
   width in Mobile layout above.

## Wider viewports

Breakpoint: 640px. Below it, follow Mobile layout exactly. At 640px and
above:

- The page content (Home's or About's) gets a max content width of 640px,
  centered, with the same 16px+ side margin outside that if the viewport is
  wider still. Text doesn't stretch edge-to-edge on a desktop-width screen —
  that's what makes it unreadable, not what makes it feel unfinished.
- The nav band keeps the same left-name / right-links arrangement as mobile;
  nothing about its structure changes above the breakpoint, only the overall
  page's max-width and centering. There is no second, wider nav pattern to
  design or build.
- No other layout change is in scope for this issue. If a future issue wants
  a sidebar, a two-column About, or similar, that's a new design pass against
  a new acceptance criterion, not an extension of this one.

## Navigation

Reconciled with the researcher's link-strategy finding (#4, comment on that
issue: relative links with no leading slash — root-absolute links 404 under
this repo's GitHub Pages project-site base path).

- The nav is two links: **Home** (`href="index.html"` from a page at the
  repo root, or `href="../index.html"` / the appropriate relative path from
  a nested page) and **About** (`href="about.html"`, relative the same way).
  No link starts with `/`.
- Since there is no build step, every page carries its own copy of the nav
  markup — there is no template to generate it from. The engineer keeps the
  markup identical across pages except for which link is marked current, per
  the component spec below.
- The current page's nav link is visually distinguished (e.g. a different
  weight or an underline — a styling decision for the engineer, not this
  spec) and also carries a non-visual signal (`aria-current="page"`), so the
  distinction survives for screen readers, not just sighted visitors.
- The nav requires no JavaScript. It is a set of `<a>` elements; the browser
  handles navigation natively. This matches the "no build step, no backend"
  constraint from #2 — nothing here depends on a script running first.

## States beyond the happy path

- **Direct entry to About** (visitor's first hit on the site is the About
  URL, not Home): About renders exactly as it does when reached via nav —
  full nav band present, About marked current. No page assumes it's only
  ever reached from another page.
- **No JavaScript / JavaScript disabled**: both pages and the nav work
  identically, since nothing here requires a script (see Navigation).
- **Long content on About**: if body text runs longer than one screen, the
  page scrolls vertically — vertical scroll is expected and fine; only
  horizontal scroll is disallowed (Mobile layout).
- **Very long owner name**: the nav band wraps to a second line (Mobile
  layout) rather than truncating or overlapping the nav links.
- **Missing optional contact links on Home**: if the owner has none to list
  yet, that section is simply absent — not an empty placeholder box, not a
  "coming soon" message.

## Components

**Nav band**
- Purpose: orient the visitor and move them between Home and About.
- Inputs: which page is current (Home or About).
- States: exactly two — Home-current, About-current. No loading or error
  state; this is static markup.
- Must never: use a hamburger/collapsed menu at any viewport in scope, use a
  root-absolute link, or depend on JavaScript to render or to navigate.

**Page content area**
- Purpose: hold the page-specific content (Home's intro, About's body) below
  the nav band.
- Inputs: the page's own content (text, optional links).
- States: normal only. There is no loading state (no data fetch, no
  backend) and no error state (no network call that can fail).
- Must never: exceed the viewport width at any breakpoint (Mobile layout),
  or exceed the 640px max content width above the breakpoint (Wider
  viewports).

## Open question

Home's optional contact/external links (email, GitHub, LinkedIn, resume,
etc.) aren't specified by objective #2 or #3 — I don't know which, if any,
the owner wants, and picking a specific set silently would be guessing at
content, not layout. Recommend the engineering child (#6) either leaves a
single clearly-marked placeholder line for these or confirms the actual set
with a human before building Home; either way, whatever is decided doesn't
change any layout or navigation rule above.
