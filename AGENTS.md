# AGENTS.md

<!-- cs-template:begin (this block is owned by cs-project-template: do not edit; the rest of the file is the project's) -->
Entry point for coding agents (and people) working in csCMake. The rules of every cscosine repository are
in [.claude/cscosine-rules.md](.claude/cscosine-rules.md): read them first. What is specific to this repository
follows this block.

Commands:

- Setup: `./setup.sh` (Windows: `.\setup.ps1`), then `source .venv/bin/activate` (the pre-commit hooks run in it).
- Checks: `pre-commit run --all-files`; tests: `pytest` (`--run-all`: every test, as CI).

Who owns which file (template: [cs-project-template](https://github.com/cscosine/cs-project-template); change it
there, then `copier update --defaults`; never edit its parts here):

- Template: `setup.sh`, `setup.ps1`, `open-code.sh`, `open-code.ps1`, `conftest.py`, `.clang-format`,
  `.vscode/`, `.github/` (the workflows: `checks.yml`, `ci.yml` only), `CLAUDE.md`, `.claude/cscosine-rules.md`, `.claude/settings.json`,
  `LICENSE`.
- Template and project: `pyproject.toml` (template tables between the `template` markers), `.pre-commit-config.yaml` (project hooks
  between the `project: begin` / `project: end` markers), `.gitignore`, `.gitattributes` (project lines after
  `--- project ---`), `README.md` and this file (the
  `cs-template` block).
- The project: everything else.
<!-- cs-template:end -->

## csCMake

What follows is csCMake's own guidance (commands, generated files, conventions, process).

- **Repository map and recipes**: [.agents/skills/cscmake-development/SKILL.md](.agents/skills/cscmake-development/SKILL.md).
- **The skill for the projects using csCMake**: [agent-plugin/skills/cscmake-usage/SKILL.md](agent-plugin/skills/cscmake-usage/SKILL.md),
  the Claude Code plugin `cscmake` of the `cscosine` marketplace (`cscosine/.github`). A change of a public command,
  preset name or layout updates it in the same PR; its `version` in `agent-plugin/.claude-plugin/plugin.json` follows
  the csCMake version. Test it with `claude --plugin-dir agent-plugin`.
- **Open work**: [TODO.md](TODO.md), by area; what changed for the projects: [CHANGELOG.md](CHANGELOG.md).
- **How csCMake works**: the documentation in `docs/`: user guide, advanced pages (lifecycle, runtime dependencies,
  installed packages, presets internals), and the reference in the `#.rst:` blocks of `csCMake.cmake` and `modules/`.
- **Contributing**: [code](docs/contributing/code.md) and [documentation](docs/contributing/documentation.md).

## What this repo is

- **CMake utility library**: `csCMake.cmake` + `modules/cs*.cmake` (public `cs_*`, private `_cs_*`; integrations with
  third-party tools in `modules/integrations/`),
  `templates/csTemplateConfig.cmake.in` for the installed `<Ns>Config.cmake`.
- **Preset generator** (Python ≥ 3.11, stdlib only): `src/cscmake/presets/registry.py` defines the
  variant matrix, `src/cscmake/presets/render.py` renders `@{var}` templates,
  `src/cscmake/presets/generate.py` (`cscmake-generate-presets`) writes `presets/csv1/` from
  `presets/template/`.
- csCMake is cloned next to consumer projects (`$CSCMAKE_WORKSPACE_ROOT/csCMake`); consumers include
  `presets/csv1/cs-presets-all.json` from their `CMakePresets.json`.

## Commands

```bash
./setup.sh                                          # .venv (python3.11+), pip install -e .[dev], pre-commit install
source .venv/bin/activate
python -m pytest                                    # fast tests (tests/cscmake mirrors src/, tests/cmake: CMake configure tests)
python -m pytest --run=smoke                        # + CMake smoke builds (host variants); --run-all: as CI (no smoke)
python tests/smoke/run_smoke.py --variant <id>      # smoke test one preset variant
pre-commit run --all-files                          # ruff, mypy --strict, gersemi, cscmake-lint, preset regen, ...
cscmake-generate-presets                            # regenerate presets/csv1
cscmake-generate-presets --check                    # verify presets/csv1 is in sync
sphinx-build -W -n docs docs/_build/html            # documentation (reference from the #.rst: blocks); CI: docs.yml
cscmake-update-cmake-inventory                      # refresh docs/_inventories (after changing CMAKE_DOCS_VERSION)
cscmake-check-docs                                  # every public command, variable, property documented (pre-commit)
cscmake-release --tag v<x.y.z> --docs docs/_build/html --output dist  # release assets (docs/contributing/releasing.md)
```

## Rules

- `presets/csv1/*.json`, `presets/csCMakeProjectSetup*.json` and `presets/layout/*.json` are generated — never edit by
  hand (the layouts are the `LAYOUTS` table of `src/cscmake/presets/generate.py`). Change the templates or the registry, then
  regenerate and commit the output together. The `generate-csv1-presets` pre-commit hook enforces this.
- Registry enum values and short forms end up in preset names/ids used by downstream projects:
  changing them renames presets. Generated output must stay byte-identical unless a rename is intended.
- No runtime dependencies: the package and the preset generator use the standard library only.
- New dev dependency in `pyproject.toml` → pin the minimum in `constraints-minimum.txt` in the same commit.
- Python: mypy strict, ruff (line length 120, double quotes), type hints everywhere.
- CMake: gersemi formats (`.gersemirc`: line width 120, indent 2; the `cs_*` signatures in cs-pre-commit-hooks),
  `cscmake-lint` (also from cs-pre-commit-hooks) checks: lowercase names, a comment block directly above every
  `function`/`macro`, complexity limits, line length. Both handle the `@VAR@` templates. Silence a finding only with
  `# cscmake-lint: disable=<code>` as first line of the function body, plus a reason.
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
  * gersemi keeps comments as written: wrap `#.rst:` blocks by hand at 120 columns, indent directive content by 2
    spaces;
  * private `_cs_*`: plain `#` comment, one-line summary (+ details), `Reads:` / `Writes:` when it touches state;
  * a module without public commands or documented state (`csInternal`): plain `#` header, no page;
  * a new documented module → `docs/reference/<module>.rst` and an entry in the toctree of `docs/index.md`;
  * `sphinx-build -W -n docs <out>` must pass: every reference resolves (CMake's own commands and variables through
    `docs/_inventories/cmake-<version>.inv`, the local copy of the cmake.org inventory: never edit it; a new minimum
    CMake version → `CMAKE_DOCS_VERSION` in `src/cscmake/devtools/cmake_inventory.py`, then
    `cscmake-update-cmake-inventory`).
- New or changed public `cs_*` command → its signature in cs-pre-commit-hooks (`src/gersemi_cscmake.py`, released there
  first, then the dev dependency and hook `rev:` here moved to it),
  so gersemi lays out its keyword arguments. Names: functions/macros `[0-9a-z_]+`, arguments and locals
  `[a-z][a-z0-9_]*` (`cscmake-lint`).
- Comments are not reflowed: wrap them by hand at 120 columns; an empty `#` line between paragraphs and before bullet
  lists (`* item`).
- **No hidden side effects.** csCMake changes only what its own targets need, or what the user asks for. In order of
  preference: a target property of the csCMake targets (e.g. set by `cs_add_library`), a directory / project
  variable, a global or cache setting. The presets are also used by projects without csCMake (third-party forks,
  OpenCV): they carry the toolchain, generator, folders and search paths only, never build behaviour (an
  `INSTALL_RPATH` in the host presets would have silently replaced OpenCV's own default). Anything wider: only if not
  already set by the project, documented (`:Writes:`, user guide), with a way to turn it off, and a configure test
  showing that a project's own value wins.
- Docs, code comments, README and test docstrings describe the current behaviour only (no "was", "no longer",
  "not FORCE", "(was X)"). History goes in the commit messages; `CHANGELOG.md` says what changed for the projects (a
  breaking change: with what to change in a project).
- The `no-unstaged-changes` pre-commit hook fails if anything is unstaged: stage before running hooks.
- Hooks need the dev venv active (`generate-csv1-presets` and `import-linter` run tools installed in it).

## Process

- One commit (at least) per step; never squash steps.
- Stop after each step for human review; update `TODO.md` (remove what is done, add what is found) and
  `CHANGELOG.md` (what changes for the projects).
- Commit and push only when the user asks.
- **Never stage changes** (`git add`, `git rm`, `git mv`, `git reset` that alters the index): leave every
  change unstaged/untracked so the user can review it in the working tree. The user stages.
- Because of that, do not verify with `pre-commit run` (it stashes unstaged changes and checks the index;
  `no-unstaged-changes` fails anyway). Run the tools directly on the working tree instead:
  `ruff check . && ruff format --check . && mypy --config-file=pyproject.toml src tests && lint-imports
  && python -m pytest && cscmake-generate-presets --check && gersemi --check csCMake.cmake modules templates tests/smoke
  && cscmake-lint csCMake.cmake modules/*.cmake modules/*/*.cmake templates/*.cmake.in && cscmake-check-docs && sphinx-build -W -n -q docs docs/_build/html`.
- Do not run CI locally (no recreating the CI matrix / minimum-deps venvs); the user runs CI on GitHub.
