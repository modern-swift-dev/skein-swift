# Contributing

## Work on the website

The Astro source is in `Website/`. Install its locked dependencies with:

```sh
make site-setup
```

Build the Astro pages and all three static DocC sites, validate their internal links, then replace `.build/site/` with the finished output:

```sh
make site-build
```

After a successful build, preview the assembled site from `.build/site/`:

```sh
make site-preview
```

Run the internal-link check again without rebuilding:

```sh
make site-check
```

The existing `make documentation` command remains separate. It creates `Skein-Documentation.zip` for GitHub releases rather than the GitHub Pages site.

## Publish a release and site update

The site build reads the latest published, stable GitHub release. Publish the GitHub release before rebuilding the site. The existing release workflow runs when you push a semantic-version tag.

1. Push the release tag and wait for GitHub to publish the release.
2. Run `make site-build` to review the rendered release version, date, notes, and generated DocC changes locally.

The [central documentation repository](https://github.com/modern-swift-dev/docs) builds and publishes this module from `main` daily and on manual runs. Generated `.build/site/` output is ignored; keep documentation sources in this repository.
