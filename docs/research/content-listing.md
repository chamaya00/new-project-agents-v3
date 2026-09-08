# Content-file-driven listing mechanism for projects and posts

Research for issue #11, part of the portfolio site objective (#3). Decision
this research has to serve: **whether "add one content file, and nothing
else, and it appears in its section's listing and on Home" is achievable on
this repo's current stack, and if not, the smallest mechanism that makes it
achievable** — so the designer and engineer children of #3 know what they're
building against.

## Can this be done as-is?

**No.** CLAUDE.md's Stack section is explicit: static HTML5 + CSS3, no
JavaScript, no build step, no package manager, and the current site (#2) is
hand-authored with no generation step. Under that stack, exactly two things
can produce a listing page's HTML: a human typing it, or nothing. There is no
third actor — no script runs on a schedule or a push, no code executes in the
visitor's browser, and GitHub Pages' branch-deployment source serves whatever
is committed, unmodified, once Jekyll processing is disabled the way this
repo has disabled it (`.nojekyll`, per `docs/research/pages-subpath.md`).

So "add one file, nothing else" cannot hold today: a new project or post file
sits in the repository, but the listing page and Home's recent-entries
section are separate files that nobody has touched, and they render exactly
as they did before the new file arrived. Making the requirement true needs
something that notices a new content file and produces or updates the
listing from it, without a human doing that second edit by hand. That is a
change to the stack, not a way of working within it — the question is which
change is smallest.

## Options considered

Constraints every option is checked against: no backend (#2), no accounts
(#2), GitHub Pages static hosting, the project-site subpath base path and
relative-link rule from `docs/research/pages-subpath.md`, and the house rule
that no agent — researcher, designer, or engineer — may edit anything under
`.github/workflows/`.

### Option A: Enable Jekyll (GitHub Pages' built-in branch-deployment build)

GitHub Pages' branch-deployment source — the one this repo already uses,
since there is no custom deploy workflow under `.github/workflows/` — runs
every push through Jekyll by default; `.nojekyll` is what currently *opts
out* of that
([Configuring a publishing source for your GitHub Pages site](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site)).
Removing `.nojekyll` and adding a minimal `_config.yml` turns that build back
on. Jekyll's collections feature groups content files under a name (e.g. a
`projects` collection is any file under `_projects/`, declared in
`_config.yml`; `_posts/` is a built-in collection, no declaration needed) and
a template iterates the collection to render a listing —
[Jekyll: Collections](https://jekyllrb.com/docs/collections/). Front matter
is optional per file; a file with no front matter is left as a static file
and not touched by the collection/listing logic (same doc).

- **What it does**: adding a file under `_projects/` or `_posts/` is the
  entire content-author action. GitHub's own infrastructure — not a workflow
  file this repo owns — regenerates the listing and any Home partial on the
  next push, because that's what branch-deployment-with-Jekyll always does.
- **What it costs**: a `_config.yml`, a collection declaration, at least one
  Liquid layout/include for the listing markup, and front matter (however
  minimal) on every content file going forward. Jekyll is a real static-site
  generator/templating framework, not a script — this is the biggest
  conceptual jump of the three options, even though it needs no new
  infrastructure this repo maintains.
- **What it rules out later**: hand-typing the listing pages, since they'd
  now be generated and immediately fall out of sync with the collection.
  Also, per `pages-subpath.md`, a Jekyll base-path variable
  (`site.baseurl`/`relative_url`) was rejected there as "not viable" only
  *because* Jekyll processing was assumed off; if this option is taken, that
  conclusion flips, and generated pages should use `relative_url` rather
  than hand-typed relative paths, since collection output nests at a path
  depth (e.g. `/projects/<slug>/`) that varies per entry.
- **What would have to be true to be right**: that the project accepts
  Jekyll (a framework, contradicting today's "no framework" implication) in
  exchange for needing zero workflow-file edits and zero committed generated
  output — both of which the next two options cannot avoid.
- **Local preview**: `python3 -m http.server` (CLAUDE.md's Dev command) would
  no longer show the listing/Home pages correctly without also running
  Jekyll locally, which needs Ruby/Bundler — a new local dependency, though
  not a new *hosted* one.

### Option B: Custom GitHub Actions build-and-deploy workflow with a generator script

Pages also supports a source that runs an arbitrary GitHub Actions workflow
to build the site before deploying it, "If you want to use a build process
other than Jekyll" (same GitHub doc as Option A). A small script (shell or
Python — both need no package manager, keeping that part of CLAUDE.md's
Stack true) would scan a content directory, read a lightweight per-file
header, and emit the listing/recent-entries HTML as the deploy artifact.

- **What it does**: same content-author experience as Option A (drop a file,
  nothing else), but the generation logic is a script this repo owns instead
  of Jekyll's built-in behavior.
- **What it costs**: a new workflow file to run the script and call
  `actions/deploy-pages`, *and* switching the repo's Pages publishing source
  from "Deploy from a branch" to "GitHub Actions" — a repository-settings
  change, not just a commit.
- **What it rules out / who can build it**: this is the option's
  disqualifying cost. Every workflow-file edit is off-limits to every agent
  in this factory (house rules; also this run's own hard limits). Whichever
  child issue implements Option B cannot be closed by the designer or
  engineer agents alone — a human has to hand-author or approve the workflow
  file and flip the Pages source setting. Option A and Option C both avoid
  this entirely.
- **What would have to be true to be right**: that avoiding a Jekyll/Liquid
  dependency is worth introducing a change that no downstream agent in this
  issue's own dependency chain (#3's designer and engineer children) is able
  to finish unassisted.

### Option C: Client-side fetch (GitHub REST API or a hand-maintained manifest)

A page's JS could fetch a listing of content files at load time, either by
querying GitHub's contents API for a directory
(`api.github.com/repos/<owner>/<repo>/contents/<dir>`) or by fetching a
manifest file.

- **What it does**: needs no workflow file and no Pages-source change —
  ships entirely as static HTML/JS/CSS, same publishing path as today.
- **What it costs**: reintroduces JavaScript, which CLAUDE.md's Stack
  currently rules out; a manifest that a human edits by hand fails the
  requirement outright (that's the second edit the issue rules out), so the
  only version of this option that satisfies "one file, nothing else" is the
  live-directory-listing variant against GitHub's API.
- **What it rules out**: working with JavaScript disabled — the listing and
  Home's recent entries would be empty, with no static fallback, for any
  visitor without JS, and for search-engine crawlers that don't execute it.
  It also puts a hard ceiling on the mechanism: unauthenticated requests to
  GitHub's REST API are capped at 60 requests per hour *per IP address*, not
  per visitor
  ([Rate limits for the REST API](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api)),
  which a shared office/school/campus NAT exhausts easily on a public
  portfolio site. Per-file metadata (date, title) isn't in a directory
  listing response either, so ordering "recent" entries would need a second
  request per file, making the ceiling worse.
- **What would have to be true to be right**: that occasional empty listings
  under real-world traffic and a permanently no-JS-hostile listing page are
  acceptable — neither holds for a public site with an explicit "readable
  without a build step" and (today) "no JavaScript" stance.

## Content file format

Whichever mechanism is chosen, it has to tell a project from a post and
order posts/recents by date. Recommended minimal convention (shown for
Option A; B and C would carry the same fields, just parsed by a script or by
JS instead of Jekyll):

- **Location distinguishes type**: `_projects/<slug>.html` for projects,
  `_posts/YYYY-MM-DD-<slug>.html` for posts. Posts use Jekyll's own
  filename-encoded-date convention, which supplies the sort key without a
  front-matter field; projects (which don't have Jekyll's built-in
  date-in-filename behavior) carry the date in front matter instead.
- **Files stay HTML**, not Markdown: Jekyll processes any file that has front
  matter, HTML included, and only converts Markdown-flavored source when the
  file itself is Markdown. Keeping content files as hand-authored HTML5
  bodies with a front-matter header on top is the smallest change from the
  current authoring style — Markdown is not required by any option above.
- **Required front matter**: `title` (string) and, for projects only, `date`
  (`YYYY-MM-DD`, since the filename doesn't supply it there). `layout`
  (which template wraps the body) is required by Jekyll's own mechanics once
  Option A is in play.
- **Optional but expected**: a one-line `summary` or `excerpt` field, since
  the listing/recent-entries card needs text shorter than the full body and
  nothing today derives an excerpt automatically.

## Consequences

- **CLAUDE.md's Stack section** would need to drop "no build step" (Jekyll
  is GitHub's own build, not one this repo runs, but it is a build) and
  qualify "no JavaScript, no framework" — Option A adds Liquid templates and
  YAML front matter as a real, if hosted, dependency; Option C adds
  JavaScript outright. Only "no package manager" survives every option
  intact (Jekyll's plugin set on GitHub Pages needs no Gemfile; A/B's
  scripts need no npm/pip install step).
- **An ADR is required**: Option A (recommended below) adds a dependency
  (Jekyll) and a data shape (the front-matter schema above) per CLAUDE.md's
  own standing rule. That's written up now as
  [`docs/decisions/0001-enable-jekyll-for-content-listings.md`](../decisions/0001-enable-jekyll-for-content-listings.md),
  status `proposed` — it moves to `accepted` in the same diff that actually
  commits `_config.yml` and removes `.nojekyll`, since the dependency isn't
  being added by this research diff, only recommended. Option B or C, if
  chosen instead, would need their own ADR for the same reason (a bespoke
  script, or a runtime dependency on GitHub's API, is still a dependency).
- **Option B specifically cannot be finished by this factory's agents**:
  implementing it requires a `.github/workflows/` edit and a Pages
  publishing-source change, both outside every role's reach per the house
  rules and this run's own hard limits. A child issue that ends up needing
  Option B should say so and stop, per that same rule, rather than an
  engineer attempting a workaround.

## Recommendation

**Option A — enable Jekyll via the branch-deployment source this repo
already uses**, with `_projects/` and `_posts/` collections and the front
matter above. It's the only option that satisfies "one file, nothing else"
without also requiring a workflow-file edit (Option B) or breaking for
visitors without JavaScript and for shared-IP traffic (Option C).

The strongest argument against it: it reverses `pages-subpath.md`'s
`.nojekyll` decision and trades a small, static, fully-inspectable site for
one that depends on a real templating framework's build semantics running on
infrastructure this repo doesn't control or preview locally without
installing Ruby/Bundler — a heavier dependency than either alternative's
literal file count suggests.
