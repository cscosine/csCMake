# Contributing to csCMake

How the code of csCMake is organised, and what a change involves: conventions, documentation, tests. The
[lifecycle](../advanced/lifecycle.md) and the other advanced pages explain how it works.

## Setting up

```bash
./setup.sh                    # .venv (Python 3.11+), the package in editable mode with the dev tools, pre-commit
source .venv/bin/activate
```

Windows: `./setup.ps1`. Keep the virtual environment active when committing: several pre-commit hooks run tools
installed in it.

## Repository layout

```text
csCMake.cmake                       entry point: include(csCMake) loads the modules
modules/cs<Name>.cmake              one module per subject (project, targets, sources, install, compile profiles, ...)
modules/integrations/               integrations with third-party tools and libraries (OpenMP, ...)
templates/csTemplateConfig.cmake.in the generated <namespace>Config.cmake
presets/                            the presets (see Presets internals)
src/cscmake/                        Python: preset generator and registry, dev tools (stdlib only)
tests/cscmake/                      Python tests, mirroring src/
tests/cmake/                        CMake configure tests (pytest writes a small project, configures it, reads values)
tests/smoke/                        smoke projects, built on every variant by CI
docs/                               this documentation
```

## CMake conventions

- Public commands are `cs_<name>`, private ones `_cs_<name>`; functions and macros lowercase, as are their arguments and
  local variables (cmake-lint checks the patterns of `.cmake-format.json`).
- Functions rather than macros, unless the command must set variables in the scope of the caller
  (`cs_initialize_project`, `cs_find_package`). To set a project variable from a function called by
  `cs_initialize_project`, use `_cs_set_in_project_scope` (see [project scope](../advanced/lifecycle.md#project-scope)).
- State lives in properties: global properties for the project and the build, target properties for a target; names
  `CSCMAKE_*`, internal ones `_CSCMAKE_*`. Per-namespace global properties (`CSCMAKE_<namespace>_...`) keep several
  csCMake projects of one build apart.
- **No hidden side effects**: csCMake changes only what its own targets need, or what the user asks for. Prefer a
  target property of the csCMake targets (set by `cs_finalize_target`, like the install RPATH) to a directory or
  project variable, and that to a global or cache setting; never put build behaviour in the presets, which projects
  without csCMake use too. A wider setting is applied only if the project has not set it, is documented (`:Writes:`,
  user guide), can be turned off, and has a configure test showing that the project's own value wins.
- Errors: `message(FATAL_ERROR "[<command>] <what is wrong>: <what to do>")`, naming the command the user called.
- Debug output: `cs_debug_message`, shown with `<project>_CSCMAKE_DEBUG`.
- Every module starts with `include_guard(GLOBAL)` and includes the modules it uses.
- cmake-format and cmake-lint (`.cmake-format.json`, 120 columns) format and check every file; a finding is silenced
  only with `# cmake-lint: disable=<code>` as the first line of the function, with the reason.

## A new or changed public command

1. The code, in the module of its subject.
2. Its documentation: the `#.rst:` block, and the variables and properties it sets (see
   [Contributing to the documentation](documentation.md#checklist-a-new-or-changed-public-command)).
3. Its signature in `.cmake-format.json` (`parse.additional_commands`).
4. Tests: a configure test in `tests/cmake/` for its behaviour and its errors; a smoke project when it changes what a
   build or an installed package does.
5. The user guide and tutorials that show it; `MIGRATION.md` when it replaces or renames something (tables and
   actions, no history in the other docs).

## Checks

Run on the working tree:

```bash
ruff check . && ruff format --check . && mypy --config-file=pyproject.toml src tests && lint-imports
python -m pytest                          # fast tests: Python and CMake configure tests
python -m pytest --run-all                # + smoke builds of the variants of this machine
cscmake-generate-presets --check
cmake-format --check csCMake.cmake modules/*.cmake modules/*/*.cmake && cmake-lint csCMake.cmake modules/*.cmake modules/*/*.cmake
cscmake-cmake-template format --check templates/*.cmake.in && cscmake-cmake-template lint templates/*.cmake.in
cscmake-check-docs
sphinx-build -W -n docs docs/_build/html
```

### Pre-commit hooks

`pre-commit install` (done by `setup.sh`) runs on every commit, on the staged files:

- `ruff` (lint and format) and `mypy` (strict) for Python; `import-linter` (layers of `src/cscmake`, in
  `pyproject.toml`);
- `cmake-format` and `cmake-lint` for `csCMake.cmake` and `modules/`; for `templates/*.cmake.in` through
  `cscmake-cmake-template`, which swaps the `@VAR@` placeholders for parseable stand-ins and restores them;
- `generate-csv1-presets`: regenerates the presets, and fails when that changes files (stage them and commit again);
- `check-docs`: every public command, variable and property of the CMake modules is documented
  (`cscmake-check-docs`, see [Contributing to the documentation](documentation.md#completeness-check));
- `actionlint` for the GitHub workflows;
- hygiene checks (YAML and JSON validity, whitespace, line endings, private keys, ...), and a hook that fails when
  changes are left unstaged.

`pre-commit run --all-files` runs them on every file. The documentation build is not a hook: build it before pushing a
documentation change. CI (`.github/workflows/`) runs the checks and tests
on Linux, Windows and macOS (`ci`), the smoke projects on every variant (`smoke`) and the documentation build (`docs`); a release tag runs the three, then
publishes the release (`release`, see [Releasing](releasing.md)).
