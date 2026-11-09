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
- csCMake is cloned next to consumer projects (`$WORKSPACE_ROOT/csCMake`); consumers include
  `presets/csv1/cs-presets-all.json` from their `CMakePresets.json`.

## Commands

```bash
./setup.sh                                          # .venv (python3.11+), pip install -e .[dev], pre-commit install
source .venv/bin/activate
python -m pytest                                    # tests (tests/ mirrors src/)
pre-commit run --all-files                          # ruff, mypy --strict, cmake-format/-lint, preset regen, ...
cscmake-generate-presets                            # regenerate presets/csv1
cscmake-generate-presets --check                    # verify presets/csv1 is in sync
```

## Rules

- `presets/csv1/*.json` is generated — never edit by hand. Change the templates or the registry, then
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
  && cscmake-cmake-template lint templates/*.cmake.in`.
- Do not run CI locally (no recreating the CI matrix / minimum-deps venvs); the user runs CI on GitHub.
