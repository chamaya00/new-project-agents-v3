#!/usr/bin/env bash
# Structural checks for issue #6's acceptance criteria. No package manager,
# no build step, no test framework in this repo, so these are the grep /
# file-existence checks the criteria themselves name, made runnable.
# The mobile-viewport criterion has no scriptable check (per its own
# acceptance criterion: "checked by a mobile-emulation pass in devtools")
# and is out of scope for this script.
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
check ".nojekyll exists at repo root" test -f .nojekyll

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

exit $fail
