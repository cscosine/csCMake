# Releasing

A release is a tag `v<major>.<minor>.<patch>` on `main` (`v<major>.<minor>.<patch>-rc<n>` for a release candidate,
published as a pre-release). The `release` workflow tests the tag and publishes the GitHub Release with the csCMake
package and its documentation. Versions follow semantic versioning: a breaking change of the API (a command, variable,
property, preset or behaviour a project relies on, see [Compatibility](../user/compatibility.md)) raises the major
version.

## What a release contains

| Asset | Content |
|---|---|
| `csCMake-<version>.tar.gz`, `csCMake-<version>.zip` | a `csCMake/` folder with what projects use: `csCMake.cmake`, `csCMakeSetup.cmake`, `modules/`, `templates/`, the presets (`presets/csCMakeProjectSetup.json`, `csCMakeProjectSetup-common.json`, `common/`, `csv1/`, `layout/`), `README.md`, `CHANGELOG.md`, `LICENSE` |
| `csCMake-docs-<version>.zip` | the documentation of the version (HTML), in a `csCMake-docs-<version>/` folder |
| `SHA256SUMS` | the checksums of the three archives |

The release notes are the section of the version in `CHANGELOG.md`. Tests, the Python sources and the preset templates
are not in the package: they are needed only to develop csCMake. The list is `PACKAGE_CONTENT` in
`src/cscmake/devtools/release.py`.

## Steps

1. On `main`, prepare the release:
   - the version in `pyproject.toml`;
   - a section `## v<version> (<date>)` in `CHANGELOG.md` (the release candidates of a version share its section):
     what changed for the projects using csCMake (new features, fixes; a breaking change with what to change in a
     project);
2. Check the release locally:

   ```bash
   sphinx-build -W -n docs docs/_build/html
   cscmake-release --tag v<version> --docs docs/_build/html --output dist
   ```

   `cscmake-release` fails when the tag does not match the version of `pyproject.toml` or `CHANGELOG.md` has no
   section for it; `dist/` gets the assets (git-ignored).
3. Push `main`; wait for its `ci` and `smoke` runs.
4. Tag the commit and push the tag:

   ```bash
   git tag -a v<version> -m "csCMake <version>"
   git push origin v<version>
   ```

The push of the tag runs the `release` workflow (`.github/workflows/release.yml`):

1. `ci`, `smoke` and `docs` on the tag (the same workflows as for pushes, called as reusable workflows);
2. when the three pass, the `publish` job builds the documentation, runs `cscmake-release` and creates the GitHub
   Release of the tag with the assets and the release notes.

Once the release is published, fast-forward `stable` to it: `git push origin v<version>:stable`. The documentation
on GitHub Pages is the one of `stable` (the latest release), published by that push.

## Pre-releases

A tag with a pre-release part, `v<version>-rc<n>` (the version of `pyproject.toml` without the suffix), makes a GitHub
pre-release with the same assets (and leaves `stable` where it is). Use it to test a release: tag a commit of
`main`, check the release, then make the final release on the same commit.

## A failed release

When the `release` workflow fails, nothing is published. A release candidate: delete its tag
(`gh release delete v<version>-rc<n> --cleanup-tag`, or `git push origin :refs/tags/v<version>-rc<n>`), fix on `main`,
tag the next candidate. A final tag cannot be moved or deleted (organisation rules): fix on `main` and release the next
patch version.

Once a release is published, its tag never moves: a fix is a new patch version.
