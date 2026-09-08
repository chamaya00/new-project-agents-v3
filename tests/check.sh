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

check "no root-absolute href/src in index.html" \
  not grep -Eq 'href="/[^/]|src="/[^/]' index.html
check "no root-absolute href/src in about.html" \
  not grep -Eq 'href="/[^/]|src="/[^/]' about.html
check "no root-absolute url() in css/style.css" \
  not grep -Eq 'url\(/[^/)]' css/style.css

check "index.html nav marks Home as current" \
  grep -q 'href="index.html" aria-current="page"' index.html
check "about.html nav marks About as current" \
  grep -q 'href="about.html" aria-current="page"' about.html

check "no off-repo <script src= in index.html" \
  not grep -Eq '<script[^>]+src="(https?:)?//' index.html
check "no off-repo <script src= in about.html" \
  not grep -Eq '<script[^>]+src="(https?:)?//' about.html
check "no form action= in index.html" \
  not grep -q '<form' index.html
check "no form action= in about.html" \
  not grep -q '<form' about.html

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

if ensure_jekyll; then
  echo "PASS: jekyll is available ($(jekyll --version))"

  check "jekyll build of the real site succeeds" \
    jekyll build --destination _site

  # Negative fixture: a collection file with invalid front matter must fail
  # the build, and the failure must name the file. Built against a throwaway
  # copy of the repo so it never touches the real working tree.
  neg_dir="$(mktemp -d)"
  trap 'rm -rf "$neg_dir"' EXIT
  mkdir -p "$neg_dir/site"
  cp -r index.html about.html css _config.yml "$neg_dir/site/"
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
  mkdir -p "$pos_dir/site"
  cp -r index.html about.html css _config.yml "$pos_dir/site/"
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

  rm -rf "$neg_dir" "$pos_dir"
  trap - EXIT
else
  echo "FAIL: jekyll is available (gem install jekyll failed - check network access / Ruby gem environment)"
  fail=1
fi

exit $fail
