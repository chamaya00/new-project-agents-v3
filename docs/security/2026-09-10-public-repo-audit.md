# Security review: this repository as a public repository

Date: 2026-09-10
Scope: `chamaya00/new-project-agents-v3` at `876b1ef`, and the factory
release it runs, `chamaya00/agent-factory@v1.18.0`
(`13948257a2f59f0ac00bac54a7d345efc1edd817`).

The question asked: with this repository public, can anyone outside it
contaminate an agent run, spend the Claude subscription, or reach the
secrets? Everything below was read at the pinned release rather than at
the factory's `main`, because the pin is what actually runs here.

## What the repository looks like from outside

| | |
|---|---|
| Visibility | public, forking allowed, issues and wiki on |
| Collaborators | `chamaya00` alone, admin |
| `main` | protected |
| Open issues at review time | #55, #56, #57 - all commentable by anyone |
| Secrets reachable from a run | `CLAUDE_CODE_OAUTH_TOKEN`, `AGENT_APP_ID`, `AGENT_APP_PRIVATE_KEY` |

## Findings

Severity is about this repository as configured, not the worst case the
same code could produce elsewhere.

### 1. Prompt injection through issue and comment bodies - HIGH, open

The one with no clean fix, and the reason the rest of this document is
short.

Trigger gating decides *who may start* a run. It does not touch *what a
run reads*. `.claude/agents/orchestrator.md` instructs the role to
"[r]ead the objective in full, including every comment - the latest
usually carries the correction", and on a public repository any account
can write those comments.

The attack needs no trigger at all. A comment is left on an open issue
and simply waits; the next legitimate run - started by the owner, fully
authorised - reads it as context. `claude-code-action` strips HTML
comments, invisible characters, markdown image alt text and hidden HTML
attributes, which defeats a *concealed* payload. It cannot defeat plain
visible prose that reads like a correction to the issue, and Anthropic's
own security guidance says as much.

What limits it is blast radius, not prevention: branch protection and
CODEOWNERS decide what a run's diff can reach, and a human merges. What
is *not* limited is what the run does while it is running - see 2.

**Residual risk. Treat every issue comment from outside as untrusted
input, and read the diff of any run that followed one.**

### 2. The Bash allowlist scopes; it does not contain - HIGH, documented

`agent-run.yml` grants the engineer `Write` and `Edit` next to
`Bash(bash tests/*)`, `Bash(./scripts/*)`, `Bash(npm install:*)` and
`Bash(make:*)`. A run can therefore author `tests/check.sh`, a
`postinstall` hook, or a `Makefile` target and then execute it, meeting
the allowlist at every step. The step's environment holds `GH_TOKEN`;
the job holds the OAuth token.

The factory's comment claimed the per-runner scoping was what stopped a
role "rewrit[ing] the gates it is being checked by". It never did.

This is not fixed by trimming the list. An engineer that writes tests and
runs them has arbitrary execution by construction, and taking the runners
away is precisely what once had a role verify its criteria with inline
greps and report a test script that could not pass. Adding `tests/**` to
the project guard's `protected-paths` was considered and **rejected**:
that check hard-fails the pull request, and writing tests is the
engineer's job, so it would break every engineer run rather than contain
one.

Fixed upstream by correcting the comment, so nobody builds on a
containment that is not there. The real boundary is the write-access
check on triggering, branch protection, CODEOWNERS, and the project
guard - all of which act on the *diff*, not on the running process.

### 3. Reusable workflows pinned to a movable tag - MEDIUM-HIGH, fixed

All four callers referenced `@v1.18.0`. A git tag is a movable pointer:
repointing it changes what executes here - with the OAuth token and the
App private key - and no diff lands in this repository for anyone to
read. Now pinned to the commit SHA with the release kept as a trailing
comment, and `tests/check.sh` fails the build if any caller drifts back
to a tag or loses its release comment.

`/update-agents` must now rewrite both halves together.

### 4. A stranger could reach the preflight's write path - LOW-MEDIUM, fixed

The preflight gated a comment on the trigger phrase alone. No author
check. `claude-code-action` refuses a triggering actor without write
access - verified, and `allowed_non_write_users` (the documented bypass,
which Anthropic calls "a significant security risk") is absent - so **the
subscription was never exposed this way.**

But that check runs a job too late. The preflight had already run with
`issues: write`, and its budget-exceeded path labels `agent:blocked`,
strips the run label and comments. A stranger commenting `@claude` on an
issue that had already had three runs could trigger that. Label griefing,
not theft.

Fixed upstream: the preflight now refuses on `author_association` as
well. `CONTRIBUTOR` is refused deliberately - on a public repository that
is one merged drive-by typo fix, not write access.

### 5. Memory files steer every future run - MEDIUM, partly fixed

`.claude/memory/<role>.md` is read at the start of every run by every
role, and is meant to be trusted rather than re-examined. The project
guard checks only that each file is inside its 40-line cap; nothing
checks what the lines say. One merged edit steers every later run.

Now covered by CODEOWNERS, so a change needs the owner's review. The cap
check is unchanged.

### 6. Fork pull requests execute `tests/check.sh` from their own head - MEDIUM, settings

`ci.yml` runs on `pull_request` and executes the script as the pull
request wrote it. Fork pull requests get no secrets and a read-only
token, so this is compute abuse rather than disclosure. GitHub's default
only holds approval for *first-time* contributors - one merged pull
request promotes an account past it. See the checklist below.

### Not problems

- **Label triggering.** `issues: [labeled]` needs triage permission.
- **`pull_request: [closed]`.** It is `pull_request`, not
  `pull_request_target`, so a fork's pull request carries no secrets.
  Had it been the latter this would head the list.
- **`workflow_dispatch`.** Needs write access.

## What changed here

- `.github/workflows/*.yml` - all four callers pinned to
  `13948257a2f59f0ac00bac54a7d345efc1edd817`, release kept as a comment.
- `.github/CODEOWNERS` - adds `/tests/`, `/scripts/`, `/.claude/memory/`
  and `/.claude/`.
- `tests/check.sh` - two checks that the pins stay SHAs and keep naming
  their release. Both were made to fail on purpose before being kept.

Upstream, on `chamaya00/agent-factory`, branch
`claude/harden-agent-run-untrusted-input`: the `author_association` gate,
the corrected allowlist comment, and four preflight cases. **Nothing here
runs that code until the pin above is moved to a release containing it.**

## Only the owner can do these

1. **Settings > Actions > General > Fork pull request workflows**: set
   approval to **all outside collaborators**, not first-time
   contributors (finding 6).
2. **Branch protection on `main`**: confirm *Require review from Code
   Owners* is on, or the CODEOWNERS entries above are advisory.
3. **Settings > General**: turn off the wiki - it is unused surface.
4. **Rotate `CLAUDE_CODE_OAUTH_TOKEN`** if any run has ever executed
   against an issue carrying a comment from outside. Cheap, and finding 1
   has no other remedy after the fact.
5. **Review, then merge** the factory branch, cut a release, and bump the
   SHA here.
