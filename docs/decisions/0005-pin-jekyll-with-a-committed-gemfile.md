# ADR 0005: Pin Jekyll with a committed Gemfile, built with Bundler

Date: 2026-09-14
Status: accepted

## Context

`tests/check.sh` has installed Jekyll ad hoc since issue #17:
`gem install jekyll --user-install`, with no version pin, run again on every
invocation of the script. Nothing records which Jekyll version last built the
site, so a version bump upstream changes what "green" means here with no diff
to review. `docs/research/vercel-deploy.md` (issue #90) found that a Vercel
deployment of this repository needs a committed `Gemfile` regardless - its
Jekyll framework detector's zero-config `installCommand` is `bundle install`,
which has nothing to install without one - and recommended pinning
`jekyll ~> 4.4` (currently resolving to `4.4.1`) plus `webrick` (needed by
`jekyll serve`, not `jekyll build`, but cheap to include and expensive to
discover missing later).

Once a `Gemfile` exists, the ad hoc `gem install` line stops being merely
unpinned - it becomes a second, disagreeing build path from the one the
`Gemfile` names. This repository has already lived through exactly that kind
of drift once: ADR 0003 records eight failed deployments while `tests/check.sh`
stayed green, because the gate built with the plain `jekyll` gem while GitHub
Pages built with a different one. A committed, version-pinned `Gemfile` that
both the gate and any future deploy target read from is what closes that gap
for the Jekyll version specifically.

## Decision

Add a `Gemfile` to the repository root pinning `jekyll` to `~> 4.4` and adding
`webrick`, with no `ruby` directive - Jekyll 4.4.1 only requires Ruby
`>= 2.7.0`, and pinning a Ruby version here would gate the build on whichever
Ruby happens to be on a given runner, which this repository does not control
and does not need to control to build. Commit the matching `Gemfile.lock`,
generated with `bundle lock --add-platform x86_64-linux` so the lockfile
resolves on the Linux platform any CI runner or Linux-based deploy target
uses, per `docs/research/vercel-deploy.md`.

Change `tests/check.sh`'s `ensure_jekyll` to install through Bundler instead
of `gem install`: `bundle config set path 'vendor/bundle'` followed by
`bundle install`, then every `jekyll` invocation in the script goes through
`bundle exec`. The vendored path is what makes this work in a sandbox with no
write access to the system Ruby's gem directories - the same constraint the
old `--user-install` flag existed to work around - without needing root or a
pre-provisioned writable system gem path on every runner this script might
run on.

## Consequences

A green `bash tests/check.sh` is now evidence about the exact Jekyll version
the `Gemfile` pins, not whatever version `gem install jekyll` happened to
resolve to on a given runner on a given day. Bumping Jekyll becomes a
reviewable diff to `Gemfile`/`Gemfile.lock` instead of a silent change in
behavior. The build is slower on a cold cache - `bundle install` now resolves
and installs Jekyll and its dependencies into `vendor/bundle` on first run in
a given checkout, the same cost `gem install jekyll` already paid, just
recorded rather than repeated blind. `.bundle/` and `vendor/bundle/` are
untracked (added to `.gitignore`) so that local per-checkout install state
never gets committed. This is also the repository's first committed
dependency of any kind, which is why this ADR exists per the house rules'
dependency-change requirement - Bundler and RubyGems are now something this
repository's build relies on, not just something a runner happens to have.

## Alternatives rejected

- **Keep the ad hoc `gem install jekyll --user-install`, unpinned**: rejected
  because it is the problem this ADR exists to fix - the check's build target
  drifts with whatever Jekyll release is current at run time, and any future
  deploy target reading a committed `Gemfile` (Vercel, per #90) would run a
  different, disagreeing build regardless.
- **Install with plain `bundle install` (no vendored path)**: rejected for
  this environment - the runner this script has actually been proven against
  has no write access to the system Ruby's gem directories, so a
  non-vendored `bundle install` fails with a `Bundler::PermissionError`
  before Jekyll ever builds. Vendoring into `vendor/bundle` costs nothing a
  `.gitignore` entry doesn't already handle, and is what a local
  `bundle install --path vendor/bundle` (per this issue's own acceptance
  criterion 5) already assumes.
- **Pin a `ruby` version in the Gemfile, matching Vercel's `3.3.x` build
  image**: rejected - the runner this script actually runs on ships Ruby
  3.2.3, and a `ruby "~> 3.3"` directive makes `bundle install` refuse to run
  here at all. `docs/research/vercel-deploy.md` itself flagged the Ruby pin
  as inferred rather than required; Jekyll 4.4.1's own floor of Ruby
  `>= 2.7.0` is satisfied either way, so the directive bought nothing but a
  broken gate.
