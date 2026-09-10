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

check "projects.html exists at repo root" test -f projects.html
check "posts.html exists at repo root" test -f posts.html
check "_includes/entry.html exists" test -f _includes/entry.html

# Hand-authored links stay relative with no leading slash; the one place a
# path is generated rather than typed - an entry's link, whose page nests at a
# variable depth - goes through Liquid's relative_url, per ADR 0001. So the
# same grep covers both: a literal root-absolute path is a failure everywhere,
# including in the include.
for page in index.html about.html projects.html posts.html _includes/entry.html; do
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
  check "no off-repo <script src= in $page" \
    not grep -Eq '<script[^>]+src="(https?:)?//' "$page"
  check "no form action= in $page" \
    not grep -q '<form' "$page"
done

# --- Jekyll build ---------------------------------------------------------
# Proves the ADR 0001 mechanism actually works, not just that the config
# file has the right shape. `jekyll build` fails loudly (non-zero exit) on
# a YAML front-matter error, which is what the negative check below relies
# on.

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

if ensure_jekyll; then
  echo "PASS: jekyll is available ($(jekyll --version))"

  check "jekyll build of the real site succeeds" \
    jekyll build --destination _site

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

  recent_section() {
    awk -v heading="$2" '
      index($0, ">" heading "<") { inside = 1 }
      inside { print }
      inside && /<\/section>/ { exit }
    ' "$1"
  }

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
  copy_site_into "$home_dir/baseurl"
  mkdir -p "$home_dir/baseurl/_projects"
  cat > "$home_dir/baseurl/_projects/based-project.html" <<'FIXTURE'
---
title: "Based fixture project"
date: 2026-01-01
tags: [based]
---
<p>Fixture content.</p>
FIXTURE
  mkdir -p "$home_dir/baseurl/_posts"
  cat > "$home_dir/baseurl/_posts/2026-01-02-based-post.html" <<'FIXTURE'
---
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
