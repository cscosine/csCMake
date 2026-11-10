# Releasing

A release is a tag `v<major>.<minor>.<patch>` on `main`. The `release` workflow tests the tag and publishes the GitHub
Release with the csCMake package and its documentation. Versions follow semantic versioning: a breaking change of the
API (a command, variable, property, preset or behaviour a project relies on) raises the minor version while the major
is 0, the major version afterwards.

## What a release contains

| Asset | Content |
|---|---|
| `csCMake-<version>.tar.gz`, `csCMake-<version>.zip` | a `csCMake/` folder with what projects use: `csCMake.cmake`, `modules/`, `templates/`, the presets (`presets/csCMakeProjectSetup.json`, `common/`, `csv1/`, `layout/`), `.gersemirc` and `gersemi/` (the formatter configuration and the `cs_*` signatures), `README.md`, `MIGRATION.md`, `CHANGELOG.md`, `LICENSE` |
| `csCMake-docs-<version>.zip` | the documentation of the version (HTML), in a `csCMake-docs-<version>/` folder |
| `SHA256SUMS` | the checksums of the three archives |

The release notes are the section of the version in `CHANGELOG.md`. Tests, the Python sources and the preset templates
are not in the package: they are needed only to develop csCMake. The list is `PACKAGE_CONTENT` in
`src/cscmake/devtools/release.py`.

## Steps

1. On `dev`, prepare the release:
   - the version in `pyproject.toml`;
   - a section `## v<version> (<date>)` in `CHANGELOG.md`: what changed for the projects using csCMake (breaking
     changes, new features, fixes);
   - for a breaking change, `MIGRATION.md`: the old and the new names and behaviours, and the actions.
2. Check the release locally:

   ```bash
   sphinx-build -W -n docs docs/_build/html
   cscmake-release --tag v<version> --docs docs/_build/html --output dist
   ```

   `cscmake-release` fails when the tag does not match the version of `pyproject.toml` or `CHANGELOG.md` has no
   section for it; `dist/` gets the assets (git-ignored).
3. Merge `dev` into `main` (`git merge --no-ff dev`) and push `main`; wait for its `ci`, `smoke` and `docs` runs.
4. Tag `main` and push the tag:

   ```bash
   git tag -a v<version> -m "csCMake <version>"
   git push origin v<version>
   ```

The push of the tag runs the `release` workflow (`.github/workflows/release.yml`):

1. `ci`, `smoke` and `docs` on the tag (the same workflows as for pushes, called as reusable workflows);
2. when the three pass, the `publish` job builds the documentation, runs `cscmake-release` and creates the GitHub
   Release of the tag with the assets and the release notes.

The documentation on GitHub Pages is the one of `main`, published by the push of step 3.

## Pre-releases

A tag with a pre-release part, `v<version>-rc<n>` (the version of `pyproject.toml` without the suffix), makes a GitHub
pre-release with the same assets. Use it to test a release before tagging `main`: tag `dev`, check the release, then
make the final release from `main`.

## A failed release

When the `release` workflow fails, nothing is published. Fix the problem on `dev`, merge it into `main` again, then
move the tag:

```bash
git tag -d v<version> && git push origin :refs/tags/v<version>
git tag -a v<version> -m "csCMake <version>" && git push origin v<version>
```

Once a release is published, its tag never moves: a fix is a new patch version.
