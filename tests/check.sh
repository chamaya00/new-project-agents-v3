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

check "index.html exists at repo root" test -f index.html
check "about.html exists at repo root" test -f about.html
check ".nojekyll exists at repo root" test -f .nojekyll

check "no root-absolute href in index.html" \
  ! grep -Eq 'href="/[^/]' index.html
check "no root-absolute href in about.html" \
  ! grep -Eq 'href="/[^/]' about.html
check "no root-absolute stylesheet link in index.html" \
  ! grep -Eq 'href="/[^/]' index.html
check "no root-absolute stylesheet link in about.html" \
  ! grep -Eq 'href="/[^/]' about.html

check "index.html nav marks Home as current" \
  grep -q 'href="index.html" aria-current="page"' index.html
check "about.html nav marks About as current" \
  grep -q 'href="about.html" aria-current="page"' about.html

check "no off-repo <script src= in index.html" \
  ! grep -Eq '<script[^>]+src="(https?:)?//' index.html
check "no off-repo <script src= in about.html" \
  ! grep -Eq '<script[^>]+src="(https?:)?//' about.html
check "no form action= in index.html" \
  ! grep -q '<form' index.html
check "no form action= in about.html" \
  ! grep -q '<form' about.html

exit $fail
