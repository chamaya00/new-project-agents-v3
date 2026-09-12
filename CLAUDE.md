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
- Dev: `python3 -m http.server` still works for `about.html`, the one page
  left that is pure hand-authored HTML, but no longer renders
  collection-driven pages correctly - it skips Jekyll's build entirely. Home
  joined that set when it gained its Recent area, so `index.html` now needs
  the build too. For a real preview, install Ruby and the `jekyll` gem
  (`gem install jekyll`) and run
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

There is one check above, `bash tests/check.sh` - typecheck and lint don't
apply to hand-authored HTML/CSS, and the only build is the Jekyll one that
script runs itself. That one check is what CI runs:
`.github/workflows/ci.yml` calls it and nothing else, so adding a check means
editing the script, never the workflow. It is the real gate - the placeholder
that used to fail the moment product code landed has done its job and is
gone.

Whatever the gate runs, the rule is the same. If a check is renamed here,
rename it in `.github/workflows/ci.yml` in the same commit, and re-point the
branch protection rule in the same sitting, or the gate silently stops checking
that thing.

## How work moves

Objectives become issues labelled `objective`. A human labels the objective
`agent:queued`; nothing else needs labelling by hand. The orchestrator splits it
into 2-5 child issues, each with acceptance criteria and one role label, and
queues them itself as each becomes ready.

It stays with the objective after the split. A child reaching `agent:review` or
`agent:blocked` wakes it: it reads the state of every child, queues whatever the
merge just unblocked, rewrites and re-queues a child that blocked on its own
scoping, and replaces the status picture on the parent issue. The parent issue
is the whole surface - read that, and the orchestrator comes to you when a
decision is genuinely yours.

Ready means the issues a child depends on are merged to `main`, not merely
labelled `agent:review`. Every role opens a pull request for its own work now,
the researcher and the designer included, so the usual gap is an open pull
request nobody has merged yet rather than a branch nobody opened one for. But
`agent:review` still means a run finished, never that anything landed, and a run
that ended on its turn cap can have pushed a branch before it got that far.
Telling those two apart is the orchestrator's job before it queues anything, and
it says which one it is looking at - "waiting on a merge" sends you to a page
with nothing on it when no pull request exists.

Merging is still yours by default. An objective may carry a `Merge policy: green`
line in its body, which hands that objective's children to your own session to
merge once each passes the gate in the house-rules skill - scoped to that one
objective, revoked by editing the issue, and never written by a role. The
orchestrator cannot break a child down further - that comes back as
`needs-decomposition` and a comment on the parent.

**This needs the agent App configured.** Events raised by the default Actions
token do not start workflow runs, so without `AGENT_APP_ID` and
`AGENT_APP_PRIVATE_KEY` every label the orchestrator applies raises nothing: the
objective decomposes and then stops, silently, with correctly labelled children
that never run. Without the App, queue each child by hand - the older flow.

Labels: `objective`, `agent:queued`, `agent:running`, `agent:review`,
`agent:blocked`, `needs-decomposition`, `needs-human`, `role:researcher`,
`role:designer`, `role:engineer`.

`needs-human` arrived with factory v1.21.0 and marks an objective waiting on a
person rather than on a run. The labels are created by the `bootstrap` workflow,
so it does not exist here until that is re-run by hand from the Actions tab -
and the orchestrator is already instructed to apply it.

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
