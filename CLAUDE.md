# Project context

## What this is

A scratch repository for exercising the agent factory's provisioning, labels,
and agent runs end to end.

## Stack

Static HTML5 + CSS3, no JavaScript, no framework, no package manager. Hosted
on GitHub Pages as a project site (served at `/<repository-name>/`, per
`docs/research/pages-subpath.md`). Content files are still hand-authored
HTML5. Jekyll is enabled (`.nojekyll` removed, `_config.yml` added, per
`docs/decisions/0001-enable-jekyll-for-content-listings.md`) to turn the
`_posts` and `_projects` collections into generated listing pages - this is
GitHub Pages' own build machinery running on GitHub's infrastructure on
every push, not tooling this repo installs or maintains. Hand-authored pages
outside the collections keep the existing relative-link convention with no
leading slash; generated collection pages nest at a variable depth and use
Jekyll's `relative_url`/`site.baseurl` instead, per ADR 0001.

## Commands

- Install: not applicable - no package manager, nothing to install. The gate
  installs its own Jekyll gem on demand (see Test, below); nothing is
  committed for it (no Gemfile).
- Dev: `python3 -m http.server` still works for the hand-authored pages
  (`index.html`, `about.html`), but no longer renders collection-driven
  pages correctly - it skips Jekyll's build entirely. For a real preview,
  install Ruby and the `jekyll` gem (`gem install jekyll`) and run
  `jekyll serve` from the repo root; that runs the same build `tests/check.sh`
  runs, and serves it with live paths.
- Typecheck / lint / build: not applicable in the compile-step sense - Jekyll
  is GitHub Pages' own build, invoked from `tests/check.sh` (see Test) rather
  than a separate step this repo runs on its own.
- Test: `bash tests/check.sh` - structural checks (file existence, relative
  links, no tracking/form code) for each acceptance criterion that can be
  scripted, plus the Jekyll build itself: installs the `jekyll` gem if it
  isn't already on the runner, builds the real site, and builds two throwaway
  fixtures to prove the collection mechanism (a valid one lands under
  `_site/projects/<slug>/`, an invalid one fails the build and names the
  file). Viewport/visual criteria are checked manually with devtools mobile
  emulation, per the issue that added the page being checked.

There is one check above, `bash tests/check.sh` - typecheck, lint, and build
don't apply to a static HTML/CSS site with no compile step. That one check is
what CI runs once the gate is real. Until then it is not: `.github/workflows/ci.yml`
ships a placeholder that checks the scaffolding is intact and fails the moment
product code lands, because a project gets its gate before it gets its stack
and a gate that goes green on untested code is worse than no gate. Replacing
it is a step in building this project, not a chore to do later - the comment
at the top of that file says how.

Whatever the gate runs, the rule is the same. If a check is renamed here,
rename it in `.github/workflows/ci.yml` in the same commit, and re-point the
branch protection rule in the same sitting, or the gate silently stops checking
that thing.

## How work moves

Objectives become issues labelled `objective`. The orchestrator splits one into
2-5 child issues, each with acceptance criteria and one role label. A human
labels a child `agent:queued` when it is ready to run. Nothing runs itself.

Labels: `objective`, `agent:queued`, `agent:running`, `agent:review`,
`agent:blocked`, `needs-decomposition`, `role:researcher`, `role:designer`,
`role:engineer`.

## Standing rules

Acceptance criteria before work starts. Tests before merge. An ADR in
`docs/decisions/` for any schema or dependency change, in the same diff.

Three failed attempts on one issue means the issue was scoped wrong. Stop and
ask for decomposition rather than trying a fourth time.

Never edit `.github/workflows/`, `CODEOWNERS`, or anything under a plugin
directory. If the work seems to need it, say so in a comment and stop.

## Memory

Lessons specific to this repository live in `.claude/memory/<role>.md`, one file
per role, 40 lines each. They are proposed in a pull request, never written
silently. A lesson that has graduated into a test, a lint rule, or a type gets
deleted - the check enforces it now, and the sentence is competing for attention
with the lessons nothing enforces yet.
