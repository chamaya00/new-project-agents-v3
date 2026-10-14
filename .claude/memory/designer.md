# Lessons for the designer in this repository

<!--
One line per lesson, specific to this repository, stated as a rule with the
reason attached. Hard cap of 40 non-blank lines, enforced by the guard.

Past the cap, rewrite rather than append: merge two lessons that say the same
thing, drop the one that has stopped being relevant, tighten what survives.

Delete any lesson that has graduated into a test, a lint rule, or a type.
-->

Say which side of ADR 0001's line a page falls on before citing it for a link -
the ADR splits generated pages, which nest at variable depth and need
`relative_url`, from hand-authored ones, which keep bare relative paths. #67's
entry-page spec cited ADR 0001 while telling the engineer to write
`href="posts.html"` on a generated page, where it resolves inside the entry's
own directory and 404s.
