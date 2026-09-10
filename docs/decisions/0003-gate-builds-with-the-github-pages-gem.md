# 3. The gate builds the real site with the github-pages gem

Date: 2026-09-10

## Status

accepted

## Context

ADR 0001 turned Jekyll on and described it as "GitHub Pages' own build
machinery running on GitHub's infrastructure". That was true of where the
build runs and wrong about what runs. Pages does not execute `jekyll build`.
It executes the `github-pages` gem, which pins Jekyll 3.10.0 and loads twelve
plugins the plain gem does not have.

`tests/check.sh` built with the plain `jekyll` gem, so the gate and the
deployment disagreed about what the site even consists of. One of those
plugins, `jekyll-optional-front-matter`, promotes every `.md` in the
repository to a page and renders it through Liquid. Under plain Jekyll the
same files are static assets, copied through unparsed.

The consequence was not subtle. `docs/research/tag-pages.md` quotes Liquid in
its code samples, including an excerpt carrying an `{% if %}` with no
matching `{% endif %}` - correct as an illustration of a fragment, fatal when
executed as a template. Pages tried to execute it. Every deployment from that
merge onward failed, for eight merges across nineteen hours, while the gate
stayed green on every one of them and the site kept serving the last build
that had worked. Nothing in the repository could report the difference,
because nothing in the repository ran the build that was failing.

A structural check would not have found this. The file is valid Markdown,
valid prose, and correct documentation. It is only invalid as a Liquid
template, and only one of the two toolchains treats it as one.

## Decision

Two changes, and they address different halves of the problem.

`_config.yml` excludes `docs`, `tests`, `CLAUDE.md` and `README.md`.
Repository documentation is not site content. Excluding it fixes the
immediate break and removes the whole class: prose is free to quote Liquid
because nothing renders it. It also stops publishing ADRs and research notes
at `/docs/...` under a default theme nobody chose, which was never intended.

`tests/check.sh` builds the real site once with the `github-pages` gem, in
addition to the existing fixture builds. That build is the gate's last check,
and its failure output names what Pages would say.

The fixture builds keep the plain `jekyll` gem. They exist to exercise this
repository's own Liquid, they run about a dozen times, and their speed is
worth more than their fidelity to a plugin set they do not touch. Fidelity is
bought once, on the build that ships.

Two environment values the hosted build gets for free have to be supplied
locally: a UTF-8 locale, without which the gem aborts on the first non-ASCII
byte in the repository's prose, and `PAGES_REPO_NWO`, which
`jekyll-github-metadata` requires and cannot infer outside Actions.

## Consequences

The gate takes a dependency on `github-pages`, which installs 67 gems. CI
runs longer. That is the price of the gate testing what ships, and the
alternative has now been measured at eight silent broken deployments.

The two builds can still drift, in the direction of the fixture builds
passing something the real build would reject. The final check catches that
for the site as a whole; it does not catch it per fixture. Anything a fixture
proves is proved about plain Jekyll only.

The exclude list is now load-bearing and its failure mode is silent
publication rather than a crash. `tests/check.sh` asserts that no excluded
path and no repository Markdown appears in the built output, so shortening
the list fails the gate rather than quietly putting internal documents back
on the public site.

Pinning is GitHub's, not ours: `github-pages` resolves to whatever version is
current, which is what Pages will run. A pin here would make the gate
disagree with production again, in the same way and for a better-sounding
reason.
