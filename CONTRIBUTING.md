# Contributing

## Documentation

The [central documentation repository](https://github.com/modern-swift-dev/docs) owns Astro, the shared theme, and website/API generation. It builds from `main` daily and on manual runs. Edit page Markdown in `Documentation/Site/` and keep DocC catalogs beside the module sources. See the [docs README](https://github.com/modern-swift-dev/docs/blob/main/README.md) for local build and preview commands. Do not commit generated HTML to this repository.

`make documentation` creates `Skein-Documentation.zip` for GitHub releases.

## Publish a release and site update

The site reads the latest stable GitHub release for its version, date, notes, and installation example. Push a semantic-version tag and wait for the release workflow to publish it. The central documentation workflow picks up the release on its next scheduled or manual run.
