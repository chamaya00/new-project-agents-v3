# Lessons for the engineer in this repository

<!--
One line per lesson, specific to this repository, stated as a rule with the
reason attached. Hard cap of 40 non-blank lines, enforced by the guard.

Past the cap, rewrite rather than append: merge two lessons that say the same
thing, drop the one that has stopped being relevant, tighten what survives.

Delete any lesson that has graduated into a test, a lint rule, or a type.
-->

Run `bash tests/check.sh` and make each new check fail on purpose before
reporting a criterion as covered - #17 shipped a broken-front-matter check that
could never fail, because `jekyll build` logs a YAML error and still exits 0
until `strict_front_matter: true`, and #20 had to land the fix that made it a
check at all.

Assert Liquid pages against the built `_site/` output, never the template
source - ordering, empty states, and `relative_url` links are only observable
after a build, and #18's first attempt read the templates and called all six
criteria satisfied by inspection.

Build the fixture with a non-empty `baseurl` when a check is meant to prove a
link went through `relative_url` - with baseurl empty it emits a leading slash
exactly like a hand-typed path, so #19's root-absolute grep over Home's built
output could neither pass a correct build nor catch a hand-typed one until its
fixture set one.

Add the front-matter header in the same edit that gives a page its first Liquid
- Jekyll copies a page without front matter through verbatim, so the tags reach
the browser as literal text with no error and a green build, which is how #19's
Home would have shipped its Recent area unrendered.
