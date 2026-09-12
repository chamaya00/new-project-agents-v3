# Visual system: palette, type scale, spacing, and component specs

Spec for issue #78, part of the objective at #77. None of the existing
design docs (`docs/design/portfolio-shell.md`, `docs/design/projects-and-posts.md`,
`docs/design/entry-page.md`) say anything about colour, contrast, typography,
or buttons — this doc is that ground, and the three engineering children of
#77 build against it directly rather than each picking a colour or a size on
their own.

This doc does not redesign layout, navigation structure, or content — those
stay exactly as `portfolio-shell.md`, `projects-and-posts.md`, and
`entry-page.md` already specify. It only adds the visual tokens and component
states those docs left unstated (`css/style.css`'s 138 lines today cover
layout and a handful of ad-hoc colours/sizes, listed below wherever this doc
builds on one of them).

## Scope and constraints

- **System fonts only** — no webfont, no icon font, no icon set. A webfont is
  a new outbound destination under the house rules; icons aren't needed for
  anything specified here. `body`'s existing `font-family: system-ui,
  -apple-system, "Segoe UI", sans-serif` (`css/style.css` line 12) is
  unchanged and is the only font stack this system uses.
- **Dark mode is `prefers-color-scheme: dark` only — there is no toggle
  control.** Out of scope for this objective. The Dark palette below applies
  automatically inside a `@media (prefers-color-scheme: dark)` block; nothing
  here adds a switch, a stored preference, or JavaScript of any kind.
- **CSS custom properties (`--color-bg`, `--space-3`, etc.) are a styling
  mechanism, not a schema/data-shape/dependency change** under the house
  rules — this issue and its dependants don't need an ADR to introduce them.
- Every colour pair the site actually renders is named below, in both
  schemes (see Colour pairs), so an engineer knows exactly which pairs to
  hold to WCAG AA (4.5:1 body text, 3:1 large text and non-text indicators
  including focus rings). This doc does not compute those ratios itself —
  the check that enforces AA reads the shipped CSS in a later engineering
  child, not this doc — but every value chosen here was picked to clear its
  bar.

## Light

- **Background:** `#ffffff`
- **Text:** `#1a1a1a` (unchanged — already `body`'s colour, `css/style.css`
  line 14)
- **Accent:** `#1552cc` — used consistently for every interactive element:
  link colour, chip text, button fill, focus ring.
- **Surface:** `#f4f6fa` — the tone that separates an entry (or any card-like
  grouping) from the page background behind it.
- **Border/divider:** `#e0e0e0` (unchanged — already used for `.nav` and
  `.entry`'s `border-bottom`, `css/style.css` lines 30 and 87)
- **Muted text** (metadata, not one of the five required tokens above but
  needed for entry dates): `#595959` (unchanged — already `.entry__date`'s
  colour, `css/style.css` line 108)

## Dark

- **Background:** `#121212`
- **Text:** `#e8e8e8`
- **Accent:** `#5b9dff`
- **Surface:** `#1c1f26`
- **Border/divider:** `#333333`
- **Muted text** (metadata): `#b0b0b0`

## Colour pairs

Every pair the site will actually render, foreground on its own background,
named in both schemes so an engineer can check each one against WCAG AA
without guessing which pairs matter:

| Context | Light | Dark |
|---|---|---|
| Body text on page background | `#1a1a1a` on `#ffffff` | `#e8e8e8` on `#121212` |
| Entry date (metadata) on page background | `#595959` on `#ffffff` | `#b0b0b0` on `#121212` |
| Nav link, non-current, on page background | `#1a1a1a` on `#ffffff` (text token — see Current nav item) | `#e8e8e8` on `#121212` |
| Nav link, current, on page background | same pair as non-current — bold + underline is the distinguishing mechanism, not colour (see Current nav item) | same |
| Button text on button fill | `#ffffff` on `#1552cc` | `#121212` on `#5b9dff` (dark scheme's own background token, reused as button text) |
| Chip text on chip fill | `#1552cc` on `#f4f6fa` | `#5b9dff` on `#1c1f26` |
| Focus ring on whatever sits behind it (page background or surface) | `#1552cc` | `#5b9dff` |

## Focus ring

One spec, applied identically everywhere an interactive element appears —
nav links (current and non-current), entry titles, tag chips, and the
button:

```
outline: 2px solid var(--color-focus);
outline-offset: 2px;
```

`--color-focus` is the scheme's own accent value (`#1552cc` light,
`#5b9dff` dark). The 2px offset is what makes one colour per scheme enough:
the ring sits over whatever background is behind the element (page or
surface), never over the element's own fill, so it never has to contrast
against itself — only against page background and surface, both of which
the Colour pairs table above already clears at well over 3:1 in each scheme.

## Current nav item

**Decision: keep the existing mechanism — bold weight + underline — and
confirm it, rather than replace it.** `css/style.css`'s
`.nav__links a[aria-current="page"]` (lines 58–61) already sets
`font-weight: 700` and `text-decoration: underline`; nothing here changes
its colour, so the current link stays the same colour as every other nav
link. Weight and underline are shape cues, not hue, so the distinction
survives for a colour-blind visitor exactly as it does for anyone else — and
`aria-current="page"` (already required by `portfolio-shell.md`) carries the
same signal non-visually. No new mechanism is needed.

## Typography

Builds on the sizes already in `css/style.css` rather than inventing a
parallel scale:

- **h1:** `2rem` (32px), weight 700, line-height 1.25. New — no page has an
  `h1` rule today.
- **h2 / entry titles:** `1.25rem` (20px), weight 700, line-height 1.3.
  **Decision: this unifies two sizes that drifted apart.** `.entry__title`
  is already `1.25rem` (`css/style.css` line 92); `.recent__heading` is
  `1.125rem` (line 124). Both are section/heading-level text one step below
  a page's `h1` — two sizes for the same level was drift, not a rule, so
  `.recent__heading` moves to `1.25rem` under this scale and the two
  converge on one token.
- **Body text:** `1rem` (16px), line-height 1.5 — unchanged, already `body`'s
  rule (`css/style.css` line 13).
- **Metadata (entry dates):** `0.875rem` (14px), line-height 1.4, muted-text
  colour (see Light/Dark palettes) — unchanged size, already
  `.entry__date` (`css/style.css` line 109); this doc adds the line-height
  and formalises the colour as a named token.

System fonts only, per Scope and constraints above — no size in this scale
depends on a webfont loading; the stack is `system-ui, -apple-system,
"Segoe UI", sans-serif` throughout.

## Spacing scale

A fixed set of six values, chosen to match the ad-hoc numbers already
scattered through `css/style.css` rather than replacing them with an
unrelated set:

- `--space-1: 4px` (was `.entry__date`/`.entry__summary`'s `margin: 4px 0 0`,
  line 104)
- `--space-2: 8px` (was `.nav`'s `gap: 8px 16px` first value, line 28)
- `--space-3: 16px` (was `.nav`'s padding, `.entry`'s padding, the side
  margin, several places — the most common value in the file today)
- `--space-4: 24px` (was `main`'s `padding: 24px 0 48px` first value, line 64)
- `--space-5: 32px` (was `.recent`'s `margin-top: 32px`, line 118)
- `--space-6: 48px` (was `main`'s `padding` last value, line 64)

Every margin/padding value in `css/style.css` maps onto one of these six; an
engineer replacing the ad-hoc numbers with tokens should not need a seventh
value anywhere in scope for this objective.

## Components

### Nav link

- **Normal:** text colour = `--color-text`, no underline.
- **Hover:** underline appears (`text-decoration: underline`); colour
  unchanged.
- **Focus:** the Focus ring spec above, applied to the `<a>` itself.
- **Current** (`aria-current="page"`): bold + underline per Current nav item,
  same colour as non-current; still gets the same hover and focus treatment
  as any other nav link — the current state changes weight and underline
  persistence, not which states exist.

### Entry title

Applies to an entry title where it is a link — on a listing page or Home's
Recent area, per `projects-and-posts.md`'s Entry component. On an entry's
own page, the title is deliberately not a link (`entry-page.md`'s Content,
top to bottom, item 2), so it has no hover/focus state there — that page
isn't in scope for this component.

- **Normal:** `1.25rem`/700/1.3 per Typography, colour = `--color-text`, no
  underline. The whole title is the tap target (existing rule).
- **Hover:** underline appears, colour unchanged.
- **Focus:** the Focus ring spec above, applied to the whole title link.

### Tag chip

Replaces `.entry__tag`'s current bare bulleted-list rendering with a pill.
Meets the 44px minimum tap target from `portfolio-shell.md` via `min-height`
plus flex centering, independent of how small the visible pill looks:

```
display: inline-flex;
align-items: center;
min-height: 44px;
padding: 0 var(--space-3);
border-radius: 999px;
font-size: 0.875rem; /* metadata scale */
```

- **Normal:** background = `--color-surface`, text = `--color-accent`,
  `1px solid var(--color-border)`.
- **Hover:** background shifts to `--color-border` (the palette's own
  divider tone, one step darker in light mode / one step lighter in dark
  mode than the resting surface) — text colour unchanged.
- **Focus:** the Focus ring spec above.

### Button

The `← Back to Projects` / `← Back to Posts` link (`entry-page.md`'s Closing
link), styled as a filled button rather than plain text. Meets the 44px
minimum tap target from `portfolio-shell.md`:

```
display: inline-flex;
align-items: center;
min-height: 44px;
padding: var(--space-2) var(--space-4);
border-radius: 6px;
text-decoration: none;
```

- **Normal:** background = `--color-accent`, text = `#ffffff` (light) /
  `#121212` (dark, the dark scheme's own background token — see Colour
  pairs).
- **Hover:** background darkens (light: `#103f99`) or lightens (dark:
  `#82b4ff`) one step from the resting accent; text colour unchanged.
- **Focus:** the Focus ring spec above. The 2px offset lands the ring on the
  page background just outside the button, not on the button's own fill.

### Empty-state text

`.empty-state`, currently bare paragraph text on `_layouts/tag.html` (and
the equivalent "No projects yet." / "No posts yet." lines from
`projects-and-posts.md`'s empty states).

- Colour = `--color-text-muted` (the same token as entry dates), not full
  body text — this is status text explaining why a list is missing, not
  primary content, and the muted tone signals that at a glance.
- Size = `1rem` (body scale) — it's still the only content on the page in
  this state and needs to read as more than a caption.
- Weight: normal. No italics, no icon — no icon set exists in this system
  (Scope and constraints).
- Not interactive: no hover or focus state, since `.empty-state` is static
  text, not a link or control.

## Implementation notes

- Declare the Light values under `:root`, and re-declare the Dark values
  inside `@media (prefers-color-scheme: dark) { :root { ... } }` — the usual
  custom-property pattern for automatic, toggle-free dark mode.
- Suggested token names, so all three engineering children use the same
  ones: `--color-bg`, `--color-text`, `--color-text-muted`, `--color-accent`,
  `--color-accent-text` (button text — differs by scheme, see Colour pairs),
  `--color-surface`, `--color-border`, `--color-focus`, `--space-1` through
  `--space-6`. Naming is a convenience, not a requirement — the literal
  values above are what's binding.
