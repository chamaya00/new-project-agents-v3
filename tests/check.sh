#!/usr/bin/env bash
# Structural checks for this repo's acceptance criteria, plus (from issue #17
# onward) the real Jekyll build. No package manager, no test framework here,
# so most of these are the grep / file-existence checks the criteria
# themselves name, made runnable.
# The mobile-viewport criterion has no scriptable check (per its own
# acceptance criterion: "checked by a mobile-emulation pass in devtools")
# and is out of scope for this script.
#
# The engineer role's Bash allowlist grants `bash tests/:*` but no Ruby
# runner (no `bundle`, `gem`, or `jekyll` directly) - see issue #17's
# constraints. That's fine: the grant covers this whole script, including
# every command it runs internally, so the build lives here rather than
# being invoked as a bare top-level command.
set -u
cd "$(dirname "$0")/.."

fail=0

check() {
  local desc="$1"
  shift
  if "$@"; then
    echo "PASS: $desc"
  else
    echo "FAIL: $desc"
    fail=1
  fi
}

# `!` is a shell keyword, recognised at parse time only - it cannot survive
# expansion through check()'s "$@", so negated checks route through this
# function instead of passing `!` as an argument.
not() {
  ! "$@"
}

check "index.html exists at repo root" test -f index.html
check "about.html exists at repo root" test -f about.html
check ".nojekyll is absent (Jekyll processing is on)" not test -f .nojekyll
check "_config.yml gives posts a stable /posts/:title/ permalink" \
  grep -Eq '^\s*permalink:\s*/posts/:title/\s*$' _config.yml
check "_config.yml declares a projects collection" \
  grep -Eq '^\s*projects:\s*$' _config.yml
check "_config.yml's projects collection sets output: true" \
  grep -Eq '^\s*output:\s*true\s*$' _config.yml
check "_config.yml declares a tags collection" \
  grep -Eq '^\s*tags:\s*$' _config.yml
check "_config.yml's tags collection sets a /tags/:path/ permalink" \
  grep -Eq '^\s*permalink:\s*/tags/:path/\s*$' _config.yml
check "_config.yml documents deleting a tag's stub with its last entry" \
  grep -q "same commit that removes its last tagged entry" _config.yml
check "ADR 0002 status is accepted" \
  grep -Eq '^Status:\s*accepted\s*$' \
    docs/decisions/0002-add-tags-and-a-tag-page-per-collection.md
check "ADR 0004 status is accepted" \
  grep -Eq '^Status:\s*accepted\s*$' \
    docs/decisions/0004-give-posts-a-stable-non-dated-permalink.md

check "projects.html exists at repo root" test -f projects.html
check "posts.html exists at repo root" test -f posts.html
check "_includes/entry.html exists" test -f _includes/entry.html

# Hand-authored links stay relative with no leading slash; the one place a
# path is generated rather than typed - an entry's link, whose page nests at a
# variable depth - goes through Liquid's relative_url, per ADR 0001. So the
# same grep covers both: a literal root-absolute path is a failure everywhere,
# including in the include.
for page in index.html about.html projects.html posts.html _includes/entry.html _layouts/entry.html; do
  check "no root-absolute href/src in $page" \
    not grep -Eq 'href="/[^/]|src="/[^/]' "$page"
done
check "the Entry component links through relative_url" \
  grep -q 'relative_url' _includes/entry.html
check "no root-absolute url() in css/style.css" \
  not grep -Eq 'url\(/[^/)]' css/style.css

check "index.html nav marks Home as current" \
  grep -q 'href="index.html" aria-current="page"' index.html
check "about.html nav marks About as current" \
  grep -q 'href="about.html" aria-current="page"' about.html
check "projects.html nav marks Projects as current" \
  grep -q 'href="projects.html" aria-current="page"' projects.html
check "posts.html nav marks Posts as current" \
  grep -q 'href="posts.html" aria-current="page"' posts.html

for page in index.html about.html projects.html posts.html; do
  check "no form action= in $page" \
    not grep -q '<form' "$page"
done

# The site ships zero JavaScript (objective #77's outcome 10): any <script>
# tag at all - inline, same-origin, or off-repo - is a violation, not just an
# off-repo src=. Covers the two hand-authored pages left (about.html,
# index.html now needs the Jekyll build too but its source is still plain
# text), the two Liquid pages, and the two layouts every generated page goes
# through - a script slipped into a layout reaches every entry/tag page it
# renders, not just one file.
for page in index.html about.html projects.html posts.html _layouts/entry.html _layouts/tag.html; do
  check "no <script> tag in $page" \
    not grep -Eiq '<script[ >]' "$page"
done

# --- Visual system doc (issue #78) ----------------------------------------
# Structural checks against the doc itself, not a build - it's hand-authored
# markdown, not a page Jekyll renders.

check "docs/design/visual-system.md exists" test -f docs/design/visual-system.md

if [ -f docs/design/visual-system.md ]; then
  check "visual-system.md has a Light heading" \
    grep -q '^## Light$' docs/design/visual-system.md
  check "visual-system.md has a Dark heading" \
    grep -q '^## Dark$' docs/design/visual-system.md
  check "visual-system.md has no TBD placeholder" \
    not grep -q 'TBD' docs/design/visual-system.md
  check "visual-system.md states dark mode is prefers-color-scheme-only" \
    grep -qi 'prefers-color-scheme' docs/design/visual-system.md
  check "visual-system.md states system fonts only" \
    grep -qi 'system fonts only' docs/design/visual-system.md

  # Extracts one `### Heading` section from the doc, so a criterion about
  # what one component's spec says (hover, focus, 44px) is checked against
  # that component's own section, never the whole document.
  design_section() {
    awk -v heading="### $2" '
      $0 == heading { inside = 1; next }
      inside && /^### / { exit }
      inside && /^## / { exit }
      inside { print }
    ' "$1"
  }

  for component in "Nav link" "Entry title" "Tag chip" "Button"; do
    check "\"$component\" section names hover" \
      grep -qi 'hover' <(design_section docs/design/visual-system.md "$component")
    check "\"$component\" section names focus" \
      grep -qi 'focus' <(design_section docs/design/visual-system.md "$component")
  done

  for component in "Tag chip" "Button"; do
    check "\"$component\" section names a 44px tap target" \
      grep -q '44px' <(design_section docs/design/visual-system.md "$component")
  done
fi

# --- Palette, type scale, spacing, dark mode (issue #79) -------------------
# css/style.css now carries the doc's values as :root custom properties
# (light) re-declared inside a `prefers-color-scheme: dark` block, rather
# than as hardcoded per-rule literals - the mechanism the doc's own
# Implementation notes name. Three of the doc's four light-scheme "unchanged"
# values (#1a1a1a text, #e0e0e0 border, #595959 muted text) are therefore
# still present in the file, as the one place that defines each token - a
# blanket "value never appears" grep would fail against the doc's own
# mandate to keep them, so the negative checks below target the specific old
# per-rule declarations (`color: #1a1a1a`, `background: #fff`, etc.), which
# are what's actually gone now that every consuming rule reads a var(...).

# Extracts one `selector {` rule's declarations by exact line match, so a
# criterion about what one rule says is checked against that rule alone.
css_rule() {
  awk -v sel="$2 {" '
    $0 == sel { inside = 1; next }
    inside && /^}/ { exit }
    inside { print }
  ' "$1"
}

# Nth literal hex value assigned to a custom property (1 = the light
# declaration under :root, 2 = the dark re-declaration), read from the
# stylesheet itself rather than restated here.
custom_prop_value() {
  grep -oE -e "$1: #[0-9a-fA-F]{3,6}" css/style.css | sed -n "${2}p" \
    | grep -oE '#[0-9a-fA-F]{3,6}'
}

check "@media (prefers-color-scheme: dark) block exists" \
  grep -q '@media (prefers-color-scheme: dark)' css/style.css

light_bg="$(custom_prop_value '--color-bg' 1)"
dark_bg="$(custom_prop_value '--color-bg' 2)"
light_text="$(custom_prop_value '--color-text' 1)"
dark_text="$(custom_prop_value '--color-text' 2)"
light_muted="$(custom_prop_value '--color-text-muted' 1)"
dark_muted="$(custom_prop_value '--color-text-muted' 2)"
light_surface="$(custom_prop_value '--color-surface' 1)"
dark_surface="$(custom_prop_value '--color-surface' 2)"

check "light --color-bg is the doc's #ffffff" test "$light_bg" = "#ffffff"
check "light --color-text is the doc's #1a1a1a" test "$light_text" = "#1a1a1a"
check "dark --color-bg is the doc's #121212" test "$dark_bg" = "#121212"
check "dark --color-text is the doc's #e8e8e8" test "$dark_text" = "#e8e8e8"

check "body's color reads the --color-text token" \
  grep -q 'color: var(--color-text);' <(css_rule css/style.css body)
check "body's background reads the --color-bg token" \
  grep -q 'background: var(--color-bg);' <(css_rule css/style.css body)

# The old flat, hardcoded declarations - as opposed to the values themselves,
# see note above - no longer appear anywhere.
check "no hardcoded 'color: #1a1a1a' declaration remains" \
  not grep -q 'color: #1a1a1a' css/style.css
check "no hardcoded 'background: #fff' declaration remains (light bg is now #ffffff via a token)" \
  not grep -q 'background: #fff' css/style.css
check "no hardcoded 'color: #595959' declaration remains" \
  not grep -q 'color: #595959' css/style.css
check "no hardcoded 'border-bottom: 1px solid #e0e0e0' declaration remains" \
  not grep -q 'border-bottom: 1px solid #e0e0e0' css/style.css
check "the 3-digit #fff shorthand is gone entirely (doc uses #ffffff)" \
  not grep -Eq '#fff([^0-9a-fA-F]|$)' css/style.css

check "light --color-surface differs from light --color-bg" \
  test "$light_surface" != "$light_bg"
check "dark --color-surface differs from dark --color-bg" \
  test "$dark_surface" != "$dark_bg"
check ".entry's background reads the --color-surface token" \
  grep -q 'background: var(--color-surface);' <(css_rule css/style.css .entry)

check "h1 uses the doc's 2rem/700/1.25 scale" \
  grep -q 'font-size: 2rem;' <(css_rule css/style.css h1)
check ".entry__title uses the doc's 1.25rem/700/1.3 scale" \
  grep -q 'font-size: 1.25rem;' <(css_rule css/style.css .entry__title) \
  && grep -q 'font-weight: 700;' <(css_rule css/style.css .entry__title) \
  && grep -q 'line-height: 1.3;' <(css_rule css/style.css .entry__title)
check ".entry__date uses the doc's 0.875rem/1.4 metadata scale" \
  grep -q 'font-size: 0.875rem;' <(css_rule css/style.css .entry__date) \
  && grep -q 'line-height: 1.4;' <(css_rule css/style.css .entry__date)
check ".entry__date reads the --color-text-muted token" \
  grep -q 'color: var(--color-text-muted);' <(css_rule css/style.css .entry__date)

nav_current_rule="$(css_rule css/style.css '.nav__links a[aria-current="page"]')"
check "current nav link keeps its bold weight" \
  grep -q 'font-weight: 700;' <<< "$nav_current_rule"
check "current nav link keeps its underline" \
  grep -q 'text-decoration: underline;' <<< "$nav_current_rule"
check "current nav link's distinguishing rule carries no colour property" \
  not grep -q 'color' <<< "$nav_current_rule"

# WCAG AA contrast (issue #79 AC3): computes relative luminance from the
# literal hex values actually shipped in css/style.css - not the design
# doc's stated ratios, which were never verified arithmetically - so a wrong
# value here fails this check even though the doc named it.
relative_luminance() {
  awk -v hex="$1" '
    function hex2dec(h,    n, i, c, v, result) {
      result = 0
      n = length(h)
      for (i = 1; i <= n; i++) {
        c = tolower(substr(h, i, 1))
        if (c ~ /[0-9]/) { v = c + 0 } else { v = index("abcdefghijklmnopqrstuvwxyz", c) + 9 }
        result = result * 16 + v
      }
      return result
    }
    function channel_lin(c,   cs) {
      cs = c / 255
      if (cs <= 0.03928) { return cs / 12.92 }
      return exp(2.4 * log((cs + 0.055) / 1.055))
    }
    BEGIN {
      gsub(/^#/, "", hex)
      if (length(hex) == 3) {
        hex = substr(hex,1,1) substr(hex,1,1) substr(hex,2,1) substr(hex,2,1) substr(hex,3,1) substr(hex,3,1)
      }
      r = hex2dec(substr(hex,1,2))
      g = hex2dec(substr(hex,3,2))
      b = hex2dec(substr(hex,5,2))
      printf "%.10f", 0.2126*channel_lin(r) + 0.7152*channel_lin(g) + 0.0722*channel_lin(b)
    }
  '
}

contrast_ratio() {
  local l1 l2
  l1="$(relative_luminance "$1")"
  l2="$(relative_luminance "$2")"
  awk -v l1="$l1" -v l2="$l2" '
    BEGIN {
      lighter = (l1 > l2) ? l1 : l2
      darker = (l1 > l2) ? l2 : l1
      printf "%.4f", (lighter + 0.05) / (darker + 0.05)
    }
  '
}

meets_aa() {
  awk -v r="$1" 'BEGIN { exit !(r + 0 >= 4.5) }'
}

light_body_ratio="$(contrast_ratio "$light_text" "$light_bg")"
dark_body_ratio="$(contrast_ratio "$dark_text" "$dark_bg")"
light_date_ratio="$(contrast_ratio "$light_muted" "$light_bg")"
dark_date_ratio="$(contrast_ratio "$dark_muted" "$dark_bg")"

check "light-scheme body text meets WCAG AA 4.5:1 (computed $light_body_ratio:1)" \
  meets_aa "$light_body_ratio"
check "dark-scheme body text meets WCAG AA 4.5:1 (computed $dark_body_ratio:1)" \
  meets_aa "$dark_body_ratio"
check "light-scheme entry date meets WCAG AA 4.5:1 (computed $light_date_ratio:1)" \
  meets_aa "$light_date_ratio"
check "dark-scheme entry date meets WCAG AA 4.5:1 (computed $dark_date_ratio:1)" \
  meets_aa "$dark_date_ratio"

# --- Hover/focus states, accent link colour, script gate (issue #80) ------
# Zero :hover/:focus rules existed in css/style.css before this issue,
# color: inherit marked four link types, and the focus ring is a non-text
# indicator that has to clear 3:1 against whatever actually sits behind it -
# page background for four of the five interactive elements, the entry
# surface for the fifth (.entry__title a lives inside .entry, which #79 gave
# a --color-surface background).

has_hover_rule() {
  grep -Fq "$1:hover {" css/style.css
}

# Accepts either :focus or :focus-visible, per the criterion's "(or
# :focus-visible)".
focus_block() {
  local block
  block="$(css_rule css/style.css "$1:focus-visible")"
  if [ -z "$block" ]; then
    block="$(css_rule css/style.css "$1:focus")"
  fi
  printf '%s' "$block"
}

has_focus_rule() {
  test -n "$(focus_block "$1")"
}

focus_rule_uses_focus_ring() {
  grep -q 'outline: 2px solid var(--color-focus);' <<< "$(focus_block "$1")"
}

interactive_selectors=(".nav__brand" ".nav__links a" ".entry__title a" ".contact-links a" ".entry__back")
for sel in "${interactive_selectors[@]}"; do
  check "\"$sel\" has a :hover rule" has_hover_rule "$sel"
  check "\"$sel\" has a :focus/:focus-visible rule" has_focus_rule "$sel"
  check "\"$sel\"'s focus rule uses the doc's focus-ring colour" \
    focus_rule_uses_focus_ring "$sel"
done

# color: inherit is gone from the four link types the issue names, and each
# now resolves to the doc's accent colour instead. (.entry__back is not one
# of the four - its colour is out of scope here, per the Button component
# being a later issue's work.)
link_selectors=(".nav__brand" ".nav__links a" ".entry__title a" ".contact-links a")
for sel in "${link_selectors[@]}"; do
  check "\"$sel\" does not set color: inherit" \
    not grep -q 'color: inherit;' <(css_rule css/style.css "$sel")
  check "\"$sel\" resolves to the --color-accent token" \
    grep -q 'color: var(--color-accent);' <(css_rule css/style.css "$sel")
done

light_accent="$(custom_prop_value '--color-accent' 1)"
dark_accent="$(custom_prop_value '--color-accent' 2)"
light_focus="$(custom_prop_value '--color-focus' 1)"
dark_focus="$(custom_prop_value '--color-focus' 2)"

check "light --color-accent is the doc's #1552cc" test "$light_accent" = "#1552cc"
check "dark --color-accent is the doc's #5b9dff" test "$dark_accent" = "#5b9dff"
check "light --color-focus is the doc's #1552cc" test "$light_focus" = "#1552cc"
check "dark --color-focus is the doc's #5b9dff" test "$dark_focus" = "#5b9dff"

meets_non_text_aa() {
  awk -v r="$1" 'BEGIN { exit !(r + 0 >= 3) }'
}

light_accent_on_bg="$(contrast_ratio "$light_accent" "$light_bg")"
dark_accent_on_bg="$(contrast_ratio "$dark_accent" "$dark_bg")"
light_accent_on_surface="$(contrast_ratio "$light_accent" "$light_surface")"
dark_accent_on_surface="$(contrast_ratio "$dark_accent" "$dark_surface")"

# AC2: each accent link's colour pair, checked against the backdrop it
# actually renders on - surface for .entry__title a (inside .entry), page
# background for the other three.
for sel in ".nav__brand" ".nav__links a" ".contact-links a"; do
  check "light-scheme \"$sel\" accent-on-background meets WCAG AA (computed $light_accent_on_bg:1)" \
    meets_aa "$light_accent_on_bg"
  check "dark-scheme \"$sel\" accent-on-background meets WCAG AA (computed $dark_accent_on_bg:1)" \
    meets_aa "$dark_accent_on_bg"
done
check "light-scheme \".entry__title a\" accent-on-surface meets WCAG AA (computed $light_accent_on_surface:1)" \
  meets_aa "$light_accent_on_surface"
check "dark-scheme \".entry__title a\" accent-on-surface meets WCAG AA (computed $dark_accent_on_surface:1)" \
  meets_aa "$dark_accent_on_surface"

light_focus_on_bg="$(contrast_ratio "$light_focus" "$light_bg")"
dark_focus_on_bg="$(contrast_ratio "$dark_focus" "$dark_bg")"
light_focus_on_surface="$(contrast_ratio "$light_focus" "$light_surface")"
dark_focus_on_surface="$(contrast_ratio "$dark_focus" "$dark_surface")"

# AC3: the focus ring's own colour pair, against every backdrop it actually
# renders over - surface for the ring on .entry__title a, page background for
# the other four elements named in AC1 - at the 3:1 non-text minimum.
for sel in ".nav__brand" ".nav__links a" ".contact-links a" ".entry__back"; do
  check "light-scheme focus ring on \"$sel\" (over page background) meets 3:1 (computed $light_focus_on_bg:1)" \
    meets_non_text_aa "$light_focus_on_bg"
  check "dark-scheme focus ring on \"$sel\" (over page background) meets 3:1 (computed $dark_focus_on_bg:1)" \
    meets_non_text_aa "$dark_focus_on_bg"
done
check "light-scheme focus ring on \".entry__title a\" (over surface) meets 3:1 (computed $light_focus_on_surface:1)" \
  meets_non_text_aa "$light_focus_on_surface"
check "dark-scheme focus ring on \".entry__title a\" (over surface) meets 3:1 (computed $dark_focus_on_surface:1)" \
  meets_non_text_aa "$dark_focus_on_surface"

# --- Jekyll build ---------------------------------------------------------
# Proves the ADR 0001 mechanism actually works, not just that the config
# file has the right shape. `jekyll build` fails loudly (non-zero exit) on
# a YAML front-matter error, which is what the negative check below relies
# on.
#
# Everything here builds with the plain `jekyll` gem. GitHub Pages does not:
# it runs `github-pages`, a different gem with a dozen extra plugins. So a
# green run below is evidence about this repository's own Liquid, not proof
# that the site will deploy. ADR 0003 records how that gap took the site
# down for nineteen hours, what closes it, and what is still open.

ensure_jekyll() {
  if command -v jekyll >/dev/null 2>&1; then
    return 0
  fi
  local user_gem_bin
  user_gem_bin="$(ruby -e 'print Gem.user_dir')/bin"
  export PATH="$user_gem_bin:$PATH"
  if command -v jekyll >/dev/null 2>&1; then
    return 0
  fi
  echo "jekyll not found - installing (gem install jekyll --user-install)..."
  gem install jekyll --user-install --no-document >/dev/null 2>&1
  command -v jekyll >/dev/null 2>&1
}


# Copies the site's own files into a throwaway directory, so a fixture build
# starts from the real pages, stylesheet, config, and includes but none of the
# real content files. Each fixture then adds only the entries it is about,
# which is what lets the counts and orderings below be asserted exactly.
copy_site_into() {
  local dest="$1"
  mkdir -p "$dest"
  cp -r index.html about.html projects.html posts.html css _includes _layouts \
    _config.yml "$dest/"
}

# Extracts one `<section class="recent">...</section>` block from a built
# Home page, identified by its heading - so a criterion about what appears
# *under a given heading* is checked against that block alone, never the
# whole page.
recent_section() {
  awk -v heading="$2" '
    index($0, ">" heading "<") { inside = 1 }
    inside { print }
    inside && /<\/section>/ { exit }
  ' "$1"
}

# Extracts one `<li class="entry">...</li>` block from a built listing page,
# identified by its title - so a criterion about one entry's summary is
# checked against that entry alone, never the whole page.
entry_block_for() {
  awk -v title="$2" '
    index($0, ">" title "<") { inside = 1 }
    inside { print }
    inside && /<\/li>/ { exit }
  ' "$1"
}

no_summary_for() {
  ! entry_block_for "$1" "$2" | grep -q 'entry__summary'
}

if ensure_jekyll; then
  echo "PASS: jekyll is available ($(jekyll --version))"

  check "jekyll build of the real site succeeds" \
    jekyll build --destination _site

  # Sample posts (issue #56). Three real _posts files exist in this repo
  # now, so - unlike every fixture above - these checks read the real
  # build's own _site/, not a throwaway copy.
  real_posts_order="$(grep -o 'Writing HTML by hand again\|A week with Jekyll\|Static by choice' \
    _site/posts.html | tr '\n' ' ')"
  check "the three sample posts render on posts.html, most-recent-first" \
    test "$real_posts_order" = "Writing HTML by hand again A week with Jekyll Static by choice "

  home_recent_posts_order="$(recent_section _site/index.html "Recent posts" \
    | grep -o 'Writing HTML by hand again\|A week with Jekyll\|Static by choice' | tr '\n' ' ')"
  check "Home's Recent posts lists the same three, most-recent-first" \
    test "$home_recent_posts_order" = "Writing HTML by hand again A week with Jekyll Static by choice "

  check "'Writing HTML by hand again' links to a page that exists in the built output" \
    test -f _site/posts/writing-html-by-hand-again/index.html
  check "'A week with Jekyll' links to a page that exists in the built output" \
    test -f _site/posts/a-week-with-jekyll/index.html
  check "'Static by choice' links to a page that exists in the built output" \
    test -f _site/posts/static-by-choice/index.html

  # Posts' old dated permalink (issue #68): the stable /posts/<slug>/ shape
  # replaces it outright, so none of the old dated paths should exist in the
  # same build that produces the new ones.
  check "'Writing HTML by hand again' no longer builds to its old dated path" \
    not test -e _site/2026/08/20/writing-html-by-hand-again.html
  check "'A week with Jekyll' no longer builds to its old dated path" \
    not test -e _site/2026/07/15/a-week-with-jekyll.html
  check "'Static by choice' no longer builds to its old dated path" \
    not test -e _site/2026/06/01/static-by-choice.html
  check "the built site produces no /2026/ dated post directory at all" \
    not test -d _site/2026

  check "'Writing HTML by hand again' shows its summary on posts.html" \
    grep -q 'closing my own tags feels like relearning' _site/posts.html
  check "'Static by choice' shows its summary on posts.html" \
    grep -q 'the constraints are the design' _site/posts.html
  check "'A week with Jekyll', which has no summary field, shows no summary line" \
    no_summary_for _site/posts.html "A week with Jekyll"

  check "no sample post declares a tags key" \
    not grep -rEl '^\s*tags\s*:' _posts/

  # Sample projects (issue #57). Two real _projects files exist in this repo
  # now, so - like the sample posts above - these checks read the real
  # build's own _site/, not a throwaway copy. The title match is bracketed by
  # `>...<` rather than bare, because "linkrot" is both the title and its own
  # slug - a bare match also hits the href, double-counting the title.
  real_projects_order="$(grep -o '>linkrot<\|>A pomodoro timer for the terminal<' \
    _site/projects.html | tr '\n' ' ')"
  check "the two sample projects render on projects.html, most-recent-first" \
    test "$real_projects_order" = ">linkrot< >A pomodoro timer for the terminal< "

  home_recent_projects_order="$(recent_section _site/index.html "Recent projects" \
    | grep -o '>linkrot<\|>A pomodoro timer for the terminal<' | tr '\n' ' ')"
  check "Home's Recent projects lists the same two, most-recent-first" \
    test "$home_recent_projects_order" = ">linkrot< >A pomodoro timer for the terminal< "

  check "'linkrot' links to a page that exists in the built output" \
    test -f _site/projects/linkrot/index.html
  check "'A pomodoro timer for the terminal' links to a page that exists in the built output" \
    test -f _site/projects/terminal-pomodoro/index.html

  check "'linkrot' shows its summary on projects.html" \
    grep -q 'walks a folder of Markdown and reports' _site/projects.html
  check "'A pomodoro timer for the terminal', which has no summary field, shows no summary line" \
    no_summary_for _site/projects.html "A pomodoro timer for the terminal"

  check "no sample project declares a tags key" \
    not grep -rEl '^\s*tags\s*:' _projects/

  # Entry pages (issue #69). Every _posts/_projects file now declares
  # `layout: entry`, so the real build already produces one sample post's
  # and one sample project's own page - read those, never the layout
  # source, per this repo's own lesson that Liquid output is only honest
  # once built.
  real_post_entry=_site/posts/writing-html-by-hand-again/index.html
  real_project_entry=_site/projects/linkrot/index.html

  entry_shell_ok() {
    grep -q '<!doctype html>' "$1" \
      && grep -q '<nav class="nav">' "$1" \
      && grep -Eq 'href="[^"]*/css/style.css"' "$1"
  }
  check "the sample post's own page ships the full site shell" \
    entry_shell_ok "$real_post_entry"
  check "the sample project's own page ships the full site shell" \
    entry_shell_ok "$real_project_entry"

  check "the sample post's own page shows its title" \
    grep -q '<h1>Writing HTML by hand again</h1>' "$real_post_entry"
  check "the sample post's own page shows its readable date" \
    grep -q '20 August 2026' "$real_post_entry"
  check "the sample project's own page shows its title" \
    grep -q '<h1>linkrot</h1>' "$real_project_entry"
  check "the sample project's own page shows its readable date" \
    grep -q '10 May 2026' "$real_project_entry"

  check "the sample post's own page's nav marks Posts as current" \
    grep -q 'href="[^"]*/posts.html" aria-current="page"' "$real_post_entry"
  check "the sample project's own page's nav marks Projects as current" \
    grep -q 'href="[^"]*/projects.html" aria-current="page"' "$real_project_entry"

  # The nav band also links to posts.html/projects.html, so the anchor text
  # distinguishes the closing link (AC2) from that nav link.
  check "the sample post's own page's closing link points back to Posts" \
    grep -q 'href="[^"]*/posts.html">← Back to Posts</a>' "$real_post_entry"
  check "the sample project's own page's closing link points back to Projects" \
    grep -q 'href="[^"]*/projects.html">← Back to Projects</a>' "$real_project_entry"

  # Repository documentation is not site content, and until ADR 0003 it was
  # being published anyway - CLAUDE.md, every ADR, every research note, live
  # at /docs/... under a theme nobody chose. That leak is also what took the
  # site down: GitHub Pages renders every .md it can see through Liquid, and
  # docs/research/tag-pages.md quotes an `{% if %}` with no `{% endif %}` in
  # its code samples. Pages executed it and eight deployments failed.
  #
  # This build cannot see that error - the plain jekyll gem has no such
  # plugin and copies the file through unparsed, which is exactly why nothing
  # here went red. What it can see, and now asserts, is the precondition: no
  # documentation reaches the built site at all. Shortening the exclude list
  # fails here rather than quietly republishing the docs.
  for leaked in docs tests CLAUDE.md README.md; do
    check "the built site carries no $leaked" not test -e "_site/$leaked"
  done
  check "no repository markdown reaches the built site" \
    test -z "$(find _site -name '*.md' 2>/dev/null)"

  # Negative fixture: a collection file with invalid front matter must fail
  # the build, and the failure must name the file. Built against a throwaway
  # copy of the repo so it never touches the real working tree.
  neg_dir="$(mktemp -d)"
  trap 'rm -rf "$neg_dir"' EXIT
  copy_site_into "$neg_dir/site"
  mkdir -p "$neg_dir/site/_projects"
  cat > "$neg_dir/site/_projects/broken-front-matter.html" <<'FIXTURE'
---
title: "unterminated string
---
<p>Broken on purpose.</p>
FIXTURE
  neg_output="$(cd "$neg_dir/site" && jekyll build --destination _site 2>&1)"
  neg_status=$?
  if [ "$neg_status" -ne 0 ] && printf '%s' "$neg_output" | grep -q 'broken-front-matter.html'; then
    echo "PASS: invalid front matter fails the build and names the file"
  else
    echo "FAIL: invalid front matter fails the build and names the file"
    echo "$neg_output"
    fail=1
  fi

  # Positive fixture: a valid project file must land under
  # _site/projects/<slug>/, proving the collection's output/permalink work.
  pos_dir="$(mktemp -d)"
  trap 'rm -rf "$neg_dir" "$pos_dir"' EXIT
  copy_site_into "$pos_dir/site"
  mkdir -p "$pos_dir/site/_projects"
  cat > "$pos_dir/site/_projects/fixture-project.html" <<'FIXTURE'
---
title: "Fixture project"
date: 2026-01-01
---
<p>Fixture content.</p>
FIXTURE
  (cd "$pos_dir/site" && jekyll build --destination _site --quiet)
  check "a _projects file builds to _site/projects/<slug>/" \
    test -f "$pos_dir/site/_site/projects/fixture-project/index.html"

  # Listing-page fixtures. Each acceptance criterion of issue #18 gets its own
  # throwaway site: the two listing pages are rendered by Liquid, so the only
  # honest check is what the build actually emits, not what the template says.
  list_dir="$(mktemp -d)"
  trap 'rm -rf "$neg_dir" "$pos_dir" "$list_dir"' EXIT

  # Zero entries of either type: one line of static text, no list container.
  copy_site_into "$list_dir/empty"
  (cd "$list_dir/empty" && jekyll build --destination _site --quiet)
  check "zero projects renders the 'No projects yet.' line" \
    grep -q 'No projects yet\.' "$list_dir/empty/_site/projects.html"
  check "zero projects renders no list container" \
    not grep -q 'entry-list' "$list_dir/empty/_site/projects.html"
  check "zero posts renders the 'No posts yet.' line" \
    grep -q 'No posts yet\.' "$list_dir/empty/_site/posts.html"
  check "zero posts renders no list container" \
    not grep -q 'entry-list' "$list_dir/empty/_site/posts.html"

  # One project file and no other change: it appears on the Projects page,
  # titled, and linked to its own generated page.
  copy_site_into "$list_dir/one-project"
  mkdir -p "$list_dir/one-project/_projects"
  cat > "$list_dir/one-project/_projects/single-project.html" <<'FIXTURE'
---
title: "Single fixture project"
date: 2026-01-01
---
<p>Fixture content.</p>
FIXTURE
  (cd "$list_dir/one-project" && jekyll build --destination _site --quiet)
  check "one _projects file appears on the Projects page by title" \
    grep -q 'Single fixture project' "$list_dir/one-project/_site/projects.html"
  check "one _projects file is linked from the Projects page" \
    grep -Eq 'href="[^"]*/projects/single-project/"' "$list_dir/one-project/_site/projects.html"
  check "the Projects page drops its empty state once a project exists" \
    not grep -q 'No projects yet\.' "$list_dir/one-project/_site/projects.html"

  # The same for one post file. A post with no `summary` also proves the Entry
  # component leaves the element out entirely rather than rendering an empty one.
  copy_site_into "$list_dir/one-post"
  mkdir -p "$list_dir/one-post/_posts"
  cat > "$list_dir/one-post/_posts/2026-01-02-single-post.html" <<'FIXTURE'
---
title: "Single fixture post"
---
<p>Fixture content.</p>
FIXTURE
  (cd "$list_dir/one-post" && jekyll build --destination _site --quiet)
  check "one _posts file appears on the Posts page by title" \
    grep -q 'Single fixture post' "$list_dir/one-post/_site/posts.html"
  check "one _posts file is linked from the Posts page" \
    grep -Eq 'href="[^"]*single-post[^"]*"' "$list_dir/one-post/_site/posts.html"
  check "the Posts page drops its empty state once a post exists" \
    not grep -q 'No posts yet\.' "$list_dir/one-post/_site/posts.html"
  check "an entry with no summary renders no summary element" \
    not grep -q 'entry__summary' "$list_dir/one-post/_site/posts.html"

  # Two projects with different dates: most-recent-first, whatever order the
  # filenames sort in (these two sort the wrong way round on purpose).
  copy_site_into "$list_dir/two-projects"
  mkdir -p "$list_dir/two-projects/_projects"
  cat > "$list_dir/two-projects/_projects/a-older.html" <<'FIXTURE'
---
title: "Older fixture project"
date: 2026-01-01
---
<p>Fixture content.</p>
FIXTURE
  cat > "$list_dir/two-projects/_projects/b-newer.html" <<'FIXTURE'
---
title: "Newer fixture project"
date: 2026-06-01
---
<p>Fixture content.</p>
FIXTURE
  (cd "$list_dir/two-projects" && jekyll build --destination _site --quiet)
  order="$(grep -o 'Older fixture project\|Newer fixture project' \
    "$list_dir/two-projects/_site/projects.html" | tr '\n' ' ')"
  check "two projects render most-recent-first" \
    test "$order" = "Newer fixture project Older fixture project "

  # Home's Recent area (issue #19). Same rule as the listing fixtures above:
  # the area is Liquid, so every assertion reads the built _site/index.html,
  # never the template. Each subsection is one `<section class="recent">`, so
  # a criterion about what appears *under a given heading* is checked against
  # that block alone rather than the whole page - a title anywhere on Home
  # would otherwise pass a check about the wrong subsection.
  home_dir="$(mktemp -d)"
  trap 'rm -rf "$neg_dir" "$pos_dir" "$list_dir" "$home_dir"' EXIT

  # Writes one _projects fixture file: dir, filename, title, date.
  write_project() {
    mkdir -p "$1/_projects"
    cat > "$1/_projects/$2" <<FIXTURE
---
title: "$3"
date: $4
---
<p>Fixture content.</p>
FIXTURE
  }

  # One project and one post: each lands under its own heading.
  copy_site_into "$home_dir/one-each"
  write_project "$home_dir/one-each" "home-project.html" "Home fixture project" "2026-01-01"
  mkdir -p "$home_dir/one-each/_posts"
  cat > "$home_dir/one-each/_posts/2026-01-02-home-post.html" <<'FIXTURE'
---
title: "Home fixture post"
---
<p>Fixture content.</p>
FIXTURE
  (cd "$home_dir/one-each" && jekyll build --destination _site --quiet)
  home_one_each="$home_dir/one-each/_site/index.html"
  check "one project appears under Home's 'Recent projects'" \
    grep -q 'Home fixture project' <(recent_section "$home_one_each" "Recent projects")
  check "one post appears under Home's 'Recent posts'" \
    grep -q 'Home fixture post' <(recent_section "$home_one_each" "Recent posts")
  check "Home's Recent projects does not list posts" \
    not grep -q 'Home fixture post' <(recent_section "$home_one_each" "Recent projects")

  # Five projects, filenames sorting against date order on purpose: exactly the
  # three most recent appear, newest first.
  copy_site_into "$home_dir/five-projects"
  write_project "$home_dir/five-projects" "a.html" "Project one" "2026-01-01"
  write_project "$home_dir/five-projects" "b.html" "Project two" "2026-02-01"
  write_project "$home_dir/five-projects" "c.html" "Project three" "2026-03-01"
  write_project "$home_dir/five-projects" "d.html" "Project four" "2026-04-01"
  write_project "$home_dir/five-projects" "e.html" "Project five" "2026-05-01"
  (cd "$home_dir/five-projects" && jekyll build --destination _site --quiet)
  home_five="$home_dir/five-projects/_site/index.html"
  five_count="$(recent_section "$home_five" "Recent projects" | grep -c 'class="entry"')"
  check "five projects render exactly three entries on Home" \
    test "$five_count" = "3"
  five_order="$(recent_section "$home_five" "Recent projects" \
    | grep -o 'Project one\|Project two\|Project three\|Project four\|Project five' \
    | tr '\n' ' ')"
  check "Home's three recent projects are the newest three, newest first" \
    test "$five_order" = "Project five Project four Project three "

  # Zero projects, one post: the Recent projects subsection is gone entirely -
  # heading string absent from the built page - while Recent posts renders.
  copy_site_into "$home_dir/posts-only"
  mkdir -p "$home_dir/posts-only/_posts"
  cat > "$home_dir/posts-only/_posts/2026-01-02-only-post.html" <<'FIXTURE'
---
title: "Only fixture post"
---
<p>Fixture content.</p>
FIXTURE
  (cd "$home_dir/posts-only" && jekyll build --destination _site --quiet)
  home_posts_only="$home_dir/posts-only/_site/index.html"
  check "zero projects removes Home's 'Recent projects' heading entirely" \
    not grep -q 'Recent projects' "$home_posts_only"
  check "zero projects leaves no empty-state line on Home" \
    not grep -q 'No projects yet\.' "$home_posts_only"
  check "zero projects still renders Home's 'Recent posts'" \
    grep -q 'Only fixture post' <(recent_section "$home_posts_only" "Recent posts")

  # The mirror image: zero posts, one project.
  copy_site_into "$home_dir/projects-only"
  write_project "$home_dir/projects-only" "only-project.html" "Only fixture project" "2026-01-01"
  (cd "$home_dir/projects-only" && jekyll build --destination _site --quiet)
  home_projects_only="$home_dir/projects-only/_site/index.html"
  check "zero posts removes Home's 'Recent posts' heading entirely" \
    not grep -q 'Recent posts' "$home_projects_only"
  check "zero posts leaves no empty-state line on Home" \
    not grep -q 'No posts yet\.' "$home_projects_only"
  check "zero posts still renders Home's 'Recent projects'" \
    grep -q 'Only fixture project' <(recent_section "$home_projects_only" "Recent projects")

  # Zero of both: no Recent area at all, and the fixed content above it intact.
  copy_site_into "$home_dir/empty"
  (cd "$home_dir/empty" && jekyll build --destination _site --quiet)
  home_empty="$home_dir/empty/_site/index.html"
  check "zero projects and zero posts leaves Home with no Recent headings" \
    not grep -Eq 'Recent projects|Recent posts' "$home_empty"
  check "zero projects and zero posts leaves Home with no entry list" \
    not grep -q 'entry-list' "$home_empty"
  check "Home still renders its heading with no Recent area" \
    grep -q '<h1>Site Owner</h1>' "$home_empty"
  check "Home still renders its nav with no Recent area" \
    grep -q 'href="index.html" aria-current="page"' "$home_empty"

  # Home's generated entry links go through relative_url, so they pick up the
  # site's base path; a hand-typed "/projects/<slug>/" would not. Building with
  # a non-empty baseurl is what makes the difference observable: the same
  # root-absolute grep the source pages get is applied to Home's built output,
  # allowing only paths the baseurl prefixed. The project also carries a tag
  # (issue #51), so this one grep covers both the entry link and its tag link.
  # It also declares `layout: entry` on both files (issue #69) - tagged
  # project, untagged post - so the same fixture proves the entry layout's
  # tags decision (AC3) and its closing link's base-path resolution (AC2)
  # without a second build: a bare relative path would emit unprefixed here
  # exactly as it would on the real site, since both builds share an empty
  # baseurl otherwise - this fixture's non-empty one is what makes a bare
  # "posts.html"/"projects.html" observably wrong instead of merely present.
  copy_site_into "$home_dir/baseurl"
  mkdir -p "$home_dir/baseurl/_projects"
  cat > "$home_dir/baseurl/_projects/based-project.html" <<'FIXTURE'
---
layout: entry
title: "Based fixture project"
date: 2026-01-01
tags: [based]
---
<p>Fixture content.</p>
FIXTURE
  mkdir -p "$home_dir/baseurl/_posts"
  cat > "$home_dir/baseurl/_posts/2026-01-02-based-post.html" <<'FIXTURE'
---
layout: entry
title: "Based fixture post"
---
<p>Fixture content.</p>
FIXTURE
  echo 'baseurl: /base-fixture' >> "$home_dir/baseurl/_config.yml"
  (cd "$home_dir/baseurl" && jekyll build --destination _site --quiet)
  home_baseurl="$home_dir/baseurl/_site/index.html"
  unbased="$(grep -oE '(href|src)="/[^"]*' "$home_baseurl" \
    | grep -vE '^(href|src)="/base-fixture/' || true)"
  check "no root-absolute href/src in Home's built output" \
    test -z "$unbased"
  check "Home's entry links carry the site's base path" \
    grep -q 'href="/base-fixture/projects/based-project/"' "$home_baseurl"
  check "Home's entry tag links carry the site's base path" \
    grep -q 'href="/base-fixture/tags/based/">based</a>' "$home_baseurl"

  based_project_entry="$home_dir/baseurl/_site/projects/based-project/index.html"
  based_post_entry="$home_dir/baseurl/_site/posts/based-post/index.html"

  entry_unbased() {
    grep -oE '(href|src)="/[^"]*' "$1" | grep -vE '^(href|src)="/base-fixture/' || true
  }
  check "no root-absolute href/src in the tagged project's own page" \
    test -z "$(entry_unbased "$based_project_entry")"
  check "no root-absolute href/src in the untagged post's own page" \
    test -z "$(entry_unbased "$based_post_entry")"

  check "the tagged project's own page's closing link carries the site's base path" \
    grep -q 'href="/base-fixture/projects.html">← Back to Projects</a>' "$based_project_entry"
  check "the untagged post's own page's closing link carries the site's base path" \
    grep -q 'href="/base-fixture/posts.html">← Back to Posts</a>' "$based_post_entry"

  check "the tagged project's own page's nav marks Projects as current, base-path resolved" \
    grep -q 'href="/base-fixture/projects.html" aria-current="page"' "$based_project_entry"
  check "the untagged post's own page's nav marks Posts as current, base-path resolved" \
    grep -q 'href="/base-fixture/posts.html" aria-current="page"' "$based_post_entry"

  # AC3: the entry page renders a tagged entry's tags, linked and base-path
  # resolved, the same way the Entry component does on a listing - and
  # renders no tags element at all for an entry that has none.
  check "the tagged project's own page shows its tag, base-path resolved" \
    grep -q 'href="/base-fixture/tags/based/">based</a>' "$based_project_entry"
  check "the untagged post's own page renders no tags element" \
    not grep -q 'entry__tags' "$based_post_entry"

  # Tag pages (issue #50). One fixture site, three assertions against its
  # built _site/ output: a stubbed tag with matching entries from both
  # collections, out of date order; a stubbed tag with no matching entries at
  # all; and a tag used by an entry but never given a stub file.
  tag_dir="$(mktemp -d)"
  trap 'rm -rf "$neg_dir" "$pos_dir" "$list_dir" "$home_dir" "$tag_dir"' EXIT

  copy_site_into "$tag_dir/site"
  mkdir -p "$tag_dir/site/_tags" "$tag_dir/site/_posts" "$tag_dir/site/_projects"

  cat > "$tag_dir/site/_tags/design.html" <<'FIXTURE'
---
layout: tag
tag: design
---
FIXTURE

  cat > "$tag_dir/site/_tags/unused.html" <<'FIXTURE'
---
layout: tag
tag: unused
---
FIXTURE

  # Older by date, but the _posts filename sorts alphabetically after the
  # _projects file - out of date order on purpose, per the criterion.
  cat > "$tag_dir/site/_posts/2026-01-01-older-tagged-post.html" <<'FIXTURE'
---
title: "Older tagged post"
tags: [design]
---
<p>Fixture content.</p>
FIXTURE

  cat > "$tag_dir/site/_projects/newer-tagged-project.html" <<'FIXTURE'
---
title: "Newer tagged project"
date: 2026-06-01
tags: [design]
---
<p>Fixture content.</p>
FIXTURE

  # Carries a tag ("ghost") with no _tags/ghost.html stub at all.
  cat > "$tag_dir/site/_projects/ghost-tagged-project.html" <<'FIXTURE'
---
title: "Ghost tagged project"
date: 2026-03-01
tags: [ghost]
---
<p>Fixture content.</p>
FIXTURE

  (cd "$tag_dir/site" && jekyll build --destination _site --quiet)

  design_page="$tag_dir/site/_site/tags/design/index.html"
  unused_page="$tag_dir/site/_site/tags/unused/index.html"

  design_page_ok() {
    local order
    order="$(grep -o 'Newer tagged project\|Older tagged post' "$design_page" | tr '\n' ' ')"
    test -f "$design_page" \
      && grep -q 'class="entry"' "$design_page" \
      && test "$order" = "Newer tagged project Older tagged post "
  }
  unused_page_ok() {
    test -f "$unused_page" && grep -q 'No entries tagged' "$unused_page"
  }

  check "design tag page lists both matching entries newest-first via entry.html" \
    design_page_ok
  check "unused tag page still builds and shows a no-entries message" \
    unused_page_ok
  check "no _site/tags/ghost/ directory is produced for the unstubbed tag" \
    not test -d "$tag_dir/site/_site/tags/ghost"

  # Entry tags (issue #51): an entry's `tags` front matter renders on
  # entry.html as one link per tag to that tag's generated page, and is
  # absent entirely - no heading, no empty container - when there are none.
  # Reuses $list_dir, still live at this point in the script.
  copy_site_into "$list_dir/tagged"
  mkdir -p "$list_dir/tagged/_projects"
  cat > "$list_dir/tagged/_projects/tagged-project.html" <<'FIXTURE'
---
title: "Tagged fixture project"
date: 2026-01-01
tags: [design, travel]
---
<p>Fixture content.</p>
FIXTURE
  (cd "$list_dir/tagged" && jekyll build --destination _site --quiet)
  tagged_page="$list_dir/tagged/_site/projects.html"
  check "an entry's 'design' tag links to that tag's generated page" \
    grep -Eq 'href="[^"]*/tags/design/">design</a>' "$tagged_page"
  check "an entry's 'travel' tag links to that tag's generated page" \
    grep -Eq 'href="[^"]*/tags/travel/">travel</a>' "$tagged_page"

  copy_site_into "$list_dir/no-tags-key"
  mkdir -p "$list_dir/no-tags-key/_projects"
  cat > "$list_dir/no-tags-key/_projects/no-tags-project.html" <<'FIXTURE'
---
title: "No tags fixture project"
date: 2026-01-01
---
<p>Fixture content.</p>
FIXTURE
  (cd "$list_dir/no-tags-key" && jekyll build --destination _site --quiet)
  check "an entry with no tags key renders no tag container" \
    not grep -q 'entry__tags' "$list_dir/no-tags-key/_site/projects.html"

  copy_site_into "$list_dir/empty-tags-list"
  mkdir -p "$list_dir/empty-tags-list/_projects"
  cat > "$list_dir/empty-tags-list/_projects/empty-tags-project.html" <<'FIXTURE'
---
title: "Empty tags fixture project"
date: 2026-01-01
tags: []
---
<p>Fixture content.</p>
FIXTURE
  (cd "$list_dir/empty-tags-list" && jekyll build --destination _site --quiet)
  check "an entry with an empty tags list renders no tag container" \
    not grep -q 'entry__tags' "$list_dir/empty-tags-list/_site/projects.html"

  rm -rf "$neg_dir" "$pos_dir" "$list_dir" "$home_dir" "$tag_dir"
  trap - EXIT
else
  echo "FAIL: jekyll is available (gem install jekyll failed - check network access / Ruby gem environment)"
  fail=1
fi

exit $fail
