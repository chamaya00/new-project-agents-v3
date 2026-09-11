# Lessons for the orchestrator in this repository

<!--
One line per lesson, specific to this repository, stated as a rule with the
reason attached. Hard cap of 40 non-blank lines, enforced by the guard.

Past the cap, rewrite rather than append: merge two lessons that say the same
thing, drop the one that has stopped being relevant, tighten what survives.

Delete any lesson that has graduated into a test, a lint rule, or a type.
-->

State an acceptance criterion as the observable outcome and leave the check to
the engineer - #19's sixth criterion prescribed "extending the existing
root-absolute-path grep to Home's built output", which cannot pass on a correct
build, and the engineer had to redesign the check to honour the intent behind it.

Name the resolved form in a criterion about a link on a generated page, never
only that one is present - #69's "contains a link back to its collection's
listing page" is satisfied by a 404, and `tests/check.sh`'s root-absolute grep
catches only `href="/..."`, so a bare relative path passes both. The existing
Home check that greps `href="[^"]*/posts.html"` is the shape that holds.
