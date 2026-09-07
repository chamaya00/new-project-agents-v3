# GitHub Pages subpath and no-build constraints

Decision this research serves: what base path, Jekyll setting, and link style let the designer and engineer ship a static portfolio site (issue #2) that works when GitHub Pages serves it from a project-site subpath with no build step.

## Base path

This repository will publish as a **project site**, because it is not named `<user>.github.io`. GitHub's own docs state project sites are served at `https://<user>.github.io/<repository>/` — the repository name becomes a path segment after the username, not a separate domain or the root path ([About GitHub Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/about-github-pages)).

GitHub confirms the mechanics with a worked example: publishing a file at `/about/contact-us.md` from the source branch makes it available at `https://<user>.github.io/<repository>/about/contact-us.html` — the repository name is inserted as a fixed prefix in front of every path ([Creating a GitHub Pages site](https://docs.github.com/en/pages/getting-started-with-github-pages/creating-a-github-pages-site)). User/organization sites are the one case where this prefix is absent, and that only applies to a repo literally named `<user>.github.io` or `<organization>.github.io` — not this repo.

**Base path = `/<repository-name>/`, determined solely by this repo's name, fixed for as long as the repo keeps that name.** Renaming the repository changes the base path and breaks every hardcoded link, which is itself an argument for the link strategy below.

## Jekyll

GitHub Pages runs every publishing-source branch through Jekyll by default, whether or not the site was authored as a Jekyll project. Two consequences follow directly from GitHub's docs:

- Jekyll silently drops, rather than copies verbatim, any file or folder whose name starts with `_`, `.`, or `#` unless it's explicitly whitelisted via an `include` setting in a Jekyll config file ([About GitHub Pages and Jekyll](https://docs.github.com/en/pages/setting-up-a-github-pages-site-with-jekyll/about-github-pages-and-jekyll)). A static site with no build step has no Jekyll config to add that `include` to, so any such file would simply vanish from the published output.
- The documented way to opt out is an empty file named `.nojekyll` committed to the root of the publishing source: "disable the Jekyll build process by creating an empty file called `.nojekyll` in the root of your publishing source" ([Creating a GitHub Pages site](https://docs.github.com/en/pages/getting-started-with-github-pages/creating-a-github-pages-site)).

**A `.nojekyll` file at the repository root is required.** Without it, GitHub Pages applies Jekyll's default processing (including the underscore/dot/hash exclusion rule) to a site that has no build step to compensate, and file drops would be silent — no failed build, no error, just missing files at request time. This is unconditional here, not contingent on whether the site currently happens to use underscore-prefixed paths: the constraint is "static files served unmodified," and `.nojekyll` is the only documented way GitHub Pages guarantees that.

## Link strategy

Verified (browser behavior, not GitHub-specific): a URL with no leading slash resolves relative to the *current document's directory*; a URL with a leading slash resolves relative to the *server root*, discarding the current path entirely ([MDN: What is a URL](https://developer.mozilla.org/en-US/docs/Learn_web_development/Howto/Web_mechanics/What_is_a_URL)).

Applied to this project site's base path:

- **Root-absolute links** (`/style.css`, `/index.html`) resolve against the domain root `https://<user>.github.io/`, which is one level *above* the site's actual base path `https://<user>.github.io/<repository>/`. Example: a link to `/style.css` from any page 404s, because the browser requests `https://<user>.github.io/style.css` instead of `https://<user>.github.io/<repository>/style.css`. This breaks on every page, always, under a project site — it is not an edge case.
- **Relative links** (`style.css`, `./style.css`, `../images/photo.png`, `about/contact.html`) resolve against the current document's own directory, which already includes `/<repository>/`. They keep working under the base path automatically, and keep working even if the repository is renamed later (same failure mode noted in the Base path section — relative links are also the mitigation for it).
- **A base-path variable** (e.g., a Jekyll `{{ site.baseurl }}` or an equivalent templated constant) is not viable here: it requires something to evaluate the template at publish time, and the Jekyll section above establishes that Jekyll processing must be *disabled* (`.nojekyll`) precisely because there is no build step to depend on. A client-side JS variable could rewrite links after the page loads, but the initial HTML's own `<link>`/`<script>` tags — which the browser requests before any JS runs — would still need correct paths already, so it does not remove the need to get those tags right in the first place.

**Link style: relative links, with no leading slash.** Example — from `about/index.html`, link back to the home page and to a shared stylesheet as:

```html
<a href="../index.html">Home</a>
<link rel="stylesheet" href="../css/style.css">
```

not `/index.html` or `/css/style.css`.

## Recommendation

Serve the site as-is from the repo root with an empty `.nojekyll` file committed at the root, and write every internal link (HTML `href`/`src`, CSS `url()`) as a relative path with no leading slash, never a root-absolute path. The strongest argument against this: relative links are more error-prone to hand-author correctly at varying folder depths than a single templated base-path constant would be — but that tradeoff is forced by the "no build step" constraint, which rules out anything that needs templating to resolve a variable.
