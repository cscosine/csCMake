# CLAUDE.md

Guidance for coding agents working in this repository. Detailed repo map and recipes:
[.agents/skills/cscmake-development/SKILL.md](.agents/skills/cscmake-development/SKILL.md).
Roadmap, open issues and session log: [PLAN.md](PLAN.md) — read it first.

## What this repo is

- **CMake utility library**: `csCMake.cmake` + `utils/cs*.cmake` (public `cs_*`, private `_cs_*`),
  `templates/csTemplateConfig.cmake.in` for the installed `<Ns>Config.cmake`.
- **Preset generator** (Python ≥ 3.11, stdlib only): `src/cscmake/presets/registry.py` defines the
  variant matrix, `src/cscmake/utils/generate_cs_preset_variants.py` renders `@{var}` templates,
  `src/cscmake/presets/generate.py` (`cscmake-generate-presets`) writes `presets/csv1/` from
  `presets/template/`.
- csCMake is cloned next to consumer projects (`$CSCMAKE_WORKSPACE_ROOT/csCMake`); consumers include
  `presets/csv1/cs-presets-all.json` from their `CMakePresets.json`.

## Commands

```bash
./setup.sh                                          # .venv (python3.11+), pip install -e .[dev], pre-commit install
source .venv/bin/activate
python -m pytest                                    # fast tests (tests/cscmake mirrors src/, tests/cmake: CMake configure tests)
python -m pytest --run-all                          # + slow CMake smoke builds (host variants)
python tests/smoke/run_smoke.py --variant <id>      # smoke test one preset variant
pre-commit run --all-files                          # ruff, mypy --strict, cmake-format/-lint, preset regen, ...
cscmake-generate-presets                            # regenerate presets/csv1
cscmake-generate-presets --check                    # verify presets/csv1 is in sync
sphinx-build -W -n docs docs/_build/html            # documentation (reference from the #.rst: blocks); CI: docs.yml
cscmake-update-cmake-inventory                      # refresh docs/_inventories (after changing CMAKE_DOCS_VERSION)
```

## Rules

- `presets/csv1/*.json`, `presets/csCMakeProjectSetup.json` and `presets/layout/*.json` are generated — never edit by
  hand (the layouts are the `LAYOUTS` table of `src/cscmake/presets/generate.py`). Change the templates or the registry, then
  regenerate and commit the output together. The `generate-csv1-presets` pre-commit hook enforces this.
- Registry enum values and short forms end up in preset names/ids used by downstream projects:
  changing them renames presets. Generated output must stay byte-identical unless a rename is intended.
- No runtime dependencies: the package and the preset generator use the standard library only.
- New dev dependency in `pyproject.toml` → pin the minimum in `constraints-minimum.txt` in the same commit.
- Python: mypy strict, ruff (line length 120, double quotes), type hints everywhere.
- CMake: cmake-format + cmake-lint with `.cmake-format.json` (line width 120). Every `function`/`macro` needs a
  docstring comment block directly above it (C0111). Silence a finding only with a scoped
  `# cmake-lint: disable=<code>` as first line of the function body, plus a reason. Do not mix a file-level
  pragma with function-level ones in the same file: cmakelang 0.6.13 then ignores the function-level ones.
- Docs of the CMake modules (full guide: `docs/contributing/documentation.md`): reStructuredText in `#.rst:` comment
  blocks (CMake's own format), extracted by Sphinx (`sphinxcontrib-moderncmakedomain`, `docs/reference/<module>.rst` =
  `.. cmake-module::`):
  * module: a `#.rst:` block before `include_guard`: title (the module name, `---` underline), summary, a `Commands`
    section (`^^^` underline);
  * public `cs_*`: a `#.rst:` block right above the function: `.. command:: cs_x`, summary, `.. code-block:: cmake`
    signature, details, the arguments as a definition list (``` ``KEYWORD`` ``` then the indented meaning),
    `:Reads:` / `:Writes:` fields with the roles `:variable:`, `:prop_tgt:`, `:prop_gbl:`, `:envvar:` (wrapped lines
    of a field indented 2 more spaces);
  * the variables and properties a module writes: `.. variable::` / `.. prop_tgt::` / `.. prop_gbl::` in a
    `#.rst:` block of that module (section `Variables`, `Target properties`, `Global properties`);
  * cmake-format keeps `#.rst:` blocks as written (`literal_comment_pattern`): wrap them by hand at 120 columns, indent
    directive content by 2 spaces;
  * private `_cs_*`: plain `#` comment, one-line summary (+ details), `Reads:` / `Writes:` when it touches state;
  * a module without public commands or documented state (`csListUtils`, `csMSVCUtils`): plain `#` header, no page;
  * a new documented module → `docs/reference/<module>.rst` and an entry in the toctree of `docs/index.md`;
  * `sphinx-build -W -n docs <out>` must pass: every reference resolves (CMake's own commands and variables through
    `docs/_inventories/cmake-<version>.inv`, the local copy of the cmake.org inventory: never edit it; a new minimum
    CMake version → `CMAKE_DOCS_VERSION` in `src/cscmake/devtools/cmake_inventory.py`, then
    `cscmake-update-cmake-inventory`).
- New or changed public `cs_*` command → update its signature in `.cmake-format.json` (`parse.additional_commands`),
  so cmake-format lays out its keyword arguments. Names: functions/macros `[0-9a-z_]+$`, arguments and locals
  `[a-z][a-z0-9_]+$` (cmake-lint patterns, anchored with `$`).
- Plain CMake comments are reflowed by cmake-format: consecutive comment lines become one paragraph. Keep structure with
  an empty `#` line between paragraphs and bullet lists (`* item`, preceded by an empty `#` line).
- Docs, code comments, README and test docstrings describe the current behaviour only (no "was", "no longer",
  "not FORCE", "(was X)"). History goes in the PLAN.md CHANGELOG and commit messages; `MIGRATION.md` maps old → new as
  tables and actions.
- `*.cmake.in` templates: use `cscmake-cmake-template format|lint` (plain cmake-format cannot parse `@VAR@`).
- The `no-unstaged-changes` pre-commit hook fails if anything is unstaged: stage before running hooks.
- Hooks need the dev venv active (`generate-csv1-presets` and `import-linter` run tools installed in it).

## Process (from PLAN.md governance)

- One commit (at least) per phase; never squash phases. Do not push.
- Stop after each phase for human review; update `PLAN_STATE` and the CHANGELOG in PLAN.md.
- Commit only when the user asks.
- **Never stage changes** (`git add`, `git rm`, `git mv`, `git reset` that alters the index): leave every
  change unstaged/untracked so the user can review it in the working tree. The user stages.
- Because of that, do not verify with `pre-commit run` (it stashes unstaged changes and checks the index;
  `no-unstaged-changes` fails anyway). Run the tools directly on the working tree instead:
  `ruff check . && ruff format --check . && mypy --config-file=pyproject.toml src tests && lint-imports
  && python -m pytest && cscmake-generate-presets --check && cmake-format --check csCMake.cmake utils/*.cmake
  && cmake-lint csCMake.cmake utils/*.cmake && cscmake-cmake-template format --check templates/*.cmake.in
  && cscmake-cmake-template lint templates/*.cmake.in && sphinx-build -W -n -q docs docs/_build/html`.
- Do not run CI locally (no recreating the CI matrix / minimum-deps venvs); the user runs CI on GitHub.
