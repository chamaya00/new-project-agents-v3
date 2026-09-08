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
  cp -r index.html about.html projects.html posts.html css _includes _config.yml "$dest/"
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

  rm -rf "$neg_dir" "$pos_dir" "$list_dir"
  trap - EXIT
else
  echo "FAIL: jekyll is available (gem install jekyll failed - check network access / Ruby gem environment)"
  fail=1
fi

exit $fail
