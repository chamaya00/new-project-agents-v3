# ADR 0006: Pin the factory's reusable workflows by commit SHA, not by tag

Date: 2026-10-14
Status: accepted

## Context

Every workflow in `.github/workflows/` is a thin caller into
`chamaya00/agent-factory`, and each has named its release as a tag -
`@v1.18.0`, then `@v1.23.0`, then `@v1.24.0` as `/update-agents` moved it.
`ci.yml`'s own comment argues the pin carefully: this repository keeps running
that exact release until somebody bumps the line and merges it, so a new
factory release changes nothing here on its own, and the diff gets read here
before it runs here.

A git tag does not deliver the immutability that argument assumes. A tag is a
movable pointer, and moving one in the factory changes what executes here with
no diff landing in this repository for anyone to read - which is the precise
property the comment was claiming. `agent-run.yml` is the sharp case, because
it hands the called workflow `CLAUDE_CODE_OAUTH_TOKEN` and the agent App's
private key.

This is the argument ADR 0005 already made about Jekyll, applied to a different
dependency. There, an unpinned `gem install` meant "a version bump upstream
changes what green means here with no diff to review". Here, a movable tag
means an upstream repoint changes what *runs* here, with secrets, with no diff
to review. ADR 0003 records this repository losing eight deployments to the
same shape of problem: two build paths that disagreed, and a gate that stayed
green through it.

The security review in `docs/security/2026-09-10-public-repo-audit.md` raised
it as finding 3.

## Decision

Each caller names the factory workflow by its 40-hex commit SHA, with the
release it corresponds to kept beside it as a trailing `# vX.Y.Z` comment. Both
halves are required and `tests/check.sh` enforces both: a reference that is not
a SHA fails, and a SHA without its release comment fails. `/update-agents`
therefore rewrites the two together - the SHA is what runs, the comment is what
it is called - and a bump that updates only the comment does not merge.

The SHA is resolved from the tag at bump time and verified to be a commit
rather than an annotated tag object, because the two are different hashes and
only one of them is a valid `uses:` ref.

## Consequences

Easy: a reader can still see which release is running, and the pin now cannot
change under this repository without a commit here.

Hard: the refs are no longer skimmable, and bumping is a two-field edit rather
than one. Both costs land on `/update-agents`, which is already the only
intended path for a bump and already reads this file's sibling ADRs.

Ruled out later: pinning to a moving major like `@v1`, which the factory's own
README offers. That convenience is now unavailable here by test, deliberately -
`@v1` is a tag that is *expected* to move, which is the whole failure mode.

The check also means a hand-edited bump fails CI rather than silently pinning
a release the comment misnames. That is intended: the failure is cheap and the
mismatch is not.

## Alternatives rejected

**Keep the tag and trust the factory.** Both repositories are the same
owner's, so a repoint would be self-inflicted. Rejected because the pin's
stated purpose is that the diff gets read here before it runs here, and a tag
cannot deliver that regardless of who owns the other end - account compromise
and an accidental `git tag -f` produce the same result as malice.

**Pin to `@v1` or another moving major.** Rejected for the reason above, more
so: it is a pointer designed to move.

**Vendor the reusable workflows into this repository.** Rejected because it
defeats the factory - the point of a thin caller is that shared logic is
maintained once, and a vendored copy drifts silently and is `CODEOWNERS`-
protected against the agents who would have to update it.

**Verify the tag's SHA in CI on every run instead of pinning.** Rejected as
strictly weaker: it detects a repoint after the workflow has already run with
the repository's secrets, which is the moment the pin exists to prevent.
