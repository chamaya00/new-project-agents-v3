# Building and deploying this Jekyll site on Vercel from committed repo config

## Decision this serves

What this repository needs to commit — a `Gemfile` pin and, if any, a `vercel.json`
— so that a Vercel project pointed at this repo builds the `_posts`/`_projects`/`_tags`
collections with no dashboard override, using the same build `tests/check.sh` proves
in CI. (Issue #90, child of objective #89.)

## (a) Does Vercel's build image provide Ruby by default?

**Yes, for the build step — no separate "install Ruby" step is needed.** Vercel's
build container is not a bare shell: it is a fixed image that already bundles
several language runtimes, and Ruby is one of them.

> "Vercel supports multiple runtimes... | Ruby | `3.3.x` |"
— [Build image overview](https://vercel.com/docs/builds/build-image)

That page's runtime table is about what the *build container* itself provides
(the container that runs `installCommand`/`buildCommand`), which is a different
thing from Vercel Functions' own Ruby runtime for `/api/*.rb` handlers
([Using the Ruby Runtime with Vercel Functions](https://vercel.com/docs/functions/runtimes/ruby)
— that page is scoped to compiling serverless functions and doesn't apply here;
this site ships no `/api` directory). This repo needs the build-image Ruby, not
the Functions runtime, and the build-image page is what documents that one.

The default build Ruby version can be pinned down from `3.3.x` with a `ruby`
directive in the `Gemfile` — confirmed for a prior default bump:

> "New deployments will use Ruby v3.2 by default, or if `ruby "~> 3.2.x"` is
> defined in the `Gemfile`"
— [Upgrading Ruby v2.7 to v3.2](https://vercel.com/changelog/upgrading-ruby-v2-7-to-v3-2)

**Inference** (not directly stated by either source above, but consistent with
both and with how Bundler works): since Jekyll 4.4.1 only requires Ruby `>= 2.7.0`
(see (c) below), there's no reason to pin below the build image's current
default of `3.3.x` — pinning only matters here if a *future* Vercel default bump
changes Ruby behaviour underneath the site without warning, which a `ruby "~>
3.3"` line in the Gemfile would prevent.

**What has to be added:** a `Gemfile` naming `jekyll` as a dependency. Ruby
itself needs nothing added — but without a `Gemfile`, Vercel's default Jekyll
`installCommand` (`bundle install`, see (b)) has nothing to install and the
build fails on the install step, before Jekyll is even invoked.

## (b) Recommended `vercel.json` build command and output directory

**The load-bearing finding here: this repository does not need a `vercel.json`
to be recognized as a Jekyll project at all.** Vercel's framework detector for
Jekyll looks for exactly one thing:

```javascript
// packages/frameworks/src/frameworks.ts, slug: 'jekyll'
detectors: {
  every: [
    { path: '_config.yml' },
  ],
},
settings: {
  installCommand: { value: 'bundle install' },
  buildCommand: { placeholder: '`npm run build` or `jekyll build`', value: 'jekyll build' },
  devCommand: { value: 'bundle exec jekyll serve --watch --port $PORT', placeholder: 'bundle exec jekyll serve' },
  outputDirectory: { placeholder: '`_site` or `destination` from `_config.yml`' },
},
getOutputDirName: async (dirPrefix) => {
  const config = await readConfigFile(join(dirPrefix, '_config.yml'))
  return (config && config.destination) || '_site'
},
```
— [`packages/frameworks/src/frameworks.ts`](https://github.com/vercel/vercel/blob/main/packages/frameworks/src/frameworks.ts),
Vercel's own framework-detection source, slug `jekyll`

This repo's `_config.yml` (already committed, no `destination` key set) is
enough on its own to trigger that detection, with `installCommand: bundle
install`, `buildCommand: jekyll build`, and `outputDirectory: _site` applied
with no dashboard override and no `vercel.json`. Vercel's own Jekyll example
confirms this in practice — it ships a `_config.yml`, `Gemfile`, and
`Gemfile.lock`, and **no `vercel.json` at all**:
[`vercel/vercel/examples/jekyll`](https://github.com/vercel/vercel/tree/main/examples/jekyll)
(file listing has `.gitignore`, `404.html`, `Gemfile`, `Gemfile.lock`,
`README.md`, `_config.yml`, `about.md`, `index.md`, `_posts/` — confirmed via
the GitHub Contents API — and fetching `vercel.json` at that path 404s).

**Recommendation: commit a `vercel.json` anyway, to pin the build command
explicitly rather than rely on the zero-config default.** The reason is
`tests/check.sh` parity (see below), not framework detection: Vercel's
zero-config default is the bare `jekyll build` command, which only works
because its paired `installCommand` is plain `bundle install` (no `--path
vendor/bundle`), so Bundler installs gems where `jekyll` lands directly on
`PATH`. If a future child locks that down (e.g. a vendored/deployment
install for caching, per the framework entry's own
`cachePattern: '{vendor/bin,vendor/cache,vendor/bundle}/**'`), the bare
`jekyll build` default silently stops finding the gem, and nothing in the
dashboard says why. Pin it instead:

```json
{
  "framework": "jekyll",
  "buildCommand": "bundle exec jekyll build",
  "outputDirectory": "_site"
}
```

`framework`, `buildCommand`, and `outputDirectory` are documented, first-class
`vercel.json` properties for exactly this purpose — overriding the
auto-detected default for a specific project rather than requiring a dashboard
change:

> "If you would like to override the Build Command for a specific deployment,
> add `buildCommand` to your `vercel.json` configuration." /
> "If you would like to override the Output Directory for a specific
> deployment, add `outputDirectory` to your `vercel.json` configuration." /
> "If you would like to override Framework Preset for a specific deployment,
> add `framework` to your `vercel.json` configuration."
— [Configuring a Build](https://vercel.com/docs/builds/configure-a-build)

(Full property reference: [Static Configuration with `vercel.json`](https://vercel.com/docs/project-configuration/vercel-json).)

`bundle exec jekyll build` rather than bare `jekyll build` because that's the
same invocation recommended below for `tests/check.sh` — see the note there on
why the gate and Vercel should run the identical command, not two that happen
to agree today.

## (c) Jekyll version to pin in a new `Gemfile`

**Pin `jekyll` `~> 4.4`, currently resolving to `4.4.1`** (released
2025-01-29, per [RubyGems' version API for the `jekyll` gem](https://rubygems.org/api/v1/versions/jekyll.json)),
which is the latest stable release and requires only Ruby `>= 2.7.0` per its
own gemspec (per [the `jekyll` gem page on RubyGems](https://rubygems.org/gems/jekyll)) —
well inside the `3.3.x` Vercel's build image already provides (see (a)).

Compatibility check against what this repo's build actually uses:

- **Collections with `output: true` and a custom `permalink`** (`_projects`,
  `_tags`) — core Jekyll collection features, unchanged across the 4.x line.
- **`strict_front_matter: true`** — a documented core configuration option,
  not a plugin, and not a recent addition:

  > "`strict_front_matter` — Cause a build to fail if there is a YAML syntax
  > error in a page's front matter."
  — [Jekyll Configuration Options](https://jekyllrb.com/docs/configuration/options/)

- **`relative_url` filter and `site.baseurl`** (used in `_layouts/entry.html`,
  `_layouts/tag.html`) — core Liquid filters shipped with Jekyll itself, not a
  plugin.
- **No plugins are declared in `_config.yml`** beyond the collections above, so
  the `Gemfile` needs only the `jekyll` gem itself — no `jekyll-feed`,
  `jekyll-seo-tag`, etc. (Vercel's own example `Gemfile` adds `minima` and
  `jekyll-feed` because its demo site uses that theme; this repo's hand-authored
  layouts don't, so neither belongs here — an unused dependency with no ADR
  explaining it, per the house rules' dependency-change rule.)
- **`webrick`** should still be added as a Gemfile dependency even though it's
  irrelevant to the *build* — `jekyll build` doesn't need it — because
  Vercel's zero-config `devCommand` for this framework is `bundle exec jekyll
  serve --watch --port $PORT` (see the frameworks.ts excerpt in (b)), and
  `jekyll serve` needs `webrick` on Ruby 3.x, where it stopped being part of
  the standard library. Vercel's own example Gemfile carries it for the same
  reason (confirmed by fetching
  [`examples/jekyll/Gemfile`](https://github.com/vercel/vercel/blob/main/examples/jekyll/Gemfile)
  directly). Omitting it doesn't break `bundle exec jekyll build`, only
  `vercel dev` / local `jekyll serve`, but it's cheap to include and expensive
  to discover missing.
- **`Gemfile.lock` must be committed, generated with a Linux platform entry**,
  because Vercel's build container is Linux, and a `Gemfile.lock` generated on
  a Mac or Windows dev machine can omit that platform's resolved gems:

  > "Please run `bundle lock --add-platform x86_64-linux` locally in your
  > project repository once, and commit the resulting `Gemfile.lock` file to
  > be able to deploy your project on Vercel."
  — [How to Deploy a Jekyll Site with Vercel](https://vercel.com/kb/guide/deploying-jekyll-with-vercel)

  This has to run on whatever machine authors the `Gemfile` (an engineer's
  local checkout or CI, not this research), since it needs Bundler installed
  to produce the lockfile — noting it here so #91 doesn't have to rediscover
  it.

## What `tests/check.sh` needs to run instead

Today `tests/check.sh` installs Jekyll ad hoc — `gem install jekyll
--user-install` — and never pins a version or passes `--baseurl`. Once a
`Gemfile` exists, that line stops being just unpinned; it becomes a *second,
disagreeing* build path, which is exactly the failure this repo already lived
through once with the `github-pages`-gem-vs-plain-`jekyll` mismatch (eight
failed deployments while the gate stayed green — see ADR
[0003](../decisions/0003-repository-docs-are-not-site-content.md)).

So the gate has to build the same way Vercel does:

- Install: `bundle install` (not `gem install jekyll --user-install`) — reads
  the same `Gemfile`/`Gemfile.lock` Vercel's `installCommand` reads.
- Build: `bundle exec jekyll build --destination _site` (not bare `jekyll
  build`) — `bundle exec` guarantees the `Gemfile`-pinned Jekyll version runs,
  the same guarantee `bundle install`'s default (non-vendored) install doesn't
  give you for free the way `bundle exec` does.
- No `--baseurl` flag, matching the recommended `vercel.json` above and the
  domain-root serving this objective is moving to (per #89's own note: the
  currently-empty `site.baseurl` is correct for Vercel and should not be
  "fixed").

This is a change to `tests/check.sh`, and this research issue's role has no
write access to anything under `tests/` — see the acceptance criteria's own
check wording, which names `tests/check.sh` as *where the check gets added*,
not as something this document edits. That edit — swapping the ad hoc
`gem install` for `bundle install` / `bundle exec jekyll build`, and adding
`test -f docs/research/vercel-deploy.md` — belongs to whichever child adds the
`Gemfile` (#91 per the objective's own decomposition), since the two changes
are one commit's worth of work: a `tests/check.sh` that still runs `gem
install jekyll` after a `Gemfile` lands is proving the wrong build the moment
it's written.

## Verified vs. inferred

Verified against a primary source, cited inline above: the build image's
Ruby runtime, the Jekyll framework detector and its zero-config defaults, the
absence of a `vercel.json` in Vercel's own Jekyll example, the
Linux-platform-lockfile requirement, `strict_front_matter`'s documented
behaviour, and Jekyll's latest version and its Ruby floor.

Inferred, flagged where it appears above: that pinning the build Ruby version
below the current `3.3.x` default isn't necessary, and that Vercel's Ruby
version pinning mechanism (documented for Functions, and for a past
build-default bump) also governs zero-config framework builds like this one —
plausible from both sources agreeing, but neither source states it for the
Jekyll build path specifically.

## Recommendation

Commit a `Gemfile` pinning `jekyll ~> 4.4` (plus `webrick` for `jekyll serve`)
and a `Gemfile.lock` built with `bundle lock --add-platform x86_64-linux`, and
commit a `vercel.json` with `"framework": "jekyll"`, `"buildCommand": "bundle
exec jekyll build"`, `"outputDirectory": "_site"` — even though Vercel would
detect Jekyll and pick `_site` without it, pinning the build command keeps
Vercel's build textually identical to what `tests/check.sh` will run, rather
than two commands that only happen to agree today. Change `tests/check.sh` to
`bundle install` / `bundle exec jekyll build` in the same diff that adds the
`Gemfile`, so CI stops proving a build nobody runs in production.

**Strongest argument against:** none of this has been run against a real
Vercel deployment — no role in this objective has dashboard/account access
(per #89), so every claim above is either quoted from Vercel's own
documentation and source, or inferred and marked as such, never verified end
to end by actually deploying. If Vercel's zero-config Jekyll detection or its
build image changes before #91/#92 land, this document could be citing a
default that's since moved; the version numbers and defaults above are dated
2026-09-14 and should be re-checked against the linked sources rather than
trusted indefinitely.
