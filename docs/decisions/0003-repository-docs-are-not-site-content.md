# 3. Repository documentation is not site content

Date: 2026-09-10

## Status

accepted

## Context

ADR 0001 turned Jekyll on and described it as "GitHub Pages' own build
machinery running on GitHub's infrastructure". That was true about where the
build runs and wrong about what runs. Pages does not execute `jekyll build`.
It executes the `github-pages` gem: Jekyll 3.10.0 plus a dozen plugins the
plain gem does not have.

One of those plugins, `jekyll-optional-front-matter`, promotes every `.md`
in the repository to a page and renders it through Liquid.
`docs/research/tag-pages.md` quotes Liquid in its code samples, including an
excerpt carrying an `{% if %}` with no matching `{% endif %}` - correct as an
illustration of a fragment, fatal when executed as a template. Pages tried to
execute it.

Every deployment from that merge onward failed: eight merges across nineteen
hours, including two that added the site's first real content. The site kept
serving the last build that had worked, so it showed empty listings while
`main` carried five content files. `tests/check.sh` was green on every one of
those merges, because the plain gem treats the same file as a static asset
and copies it through unparsed. The gate and the deployment disagreed about
what the site even consists of, and nothing in the repository could report
the difference.

A structural check would not have found the Liquid error. The file is valid
Markdown, valid prose, and correct documentation. It is only invalid as a
template, and only one of the two toolchains treats it as one.

## Decision

`_config.yml` excludes `docs`, `tests`, `CLAUDE.md` and `README.md`.

Repository documentation is not site content. Excluding it fixes the break
and removes the whole class rather than the instance: prose is free to quote
Liquid because nothing renders it. It also stops publishing ADRs and research
notes at `/docs/...` under a default theme nobody chose, which was never
intended and which nobody had noticed either.

`tests/check.sh` asserts that no excluded path and no repository Markdown
appears in the built site.

## Consequences

The exclude list is now load-bearing, and its failure mode is silent
publication rather than a crash. That is what the new assertions are for:
shortening the list fails the gate instead of quietly putting internal
documents back on a public site.

**The gate still does not build what ships, and this ADR does not fix that.**
The assertions above run under the plain gem, so they catch the precondition
- documentation reaching the site at all - and not the Liquid error itself.
Had they existed a day earlier they would have failed on the merge that broke
the deployment, for the right reason, which is why they are worth having. But
a Pages-only failure of a different shape would still pass here.

Closing that gap properly means building with the `github-pages` gem in the
gate, and the attempt is recorded here because it failed rather than because
it worked: installing `github-pages` after `jekyll` in the same user gem
directory fails dependency resolution on the runner, since the gem pins
`jekyll = 3.10.0` against the 4.x the gate has already installed. Reproducing
that locally needs an environment that does not already have both resolved,
and running Pages' own container image needs a Docker daemon. Neither was
available to verify against, and shipping an unverified fix for a gate is
worse than shipping a gate with a stated hole.

So the hole is stated. Until it closes, a green run here means this
repository's own Liquid is sound and its documentation is not being
published. It does not mean the site will deploy. The deployment's own status
on `main` is the only thing that means that, and it is worth looking at after
a merge.
