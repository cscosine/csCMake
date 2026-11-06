# csCMake — Plan, Issues & TODO

Single source of truth for project maturity. Update `PLAN_STATE` and the checkboxes at the end of each work session.

## Vision & status

- csCMake wraps CMake for common project setup: targets, deps, installs, compile-option defaults, CMake presets.
- `main` is tagged `v0.1.0`. Active development is on `dev` (checked out here).
- Goal: full maturity — working setup/config, tests, CI, docs (humans + agents), preset generation independent of csOrchestrator.

## Roadmap (phases)

- [ ] **Phase 0 — Project plumbing** (port from csorchestrator: `.vscode/`, `pyproject.toml`, `conftest.py`, `constraints-minimum.txt`, `.pre-commit-config.yaml`, `setup.sh`/`setup.ps1`, CI workflow, agent skill)
- [ ] **Phase 1 — Decouple preset generation from csOrchestrator** (built-in variant registry in `src/cscmake/presets/`, rewrite `tools/generate_all_csv1_presets.py`, optional `--variants-source csorchestrator`)
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
- [ ] `setup.sh` / `setup.ps1` reference `../../../csOrchestrator` (wrong case on Linux, hard dep on unpublished package) → remove entirely.
- [ ] `pyproject.toml` pytest section empty → add `testpaths`, `pythonpath=["src"]`, markers, addopts.
- [ ] No `constraints-minimum.txt` → add for CI minimum-deps job.
- [ ] No `conftest.py` → add markers (`slow`, `git`, `requires`) + `--run-all` flag.
- [ ] `.pre-commit-config.yaml` has dead/commented hooks (preset gen, cmake-lint) → clean up, enable preset regen once dep-free.
- [ ] `.vscode/settings.json` minimal → enrich (pylance strict, ruff format-on-save, mypy strict, pythonpath).
- [ ] `.vscode/launch.json` missing → add debugpy configs for pytest.
- [ ] `.vscode/extensions.json` missing pylance/ruff/mypy → add.
- [ ] No CI → add `.github/workflows/ci.yml` mirroring csorchestrator + CMake setup + presets-sync gate.
- [ ] No agent-facing docs → add `.agents/skills/cscmake-development/SKILL.md` + `AGENTS.md`.

### CMake code assessment (`csCMake.cmake` + `utils/*.cmake`)
- [ ] `cmake_minimum_required(VERSION 3.31.5)` inside `csCMake.cmake` (non-standard in an included file; 3.31.5 is very new) → remove, add version guard.
- [ ] `cs_target_link_libraries` mishandles scope keywords when not first in `ARGN` → parse/preserve scope.
- [ ] `cs_target_sources` uses `CMAKE_SOURCE_DIR` for relative path → use `CMAKE_CURRENT_SOURCE_DIR`.
- [ ] MSVC runtime hardcoded to `MultiThreaded*DLL` → add static-runtime option.
- [ ] Error messages reference `_cs_add_custom_build_configuration` (doesn't exist) → align with real function names.
- [ ] Silent skips in `csTargetDependencies.cmake` only emit debug messages → promote to `WARNING`.
- [ ] `cs_finalize_project` does reporting + install finalization + VS debugger setup → split concerns.
- [ ] `templates/csTemplateConfig.cmake.in` breaks cmake-format (`@...@` substitution) → isolate/exclude.
- [ ] No CMake-level tests → fixture project in Phase 2.

## Process / dependency hygiene

- [ ] **Keep `pyproject.toml` dev deps and `constraints-minimum.txt` in sync.** The CI minimum-deps job installs `pip install -e .[dev] -c constraints-minimum.txt`. If a new dev dependency is added to `pyproject.toml` but not pinned in `constraints-minimum.txt`, the minimum job will silently install the latest version from PyPI instead of the pinned minimum, defeating the purpose of the minimum-deps test. Update both files together in the same commit.

## PLAN_STATE

| Phase | Status | Notes |
|-------|--------|-------|
| 0 | done | Project structure ported from csorchestrator (`.vscode/`, `pyproject.toml`, `constraints-minimum.txt`, `.pre-commit-config.yaml`, `setup.sh`/`setup.ps1`, CI workflow, agent skill). csOrchestrator dep removed from setup. `conftest.py` removed (no slow/git tests yet). |
| 1 | not started | Built-in preset variant registry |
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
