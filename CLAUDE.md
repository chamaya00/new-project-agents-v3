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

## What is different here

This section sits outside the managed block below on purpose: it is what this
repository knows about the shared process that the shared process does not know
about itself. Nothing in an update overwrites it.

**Every role opens a pull request for its own work here, the researcher and the
designer included.** The block below says they cannot and push a branch instead.
That is stale in this release: `.claude/agents/researcher.md` and
`.claude/agents/designer.md` both carry `mcp__github__create_pull_request` and
both instruct opening one as the deliverable. So the usual gap between a child
finishing and its dependants becoming ready is an open pull request nobody has
merged, not a branch nobody opened one for.

`agent:review` still means only that a run finished, never that anything landed,
and a run that ended on its turn cap can have pushed a branch before it got that
far. Telling those two apart is the orchestrator's job before it queues
anything, and it says which one it is looking at - "waiting on a merge" sends
you to a page with nothing on it when no pull request exists.

**The agent App has to be configured.** Events raised by the default Actions
token do not start workflow runs, so without `AGENT_APP_ID` and
`AGENT_APP_PRIVATE_KEY` every label the orchestrator applies raises nothing: the
objective decomposes and then stops, silently, with correctly labelled children
that never run. Without the App, queue each child by hand - the older flow.

**`needs-human` may not exist as a label yet.** It arrived with factory v1.21.0
and marks an objective waiting on a person rather than on a run. The labels are
created by the `bootstrap` workflow, so it does not exist here until that is
re-run by hand from the Actions tab - and the orchestrator is already instructed
to apply it.

<!-- agent-factory:begin -->
<!-- Everything from here to the agent-factory:end marker describes the shared
     process rather than this project, and /update-agents replaces the whole
     block when this repository moves to a new factory release. An edit inside
     it is lost on the next update: put anything specific to this repository
     outside the block, where nothing will overwrite it. -->

## How work moves

Objectives become issues labelled `objective`. A human labels the objective
`agent:queued`; nothing else needs labelling by hand. The orchestrator splits it
into 2-5 child issues, each with acceptance criteria and one role label, and
then queues them itself as each one becomes ready.

It stays with the objective after the split. A child reaching `agent:review` or
`agent:blocked` wakes it: it reads the state of every child, queues whatever the
merge has just unblocked, rewrites and re-queues a child that blocked on its own
scoping, and replaces the status picture on the parent issue. The parent issue
is the whole surface - a human reads that and nothing else, and hears from the
orchestrator when a decision is genuinely theirs.

Ready means the issues a child depends on are merged to the default branch, not
merely finished and labelled `agent:review`. The researcher and the designer
cannot open pull requests - they push a branch and leave a link for a human -
so their work can be complete and still invisible to the next agent, which
reads the default branch. A run started too early refuses, correctly, and still
spends one of that issue's three attempts. That check is now the orchestrator's
to make before it queues anything.

The human still decides what merges. The orchestrator queues work and reports on
it; it does not merge a pull request, and it cannot break a child down further -
that comes back as `needs-decomposition` and a comment on the parent.

Labels: `objective`, `agent:queued`, `agent:running`, `agent:review`,
`agent:blocked`, `needs-decomposition`, `needs-human`, `role:researcher`,
`role:designer`, `role:engineer`.

## Driving an objective

A session that files an objective, or is pointed at one, is that objective's
driver and the person's window into it. Nobody else is watching. Filing one is
`/objective`, which refines the idea, sets the merge policy, queues it, and
hands back to the session to drive.

**Read `.claude/skills/driving-an-objective/` whenever an objective is in play**
- what to do with its merge policy, how to report, how to put a blocker so it
can be answered, and what only the person can decide. This paragraph exists to
say the role is yours; the skill says how to hold it.

## The rules

Not restated here. Two sections used to summarise them and every line had a
fuller source a click away, so the summaries could only ever drift out of
agreement with the thing they summarised - which is worse than not having them,
because a reader who finds a rule here stops looking for the real one.

- `.claude/skills/house-rules/` - what must be true before work starts and
  before anything merges, who may merge, the three-strike rule, and what no
  agent may touch.
- `.claude/skills/memory-protocol/` - how this repository's lessons are stored,
  capped, proposed, and retired.
- `.claude/skills/acceptance-criteria/` - what a criterion has to look like to
  gate anything.
- `.claude/skills/driving-an-objective/` - what the session in front of a person
  does once an objective is running.

Every agent run is told to follow the first three by name. The fourth is for the
session driving, which is why the section above names it rather than leaving it
to be discovered.

<!-- agent-factory:end -->
