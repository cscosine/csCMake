# csCMake — Plan, Issues & TODO

Single source of truth for project maturity. Update `PLAN_STATE` and the checkboxes at the end of each work session.

## Vision & status

- csCMake wraps CMake for common project setup: targets, deps, installs, compile-option defaults, CMake presets.
- `main` is tagged `v0.1.0`. Active development is on `dev` (checked out here).
- Goal: full maturity — working setup/config, tests, CI, docs (humans + agents), preset generation independent of csOrchestrator.

## Roadmap (phases)

- [x] **Phase 0 — Project plumbing** (port from csorchestrator: `.vscode/`, `pyproject.toml`, `conftest.py`, `constraints-minimum.txt`, `.pre-commit-config.yaml`, `setup.sh`/`setup.ps1`, CI workflow, agent skill)
- [x] **Phase 1 — Decouple preset generation from csOrchestrator** (built-in variant registry in `src/cscmake/presets/registry.py`, generator `src/cscmake/presets/generate.py` / `cscmake-generate-presets` with `--check`, pre-commit regen hook; amended: `csCMakeProjectSetup-{default,default-standalone,shortBuildPath}.json` generated too). `--variants-source csorchestrator` dropped: csOrchestrator should import the registry from cscmake instead.
- [x] **Phase 2 — Tests** (Python unit tests + CMake smoke projects run on the full preset matrix in a dedicated CI workflow; see "Phase 2 plan")
- [ ] **Phase 3 — Productize (breaking): naming, hardening, docs** on branch `feature/productize`, validated on csfoundation before merging to `dev` (see "Phase 3 plan")
- [ ] **Phase 4 — Internal quality (non-breaking)**: complexity refactors, re-enable C0301, Python 100% coverage, remaining smoke gaps (macOS, non-csCMake consumer), cmakelang replacement evaluation
- [ ] **Phase 5 — Release** (version bump — `v0.2.0` or `v1.0.0`, to decide —, tag, CHANGELOG entries)

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
- [x] No CMake-level tests → smoke projects `tests/smoke/` (Phase 2), run on all 20 variants by `smoke.yml`.
- [ ] 46 lines over 120 columns are string literals (log messages and the code injected into `<Ns>Config.cmake`), so `C0301` is disabled. Split/shorten them (`message()` concatenates its arguments; `cs_debug_message` takes a single string, so build the text first) and re-enable `C0301`.
- [ ] Template `csTemplateConfig.cmake.in`: the TODO about `@EXPORT_NAMESPACE_SANITIZED@`-prefixed function/macro names (needed to avoid clashes between installed packages) is still open.
- [x] Template: the standalone `@INJECTED_FIND_PACKAGES_CODE@` line is indented inside the macro → `_cs_finalize_install` now always wraps the injected code without leading spaces on the first line (also fixes a whitespace-only line when nothing is injected, found by linting the generated Config in Phase 2).
- [x] Phase 2: cmake-lint on the installed `csSmokeConfig.cmake` (`run_smoke.py`; C0103 skipped there: names come from CMake's `<Package>_*` conventions and the user's package/export names).
- [ ] The presets set `CMAKE_C_COMPILER` for every variant, so C++-only projects get a "Manually-specified variables were not used: CMAKE_C_COMPILER" warning at configure (seen in the smoke projects) → harmless; consider setting it only when C is enabled, or document it.
- [ ] cmake-format does not know the `cs_*` command signatures, so calls like `cs_initialize_project(...)` / `cs_target_sources(...)` are laid out one argument per line or flattened → declare them in `.cmake-format.json` (`parse.additional_commands`: flags, keyword arguments).

### csCMake location (presets)
- [ ] Evaluate making the csCMake location configurable. Today only two layouts are possible, both hard-coded:
  - default: csCMake is a sibling of the project, `${sourceParentDir}/csCMake` (in the project's `CMakePresets.json` include, its `csCMakeProjectSetup.json` include, and `WORKSPACE_ROOT` / `CS_CMAKE_ROOT` in `csCMakeProjectSetup-base.json`);
  - standalone: `<project>/workspace/csCMake` (`csCMakeProjectSetup-base-standalone.json`).
  A preset `environment` overrides the process environment, so exporting `CS_CMAKE_ROOT` / `WORKSPACE_ROOT` has no effect; `CS_CMAKE_MODULE_PATH_*` / `CS_CMAKE_PREFIX_PATH_*` only add paths. A project can define its own `cscmake-project-setup` preset (own `CS_CMAKE_ROOT`/`WORKSPACE_ROOT`), but its `CMakePresets.json` include still assumes the sibling path.
- [ ] Option to evaluate: a base setup whose root comes from the environment, e.g. `csCMakeProjectSetup-base-env.json` + `-default-env.json` using `$penv{CS_CMAKE_ROOT}` / `$penv{CS_CMAKE_WORKSPACE_ROOT}` (presets v7+ also allow `$penv{}` in `include`, so `CMakePresets.json` could include `$penv{CS_CMAKE_ROOT}/presets/csv1/cs-presets-all.json`). Presets have no default for unset variables, so this must be an additional variant, not a replacement of the zero-setup sibling layout.
- [ ] The standalone layout is not tested: add it to the smoke tests (a project with `workspace/csCMake` inside, using `csCMakeProjectSetup-default-standalone.json`), and likewise any configurable-root variant if added. Today the smoke tests cover the default layout with `csCMakeProjectSetup-shortBuildPath.json` (csSmokeMidB) and `csCMakeProjectSetup-default.json` (the other chain projects).

### Python code coverage
- [ ] Reach **100% line + branch coverage** of `src/cscmake` (baseline 2026-11-09: 88% overall, 415 statements / 102 branches, `pytest --cov=cscmake --cov-branch`):
  - `presets/registry.py` 79%: non-default variant selection (`use_ninja_for_windows`, `use_ninja` / `use_ninjamulti` without `generate_all_combinations`), MSVC versions for Ninja on Windows, `MACOS` branches, `assert_never` fallbacks;
  - `devtools/cmake_template.py` 90%: cmake-format failure, restored placeholders differing from the original, `TemplateError` reported by `main`, the `__main__` entry point;
  - `presets/generate.py` 98%: the `__main__` entry point.
- [ ] Then enforce it: `[tool.coverage.report] fail_under = 100` in `pyproject.toml` (CI already runs `pytest --cov=cscmake --cov-branch`); exclude only `if __name__ == "__main__":` blocks (`exclude_also`), no other `# pragma: no cover`.
- Scope: only `src/cscmake` (`[tool.coverage.run] source = ["cscmake"]`). The CI helpers in `tests/smoke/` (`run_smoke.py`, `ci_matrix.py`) do **not** count for coverage (decided 2026-11-09).

### Tooling (cmakelang)
- [ ] cmakelang (cmake-format/cmake-lint) 0.6.13 is the last release and unmaintained; Python 3.13/3.14 compatibility only proven by CI. If it breaks, evaluate `gersemi` (formatter) and keep/replace cmake-lint.
- [ ] cmakelang 0.6.13 bug: suppression events are not sorted by line, so a file-level `# cmake-lint: disable` disables the later function-level ones in the same file (workaround documented in CLAUDE.md; only `csInstall.cmake` has a file-level pragma).
- [ ] cmake-lint name patterns are prefix matches (`re.match`), so non-conforming names pass. After the renames above, anchor the patterns in `.cmake-format.json` with `$`.
- [ ] Adopt the established CMake naming: lowercase snake_case function arguments and local variables (cmakelang default; UPPER_CASE stays for cache/global variables and keywords). `argument_var_pattern` / `local_var_pattern` in `.cmake-format.json` are **temporary** overrides that accept today's UPPER_CASE names (166 arguments, 98 locals). Do the rename in its own commit **after** the Phase 2 fixture project exists (configure/build/install/`find_package`) to verify it. Watch out: `_cs_configure_config_cmake` argument names must match the `@VAR@` placeholders of `templates/csTemplateConfig.cmake.in` (rename both together); CMake functions see caller variables (new collisions/shadowing); check `${OUT_VAR}`/`PARENT_SCOPE` and `cmake_parse_arguments` prefixes. Then delete both overrides.
- [ ] cmakelang 0.6.13 cannot lint CRLF files: `format.line_ending: auto` crashes cmake-lint (`set_line_ending` missing), `windows` still flags the last line (C0327). Found by the Windows smoke jobs (generated Config.cmake with CRLF): `run_smoke.py` now checks the line endings are consistent and lints an LF copy; `.gitattributes` forces LF for `*.cmake`, `*.cmake.in`, `CMakeLists.txt`.
- [ ] `cmake-lint -c` takes one or more values and swallows the following file paths ("files scanned: 0", exit 0). `cscmake-cmake-template` passes `-c` last; keep that in mind for any other cmake-lint invocation.

### Phase 3 plan (agreed 2026-11-09)
Breaking change, **no deprecation aliases**: old names are removed, a `MIGRATION.md` (old → new table for functions,
variables, properties, preset environment variables, default targets) guides the migration of the projects.
- **Branching**: csCMake `feature/productize` (from `dev`), one commit per sub-phase, review stop after each. Test bed:
  csfoundation (`workspace/`: csCMake, csCore, csCamera, csLie, csVisOpenGL; standalone layout) on `feature/productize`
  in each repo. When validated: merge (no squash) into `dev`, then migrate the other projects.
- **3a — Naming and API surface** (behaviour unchanged, smoke results identical):
  - API classification (details reviewed together): *user* (initialize/finalize, add_library/executable,
    target_sources/link_libraries, find_package, install_target, quality helpers, generate folders), *advanced*
    (`cs_get_*`/`cs_print_*` introspection), *private* (`_cs_*`, everything else).
  - Functions → `cs_snake_case` / `_cs_snake_case`, no aliases (`csUseOpenMPOnTarget`, `cs_compileEachInstalledInclude`,
    `csGetConfigurationWithStrictFlags`, `_csPopulateTargetDependencies`, `_csCheckPathExistsAndAddToTargetProperty`,
    `_csSetConfigurationWithStrictFlags`; internal ones with public names → `_cs_`).
  - One prefix everywhere: `CSCMAKE_` for cache/normal/environment/preset variables (`CS_CMAKE_*`, `WORKSPACE_ROOT`,
    `<project>_CS_CMAKE_DEBUG`, ...) and one scheme for global/target properties (`cs*` camelCase today).
  - Namespace declared once: `cs_initialize_project(NAMESPACE <ns> CXX_STANDARD ...)` (no positional project name; an old
    call fails as unparsed argument), `cs_finalize_project()` without argument. Real default-target names keep the
    `<P>` (project name) prefix; `EXPORT_NAME` makes the in-build alias equal to the installed name
    (`<ns>::cscmake_compile_options` in the build and after install; today `csCoreSol::csCoreSol_...` in the build vs
    `csCore::csCoreSol...` installed). `<Ns>_BASE_DIR` of the generated Config is public (csImgTracker uses it).
  - Debug option `<P>_CSCMAKE_DEBUG` per project (`<P>` = `PROJECT_NAME` at `cs_initialize_project`, grouped by
    cmake-gui), defined in `cs_initialize_project` (today `${CMAKE_PROJECT_NAME}_CS_CMAKE_DEBUG`, always the top-level
    project, defined once at include time); the Config keeps `<Ns>_DEBUG` per package.
  - Terminology: *component* everywhere (an install export = a `find_package(... COMPONENTS ...)` component):
    `cs_install_target(<target> <component> [DEFAULT])`, `CSCMAKE_COMPONENT_*` properties, `cs_get_*component*`.
  - Default targets (`<P>_csCMakeBaseInclude`, `<P>_csCMakeCompileOptionsDefault/Strict`, `<P>MSVCParallelCompile`,
    `<P>StrictCompilation`, component `<P>_csCMakeCommon`): analyse and refactor the naming.
  - Lowercase arguments/locals (with the template `@VAR@` placeholders), drop the temporary lint overrides, anchor the
    cmake-lint name patterns with `$`, `additional_commands` for the `cs_*` signatures. `MIGRATION.md` started.
- **3b — Hardening** (+ smoke coverage of every behaviour change and of what the docs show: shared lib, INTERFACE lib,
  multi-component with PUBLIC `cs_find_package`, strict config, compile-each-header; clang-tidy/OpenMP "experimental"
  until tested):
  - bugs: quoted `foreach` in `_cs_target_try_to_finalize` (iterates once over the whole list, confirmed with
    `cmake -P`), `cs_print_target_properties` (`PROP_LIST`), `cs_print_exported_list_details` (prints the export list
    as default list), error messages naming nonexistent functions / undefined variables, unused argument of
    `_cs_sort_export_dependent_exports`, `INSTALL_CONFIGDIR` read from the caller scope, PDB destination `bin`;
  - `csClangTidy.cmake` fails at include time on UNIX without clang-tidy → lazy lookup in `cs_exec_clang_tidy`
    (and verify its property value);
  - `CMAKE_SOURCE_DIR` used for the relative install paths of headers (wrong when the csCMake project is itself a
    subproject) → the source dir of `cs_initialize_project`, stored in a global property. **Not** `PROJECT_SOURCE_DIR`:
    csfoundation subdirectories call `project()` again (`project(core ...)`), which would change the install layout;
  - csCMake-owned cache variables not `FORCE`d (user `-D` honoured); `FORCE` only where csCMake must own the value
    (`CMAKE_CONFIGURATION_TYPES`), documented;
  - `cs_initialize_project(<name>)`: `FATAL_ERROR` if `<name>` differs from `PROJECT_NAME`; stays a macro, no leaked
    variables;
  - `cs_finalize_target` **mandatory**: `cs_finalize_project` fails listing unfinalized targets and targets whose link
    properties changed after finalization; a `cmake_language(DEFER)` check fails if `cs_finalize_project` is not called;
  - verbosity policy (no forced STATUS lines per call), silent skips → `WARNING`;
  - generated Config: namespaced variables (no `COMPONENT`, `${COMPONENT}_DEPENDENT_EXPORTS` clashes), the
    `@EXPORT_NAMESPACE_SANITIZED@` TODO, `<Pkg>_FOUND`/`OPTIONAL_COMPONENTS` semantics instead of `FATAL_ERROR`;
  - `cmake_minimum_required` in `csCMake.cmake` → version check (3.31, presets v10);
  - **nested csCMake projects** (a lib project `add_subdirectory`-ed into a target project): fails today
    (`duplicated element Debug`, verified 2026-11-09: all state is in global properties). Current project tracked by a
    variable set in `cs_initialize_project` (inherited by subdirectories, not tied to `PROJECT_NAME`); targets,
    components and dependency data keyed by project; each `cs_finalize_project` installs only its own components;
    build configurations shared by the build tree (nested project checks compatibility, rule to decide); links to a
    target of another csCMake project of the same build → `find_dependency(<ns> COMPONENTS ...)` in the Config
    (design together); smoke test with a nested project;
  - from the former Phase 4: static MSVC runtime option, split `cs_finalize_project`, configurable csCMake location;
  - double-check (likely a non-issue, prove with a test): `cs_target_link_libraries` scope keywords.
- **Chained-projects smoke test** (added before the renames, kept green through 3a/3b): mirror the csfoundation chain
  (csCore → csCamera → csImgTracker): `<X>Sol` top projects with a subproject named like the package, namespace ≠
  project name, default targets linked, components depending on each other, a third project consuming two packages.
  In 3b add two packages with the same component name (fails today: the generated Config sets
  `${COMPONENT}_DEPENDENT_EXPORTS` globally, which is why csfoundation names components `csCameraAssert`, `<P>Sol_csCMakeCommon`, ...).
- **3c — In-source docs**: one docstring format (signature, summary, arguments, *Reads*/*Writes*: variables, global
  and target properties); rewrite the comments flattened by cmake-format; full variables/properties reference.
- **3d — Docs**: `README.md` (pitch, quickstart, map), `AGENTS.md`, `MIGRATION.md`, `docs/user/` (quickstart,
  tutorials = smoke projects, reference of functions/user variables, troubleshooting), `docs/advanced/` (concepts and
  lifecycle, build configurations, target tracking, install/export, variables/properties reference, presets
  internals, extending, conventions). Plain Markdown on GitHub, diagrams in Mermaid. Every user entry links its
  "under the hood" advanced section and vice versa.
- **3e — Doc checks**: `cscmake-check-docs` (`src/cscmake/devtools`) + pre-commit hook: every public `cs_*` documented
  (and no stale entries), every variable/property in the reference, links/anchors resolve, tutorial snippets equal
  the smoke files.
- **3f — Validation** (final gate before `dev`): csfoundation migrated on `feature/productize` and green; merge to `dev`; migrate other projects
  (optional `cscmake-migrate` search/replace helper from the `MIGRATION.md` table, to decide).

### Phase 2 plan (agreed 2026-11-09)
- **Smoke projects** in `tests/smoke/` (consumers of csCMake through the presets, exactly like real projects):
  - `hello/` (export namespace `csSmoke`): `cs_initialize_project` with Debug, Release, RelWithDebInfo (mapped) and Paranoid (custom) configs; static lib `hellolib` (`hello_lib()` prints `hello-lib`); executable `helloapp` (calls it, prints `hello-app`); ctest: unit test of the lib + run of `helloapp` with output regex `hello-lib.*hello-app`; installed with `cs_install_target` + `cs_finalize_project(csSmoke)`.
  - `consumer/`: separate project, `find_package(csSmoke COMPONENTS hellolib REQUIRED)` from the install folder, links `csSmoke::hellolib`, ctest checks its output. Proves the installed `csSmokeConfig.cmake`.
- **Driver** `tests/smoke/run_smoke.py` (stdlib only), used by CI and by a local pytest: lays out csCMake + `hello` + `consumer` as siblings (the presets expect `${sourceParentDir}/csCMake`), runs `cmake --workflow` (multi-config: `debug-release-relWithDebInfo-paranoid`; single-config: one workflow per config), runs the **installed** `helloapp` of each config (install layout + postfixes), builds/tests the consumer, runs cmake-lint on the installed `csSmokeConfig.cmake`.
- **CI** `.github/workflows/smoke.yml`, separate from `ci.yml`: a `matrix` job prints the matrix JSON from the registry (`tests/smoke/ci_matrix.py`: variant → generator type + runner label, e.g. `ubuntu-24.04-arm`, `windows-2025-vs2026`), the `smoke` job uses `fromJSON` → all **20** variants × **4** configs. CMake/Ninja from the runner images (as csfoundation/csorchestrator do); add a setup action only if a runner turns out too old.
- **Local**: `tests/smoke/test_run_smoke.py` runs the driver for the host variants, marked `slow` + `requires("cmake")` via a new `conftest.py` (`--run-all`).

### Phase 2 — not covered by the smoke projects (trace for full completion)
- [ ] Shared libraries: Windows DLL export (`__declspec`/`GenerateExportHeader`), runtime dependency analysis (`csTargetDependencies`) and VS debugger PATH (`_cs_set_vs_debugger_env_variable`).
- [ ] INTERFACE / header-only libraries.
- [ ] Several components with dependencies between exports; cyclic dependency detection (expected failure test).
- [ ] `cs_find_package` PUBLIC propagation into the installed Config (`find_dependency`).
- [ ] `STRICT_COMPILATION_ON_CONFIG`, `cs_compileEachInstalledInclude`, `cs_exec_clang_tidy`, `csUseOpenMPOnTarget`.
- [ ] `csCMakeProjectSetup-default-standalone.json` and `-shortBuildPath.json` setups.
- [ ] A consumer that does not use csCMake (plain `find_package` with `CMAKE_PREFIX_PATH`).
- [ ] macOS (no variants in the registry yet).

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
| 1 | done | Signed off 2026-11-09; amended 2026-11-09 (project setup presets generated, see CHANGELOG). Built-in registry + `cscmake-generate-presets`; generated presets byte-identical to `a818f7a`; regen pre-commit hook enabled; CMake format/lint (incl. templates) enabled. `fa2eefc`, CI green on GitHub (incl. Windows case-insensitive glob fix in tests). |
| 2 | done | Signed off 2026-11-09. Smoke projects (csSmoke, csSmokeConsumer) + `run_smoke.py` + `smoke.yml`: all 20 preset variants green on GitHub (`95190ae`, Windows CRLF lint fix `345dc60`). Remaining coverage gaps tracked in "Phase 2 — not covered by the smoke projects". |
| 3 | in progress | Productize on `feature/productize`: plan agreed 2026-11-09; 3a (naming) next, rename table under review. |
| 4 | not started | Internal quality (non-breaking) |
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

### 2026-11-09 (Phase 1 amendment — project setup presets generated)
- Finding: `presets/csCMakeProjectSetup-{default,default-standalone,shortBuildPath}.json` listed the 20 `cscmake-project-setup-<variant>` presets (inherited by every `-base` preset) by hand → could drift from the registry.
- Now generated by `cscmake-generate-presets` from `presets/template/csCMakeProjectSetup-*.json.template` (`generate_project_setup_presets`, `--setup-output-dir`); `--check` and the pre-commit hook cover them. Output identical to the hand-written files except the added "autogenerated" `$comment` (JSON compared equal, same preset order). `csCMakeProjectSetup-base*.json` stay hand-written.
- Tests: every variant has a setup preset in each file; every setup preset inherited by a `-base` preset exists; `--check` detects stale/missing setup files; committed files in sync; CLI tests never write into the repository.

### 2026-11-09 (Phase 2 — smoke tests on the preset matrix)
- `tests/smoke/csSmoke`: `cs_initialize_project` (Debug, Release, RelWithDebInfo mapped, Paranoid custom, postfix `dp`), static lib `hellolib` (+ `hellolibTest`), executable `helloapp` (ctest output regex `hello-lib[\r\n]+hello-app`), `cs_install_target`, `cs_finalize_project(csSmoke)`; uses `csCMakeProjectSetup-shortBuildPath.json`. `tests/smoke/csSmokeConsumer`: `cs_find_package(... csSmoke COMPONENTS hellolib REQUIRED CONFIG)` + ctest; uses `csCMakeProjectSetup-default.json`. Project folders are named after the package: `find_package` searches `<prefix>/<name>*/lib/cmake/<name>` and the install prefix is `install/<variant>/<sourceDirName>`.
- `tests/smoke/run_smoke.py`: workspace with csCMake + both projects as siblings, `cmake --workflow` (multi-config: one `debug-release-relWithDebInfo-paranoid` workflow; single-config: one per config), installed `helloapp{,d,rd,dp}` output check, cmake-lint of the installed `csSmokeConfig.cmake`, GitHub log groups.
- `tests/smoke/ci_matrix.py` + `.github/workflows/smoke.yml`: matrix generated from the registry (variant → runner: `ubuntu-XX.04[-arm]`, `windows-2022` for VS 2022, `windows-2025-vs2026` for VS 2026), 20 jobs, `fail-fast: false`; CMake/Ninja from the runner images.
- Root `conftest.py`: `slow` (skipped unless `--run-all`) and `requires(tools)` markers, registered in `pyproject.toml`. Tests: matrix = registry, runner labels, `GITHUB_OUTPUT`; workflow presets exist in the generated presets; multi/single-config workflow selection; workspace layout; slow smoke test per host variant (`CSCMAKE_SMOKE_VARIANTS` overrides).
- Fix found by the smoke lint: `_cs_finalize_install` left a whitespace-only line in the generated Config when no `find_dependency` was injected (and an extra indent on the first injected line) since the template formatting.
- Local run: 46 tests incl. 4 smoke variants pass (`pytest --run-all`, ~35 s).
- Fix after the first GitHub run (2026-11-09): all Windows smoke jobs failed only at the cmake-lint step of the installed `csSmokeConfig.cmake` (C0327, CRLF: the template was checked out with CRLF by `* text=auto`; configure, build, install, ctest and the installed apps were fine). `.gitattributes`: `eol=lf` for CMake sources; `run_smoke.py`: consistent line endings required (mixed → failure), lint of an LF copy (cmakelang CRLF bugs).

### 2026-11-09 (Phase 3 — plan)
- Inventory of `csCMake.cmake`, `utils/*.cmake`, the Config template and the presets (83 functions/macros: 48
  public-named, 35 private); findings recorded in "Phase 3 plan". Breaking-change productization agreed: branch
  `feature/productize`, csfoundation as test bed, no deprecation aliases, `MIGRATION.md`; breaking items of the old
  Phase 4 moved into Phase 3, Phase 4 reduced to non-breaking internal quality.

### 2026-11-09 (Phase 3 — chained-projects smoke test, before the renames)
- `tests/smoke/csSmokeBase` (like csCore: `csSmokeBaseSol` top project, subprojects `csSmokeBase`, `core` INTERFACE
  with `cs_compileEachInstalledInclude` + strict options, `text` STATIC depending on `core`), `csSmokeMidA` /
  `csSmokeMidB` (like csCamera / csLie: `cs_find_package(... PUBLIC csSmokeBase COMPONENTS text|core ...)`, default
  targets linked), `csSmokeTop` (consumes both: diamond on `csSmokeBase`). Records today's behaviour; must stay green
  through 3a/3b.
- `csSmoke` / `csSmokeConsumer` removed, superseded by the chain (2026-11-09): what only they covered moved into it —
  `csSmokeMidB` uses the flat layout (single `project()` = namespace, no `Sol`) and `csCMakeProjectSetup-shortBuildPath.json`,
  `csSmokeTop` finds `csSmokeMidB` PRIVATE. Dropped: a project installing nothing (empty Config).
- `run_smoke.py`: `PROJECTS` in build order (expected `find_dependency` packages of the installed Config, installed
  apps + expected output per project): checks that the installed Config propagates exactly the PUBLIC
  `cs_find_package` (PRIVATE not; not verified before), cmake-lint of every installed Config; test that every
  project folder is run. `tests/smoke/README.md`: what is tested, Mermaid graphs
  (to be moved/linked into `docs/advanced/` in 3d).
