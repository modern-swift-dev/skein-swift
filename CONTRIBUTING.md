# Contributing

## Work on the website

The Astro source is in `Website/`. Install its locked dependencies with:

```sh
make site-setup
```

Build the Astro pages and all three static DocC sites, validate their internal links, then replace `docs/` with the finished output:

```sh
make site-build
```

After a successful build, preview the assembled site from `docs/`:

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
2. Run `make site-build`.
3. Review the rendered release version, date, notes, and generated DocC changes.
4. Commit the updated `docs/` directory.

GitHub Pages needs one repository setting before its first deployment. In [Settings > Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site), choose **Deploy from a branch**, then select the `main` branch and `/docs` folder. The local build does not change this remote setting.
