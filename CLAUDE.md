# Project context

## What this is

A scratch repository for exercising the agent factory's provisioning, labels,
and agent runs end to end.

## Stack

Static HTML5 + CSS3, no JavaScript, no framework, no package manager, no build
step. Hosted on GitHub Pages as a project site (served at
`/<repository-name>/`, per `docs/research/pages-subpath.md`). All internal
links are relative with no leading slash, for the same reason.

## Commands

- Install: not applicable - no package manager, nothing to install.
- Dev: open `index.html` directly in a browser, or serve the root with any
  static file server (e.g. `python3 -m http.server`) to test relative paths
  the way GitHub Pages will serve them.
- Typecheck / lint / build: not applicable - plain static HTML/CSS has no
  compile step.
- Test: `bash tests/check.sh` - structural checks (file existence, relative
  links, no tracking/form code) for each acceptance criterion that can be
  scripted. Viewport/visual criteria are checked manually with devtools
  mobile emulation, per the issue that added the page being checked.

The four checks above are what CI runs once the gate is real. Until then it is
not: `.github/workflows/ci.yml` ships a placeholder that checks the scaffolding
is intact and fails the moment product code lands, because a project gets its
gate before it gets its stack and a gate that goes green on untested code is
worse than no gate. Replacing it is a step in building this project, not a
chore to do later - the comment at the top of that file says how.

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
