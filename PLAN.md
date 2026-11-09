# csCMake — Plan, Issues & TODO

Single source of truth for project maturity. Update `PLAN_STATE` and the checkboxes at the end of each work session.

## Vision & status

- csCMake wraps CMake for common project setup: targets, deps, installs, compile-option defaults, CMake presets.
- `main` is tagged `v0.1.0`. Active development is on `dev` (checked out here).
- Goal: full maturity — working setup/config, tests, CI, docs (humans + agents), preset generation independent of csOrchestrator.

## Roadmap (phases)

- [x] **Phase 0 — Project plumbing** (port from csorchestrator: `.vscode/`, `pyproject.toml`, `conftest.py`, `constraints-minimum.txt`, `.pre-commit-config.yaml`, `setup.sh`/`setup.ps1`, CI workflow, agent skill)
- [x] **Phase 1 — Decouple preset generation from csOrchestrator** (built-in variant registry in `src/cscmake/presets/registry.py`, generator `src/cscmake/presets/generate.py` / `cscmake-generate-presets` with `--check`, pre-commit regen hook). `--variants-source csorchestrator` dropped: csOrchestrator should import the registry from cscmake instead.
- [ ] **Phase 2 — Tests** (Python unit tests + CMake fixture project via subprocess + preset JSON walker test)
- [ ] **Phase 3 — Docs** (README.md, AGENTS.md, docs/architecture.md, docs/utils-api.md, docs/presets.md)
- [ ] **Phase 4 — CMake code hardening** (see Issues below)
- [ ] **Phase 5 — Release** (version bump, tag, CHANGELOG entries)

## Governance

- **Each phase is at least one commit.** Do not squash multiple phases into a single commit.
- **Human review required** at the end of every phase (or sub-phase). Agents must not push or mark a phase done without the reviewer signing off on PLAN_STATE.
- **Agents must not work unattended.** After each commit, stop and wait for review before starting the next phase.

## Issues & findings

### Setup / config / settings
- [x] `setup.sh` / `setup.ps1` reference `../../../csOrchestrator` (wrong case on Linux, hard dep on unpublished package) → removed (Phase 1).
- [x] `pyproject.toml` pytest section empty → `testpaths`, `pythonpath` added (Phase 1).
- [x] No `constraints-minimum.txt` → added (Phase 0); `import-linter` now also in `pyproject.toml` dev deps.
- [x] ~~No `conftest.py`~~ → dropped: no slow/git tests yet; add with markers when needed (Phase 2).
- [x] `.pre-commit-config.yaml` dead/commented hooks removed; actionlint, import-linter and preset regen hooks enabled.
- [x] Phase 0 gaps (CHANGELOG claimed but not in `c399f7f`) completed on 2026-11-09, see CHANGELOG.
- [x] CI presets-sync gate: covered by the `generate-csv1-presets` hook in `pre-commit run --all-files` (fails if regeneration changes files) and `tests/cscmake/presets/test_registry.py`; no separate step.
- [x] `.vscode/settings.json` enriched (pylance strict, ruff format-on-save, mypy strict, extraPaths).
- [x] `.vscode/launch.json` debugpy configs for pytest.
- [x] `.vscode/extensions.json` pylance/ruff/mypy added.
- [x] CI `.github/workflows/ci.yml` (OS × Python matrix + minimum-deps). CMake setup deferred to Phase 2 (fixture tests).
- [x] Agent-facing docs: `.agents/skills/cscmake-development/SKILL.md` + `CLAUDE.md`. `AGENTS.md` → Phase 3.
- [x] `import-linter[ui]>=2.11` (first release with the `ui` extra, for the `import-linter explore` task); `constraints-minimum.txt` pins `2.11`.
- [x] `cmake-lint` enabled on `csCMake.cmake` + `utils/*.cmake` and on templates (see 2026-11-09 CMake format/lint entry).

### CMake code assessment (`csCMake.cmake` + `utils/*.cmake`)
- [ ] `cmake_minimum_required(VERSION 3.31.5)` inside `csCMake.cmake` (non-standard in an included file; 3.31.5 is very new) → remove, add version guard.
- [ ] `cs_target_link_libraries` mishandles scope keywords when not first in `ARGN` → parse/preserve scope.
- [ ] `cs_target_sources` uses `CMAKE_SOURCE_DIR` for relative path → use `CMAKE_CURRENT_SOURCE_DIR`.
- [ ] MSVC runtime hardcoded to `MultiThreaded*DLL` → add static-runtime option.
- [ ] Error messages reference `_cs_add_custom_build_configuration` (doesn't exist) → align with real function names.
- [ ] Silent skips in `csTargetDependencies.cmake` only emit debug messages → promote to `WARNING`.
- [ ] `cs_finalize_project` does reporting + install finalization + VS debugger setup → split concerns.
- [x] `templates/csTemplateConfig.cmake.in` breaks cmake-format (`@...@` substitution) → formatted/linted via `cscmake-cmake-template` (placeholder stand-ins).
- [ ] Refactor the functions over the cmake-lint complexity limits (scoped `# cmake-lint: disable` today): `_cs_parse_additional_configurations` (R0912 16/12 branches, R0915 103/50 statements), `_cs_recursive_analyze_target` (R0915 54/50); `_cs_configure_config_cmake` has 7 positional args (R0913, file-level pragma in `csInstall.cmake`) → keyword args.
- [ ] Naming: public camelCase API (`csUseOpenMPOnTarget`, `cs_compileEachInstalledInclude`, `csGetConfigurationWithStrictFlags`) and private `_csPopulateTargetDependencies`/`_csCheckPathExistsAndAddToTargetProperty`/`_csSetConfigurationWithStrictFlags` do not follow `cs_snake_case`; cmake-lint patterns are prefix matches so they pass. Rename with deprecated aliases for the public ones.
- [ ] `cs_print_target_properties` iterates `${PROP_LIST}` but builds `CMAKE_PROPERTY_LIST` → prints nothing (bug).
- [ ] Some old comments were flattened by earlier cmake-format runs (bullet lists merged into prose, e.g. `_cs_recursive_analyze_target`, `_cs_configure_config_cmake`, `_cs_parse_additional_configurations`) → rewrite them.
- [ ] No CMake-level tests → fixture project in Phase 2.
- [ ] 46 lines over 120 columns are string literals (log messages and the code injected into `<Ns>Config.cmake`), so `C0301` is disabled. Split/shorten them (`message()` concatenates its arguments; `cs_debug_message` takes a single string, so build the text first) and re-enable `C0301`.
- [ ] Template `csTemplateConfig.cmake.in`: the TODO about `@EXPORT_NAMESPACE_SANITIZED@`-prefixed function/macro names (needed to avoid clashes between installed packages) is still open.
- [ ] Template: the standalone `@INJECTED_FIND_PACKAGES_CODE@` line is now indented inside the macro, so the first injected line gets 2 extra spaces in the generated Config.cmake (cosmetic) → drop the leading spaces of the first line in `_cs_finalize_install`.
- [ ] Phase 2 fixture: also run cmake-lint on the generated/installed `<Ns>Config.cmake` (today only the template is linted, not its expansion).

### Tooling (cmakelang)
- [ ] cmakelang (cmake-format/cmake-lint) 0.6.13 is the last release and unmaintained; Python 3.13/3.14 compatibility only proven by CI. If it breaks, evaluate `gersemi` (formatter) and keep/replace cmake-lint.
- [ ] cmakelang 0.6.13 bug: suppression events are not sorted by line, so a file-level `# cmake-lint: disable` disables the later function-level ones in the same file (workaround documented in CLAUDE.md; only `csInstall.cmake` has a file-level pragma).
- [ ] cmake-lint name patterns are prefix matches (`re.match`), so non-conforming names pass. After the renames above, anchor the patterns in `.cmake-format.json` with `$`.
- [ ] Adopt the established CMake naming: lowercase snake_case function arguments and local variables (cmakelang default; UPPER_CASE stays for cache/global variables and keywords). `argument_var_pattern` / `local_var_pattern` in `.cmake-format.json` are **temporary** overrides that accept today's UPPER_CASE names (166 arguments, 98 locals). Do the rename in its own commit **after** the Phase 2 fixture project exists (configure/build/install/`find_package`) to verify it. Watch out: `_cs_configure_config_cmake` argument names must match the `@VAR@` placeholders of `templates/csTemplateConfig.cmake.in` (rename both together); CMake functions see caller variables (new collisions/shadowing); check `${OUT_VAR}`/`PARENT_SCOPE` and `cmake_parse_arguments` prefixes. Then delete both overrides.
- [ ] `cmake-lint -c` takes one or more values and swallows the following file paths ("files scanned: 0", exit 0). `cscmake-cmake-template` passes `-c` last; keep that in mind for any other cmake-lint invocation.

### cscmake ↔ csorchestrator alignment (future)
- [ ] csorchestrator keeps its own copy of the supported matrix (`frontend/cscmake_presets/supported_variants.py` + `domain/context/*`); `src/cscmake/presets/registry.py` is the source of truth. Prevent silent drift **without a code dependency in either direction**: csCMake is checked out next to projects (never pip-installed) and must not be checked out automatically by csorchestrator.
  - csCMake: the generator also writes a committed manifest `presets/csv1/variants.json` (per variant: id, os/os_version/architecture/variant/compiler/compiler_version/generator/generator_type, short forms). Kept in sync by the `generate-csv1-presets` hook and the sync test — a data contract, not code.
  - csorchestrator: a test loads `variants.json` from an already-present csCMake checkout (sibling `../csCMake`, or a path given via env var / pytest option) and asserts its own `get_supported_context_os_architecture_list()` + `short_*` match it exactly. Skipped (not failed) when no checkout is found; never clones. In csorchestrator CI the checkout is an explicit workflow step (`actions/checkout` of csCMake at a pinned ref), not done by csorchestrator code.
  - Adding a variant in csCMake then makes csorchestrator's test fail until it catches up (or is pinned to the older ref).

## Process / dependency hygiene

- [ ] **Keep `pyproject.toml` dev deps and `constraints-minimum.txt` in sync.** The CI minimum-deps job installs `pip install -e .[dev] -c constraints-minimum.txt`. If a new dev dependency is added to `pyproject.toml` but not pinned in `constraints-minimum.txt`, the minimum job will silently install the latest version from PyPI instead of the pinned minimum, defeating the purpose of the minimum-deps test. Update both files together in the same commit.

## PLAN_STATE

| Phase | Status | Notes |
|-------|--------|-------|
| 0 | done | `c399f7f` was partial; gaps completed in `fa2eefc` (see CHANGELOG). CI green on GitHub, signed off 2026-11-09. |
| 1 | done | Signed off 2026-11-09. Built-in registry + `cscmake-generate-presets`; generated presets byte-identical to `a818f7a`; regen pre-commit hook enabled; CMake format/lint (incl. templates) enabled. `fa2eefc`, CI green on GitHub (incl. Windows case-insensitive glob fix in tests). |
| 2 | not started | Tests |
| 3 | not started | Docs |
| 4 | not started | CMake hardening |
| 5 | not started | Release |

## CHANGELOG

### 2026-11-06 (session start)
- Reviewed cscmake and csorchestrator structure; created PLAN.md; defined phases and issues.

### 2026-11-06 (Phase 0 — project plumbing)
- `.vscode/settings.json`: enriched with pylance strict, ruff format-on-save + organize imports, mypy `--strict`, `pythonpath=["src"]`, excludes.
- `.vscode/extensions.json`: added pylance, ruff, mypy-type-checker.
- `.vscode/tasks.json`: fixed `--cov=cscmake` typo; added individual pre-commit tasks (mypy, ruff, ruff-format) with dedicated panels.
- `.vscode/launch.json`: added debugpy configs for "Debug all tests", `tests/cscmake/utils`, `tests/cscmake/presets`.
- `constraints-minimum.txt`: added pinned minimum dev dependency versions for CI minimum-deps job; kept in sync with `pyproject.toml` dev deps (incl. `import-linter`).
- `pyproject.toml`: expanded ruff rules (`UP`,`SIM`,`N`,`C4`,`W`); added pytest `testpaths`, `pythonpath=["src"]`, `addopts`; removed unused `markers` block; added `[tool.coverage]` and `[tool.importlinter]`; added `import-linter[ui]>=2.0` to dev deps.
- `.pre-commit-config.yaml`: added actionlint and import-linter hooks; `generate-csv1-presets` hook **deferred to Phase 1** (commented with TODO — needs built-in variant registry + `--check` flag); kept cmake-format with template exclusion.
- `setup.sh` / `setup.ps1`: removed `../../../csOrchestrator` path entirely; added `setuptools wheel` to pip upgrade; aligned with csorchestrator (Python arg, version check).
- `.github/workflows/ci.yml`: added CI matrix (ubuntu/windows/macOS × 3.11/3.12/3.13/3.14 + minimum-deps job), MSVC setup on Windows, pre-commit, pytest + coverage.
  - **Deferred:** `setup-cmake` step (CMake not needed for Phase 0 Python tests; add in Phase 2 with fixture tests).
  - **Deferred:** `presets-sync` job (generator still imports `csorchestrator`, no `--check` flag; add in Phase 1).
- `tools/generate_all_csv1_presets.py`: fixed ruff N806 naming violations + C414 (`sorted(list(set(...)))` → `sorted(set(...))`).
- `src/cscmake/utils/generate_cs_preset_variants.py`: ruff auto-fix (typing → collections.abc for Mapping, `Dict` → `dict`).
- `pre-commit run --all-files`: **all hooks pass**.
- `.agents/skills/cscmake-development/SKILL.md`: agent-facing development skill (repo map, conventions, common tasks, csOrchestrator decoupling).

### 2026-11-09 (Phase 1 — decouple preset generation from csOrchestrator)
- `src/cscmake/presets/registry.py`: typed, stdlib-only port of csOrchestrator's variant logic (enums, frozen dataclasses, short forms, `CS_SCHEMA_VERSION`), faithful to csorchestrator `c809a04` (the version with `generate_all_combinations`, which produced the committed presets). Defaults = full csv1 matrix (20 variants).
- Generator moved into the package: `src/cscmake/presets/generate.py` + console script `cscmake-generate-presets`; fixed output paths (were `csCMake/presets/...`), single/multi-config branches merged, stale-file removal, `--check`, `--template-dir`, `--output-dir`, `--quiet`. `tools/` removed (no `sys.path` workarounds).
- Verified: regenerated `presets/csv1/` (121 files) is byte-identical to the committed one, in a fresh `.venv` (python3.11) without csOrchestrator, and with `python3.11 -I` without installing the package.
- `.pre-commit-config.yaml`: `generate-csv1-presets` hook enabled (`language: system`, runs `cscmake-generate-presets` from the dev venv, `always_run`, regenerates in place, fails when files change). Note: in local hooks `additional_dependencies: [".[dev]"]` installs pre-commit's placeholder package, not this repo (csorchestrator's hooks rely on it by mistake).
- `setup.sh`/`setup.ps1`: csOrchestrator install removed. `pyproject.toml`: empty runtime deps, SPDX license (setuptools>=77), pytest `testpaths`/`pythonpath`.
- `.vscode/tasks.json`: coverage now targets `cscmake`; removed `--run-all` tasks (no conftest).
- `tests/cscmake/presets/test_registry.py`: matrix ids == committed `-ALL` presets; presets in sync.
- `tests/cscmake/presets/test_generate.py` (`tmp_path`): full matrix file count, valid JSON + LF-only, every `include` resolves (generated siblings / `presets/common`), `cs-presets-all.json` == sorted `-ALL` list, deterministic output, stale `*.json` removal (other files kept), `--check` detects modified/missing/extra files and never writes, `main()` exit codes/output, missing template dir → argparse error.
- README, SKILL.md updated; `CLAUDE.md` added.

### 2026-11-09 (Phase 0 — completion of gaps left by `c399f7f`)
- Audit: the Phase 0 entry above lists changes that were never committed; they are done now.
- `.vscode/settings.json` / `extensions.json`: ported from csorchestrator (pylance strict, ruff on save, mypy, `src` extraPaths).
- `.vscode/tasks.json`: per-hook pre-commit tasks (ALL, mypy, ruff, ruff-format, import-linter, generate-csv1-presets), presets generate/check tasks, `import-linter show graph`.
- `pyproject.toml`: ruff `UP`,`SIM`,`N`,`C4`,`W`; pytest `addopts = ["-ra", "--strict-markers"]`; `[tool.coverage]`; `[tool.importlinter]` contracts (`presets` → `utils`, `generate` → `registry`); `import-linter[ui]>=2.11` dev dep (`ui` first available in 2.11; `constraints-minimum.txt` updated).
- `.pre-commit-config.yaml`: actionlint; import-linter (`language: system`, dev venv); commented cmake-format-templates / cmake-lint removed.
- `setup.sh` / `setup.ps1`: `pip setuptools wheel` upgrade; `setup.ps1` takes the Python as argument and checks >= 3.11.
- `src/cscmake/utils/generate_cs_preset_variants.py`: `typing.Dict`/`Mapping` → `dict` / `collections.abc.Mapping`.
- `.gitattributes`: `presets/csv1/*.json text eol=lf`; generator writes LF on every OS.
- Checked locally on the working tree: ruff, ruff-format, mypy, lint-imports, pytest, `cscmake-generate-presets --check`, actionlint, cmake-format. CI to be run on GitHub.

### 2026-11-09 (CMake format + lint, incl. templates)
- `.cmake-format.json`: `line_width` 120 (same as Python); lint naming patterns matching the project style (UPPER_CASE or snake_case args/locals, `_?[0-9a-z_]+` functions/macros, dynamic `${...}` CACHE names allowed); `C0301` off (46 remaining long lines are string literals cmake-format cannot wrap), `C0307` off (conflicts with cmake-format argument alignment); `markup.literal_comment_pattern` keeps `# cmake-lint:` pragma blocks from being reflowed.
- All `csCMake.cmake` / `utils/*.cmake` reformatted at 120 columns. Verified with the cmakelang lexer: token streams identical to before (only whitespace/comments changed), except the intended `_cs_finalize_install` simplification (`set(TEMP ...)` + `string(REPLACE ... "${TEMP}")` → `string(REPLACE ... "${X}")`, 2×), which brings it under the 50-statement limit.
- Docstring comment blocks added to the 40 functions/macros missing one (C0111).
- Scoped pragmas: `R0912,R0915` in `_cs_parse_additional_configurations`, `R0915` in `_cs_recursive_analyze_target`, `W0106` in `cs_print_state_info` (intentional `ENV{...}` label), file-level `R0913` in `csInstall.cmake` (only `_cs_configure_config_cmake`). cmakelang 0.6.13 bug: suppression events are not sorted by line, so a file-level pragma disables later function-level ones in the same file — avoid mixing them.
- `src/cscmake/devtools/cmake_template.py` + console script `cscmake-cmake-template format [--check]|lint`: swaps `@VAR@` for parseable stand-ins (same width, lowercase in command/function-name position, uppercase elsewhere; standalone `@VAR@` lines → `cscmake_template_line(<n>)`), runs cmakelang, restores, and fails if the placeholders changed. Note: cmake-lint `-c` takes multiple values, so the config is passed after the input file.
- `templates/csTemplateConfig.cmake.in` formatted (tabs → spaces, `SET/STRING/MESSAGE/OPTION` lowercased; tokens otherwise identical) and given a docstring on its macro.
- `.pre-commit-config.yaml`: `cmake-lint` (upstream) + local `cmake-format-templates` / `cmake-lint-templates` (`language: system`, dev venv). `cmakelang>=0.6.13` dev dep, `cmakelang==0.6.13` in `constraints-minimum.txt`. import-linter: `presets | devtools` above `utils`.
- `tests/cscmake/devtools/test_cmake_template.py`: protect/restore round trip on the real template, stand-in width and case, case-insensitive restore, error cases, committed template formatted + lint-clean, format idempotent, `main` format `--check`/write and lint report.
- `.cmake-format.json` aligned with established conventions: removed `function_pattern` (same as the cmakelang default), `macro_pattern` now lowercase `[0-9a-z_]+` (CMake upstream style; cmakelang's UPPER_CASE macro default is not CMake practice). Argument/local-variable patterns kept as temporary overrides until the lowercase rename (Phase 4, see issues).
