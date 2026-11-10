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
- [x] **Phase 3 — Productize (breaking): naming, hardening, docs** on branch `feature/productize`, validated on csfoundation before merging to `dev` (see "Phase 3 plan")
- [ ] **Phase 4 — Internal quality (non-breaking)**: complexity refactors, re-enable C0301, Python 100% coverage, remaining smoke gaps (macOS, non-csCMake consumer), cmakelang replacement evaluation
- [ ] **Phase 5 — Release** (version bump — `v0.2.0` or `v1.0.0`, to decide —, tag, CHANGELOG entries; release package with the docs: see "Phase 5 — Release package")

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
- [x] (3b step 2) `cmake_minimum_required(VERSION 3.31.5)` inside `csCMake.cmake` (non-standard in an included file; 3.31.5 is very new) → remove, add version guard.
- [x] ~~`cs_target_link_libraries` mishandles scope keywords when not first in `ARGN`~~ → not an issue: keywords are kept in place, the result equals `target_link_libraries` (`tests/cmake/test_target_link_libraries.py`, 3b step 1).
- [x] (3b step 2) `cs_target_sources` uses `CMAKE_SOURCE_DIR` for relative path → use `CMAKE_CURRENT_SOURCE_DIR`.
- [x] (3b step 6b) MSVC runtime hardcoded to `MultiThreaded*DLL` → overridable per configuration (`-DCSCMAKE_MSVC_RUNTIME_LIBRARY_<CONFIG>`), documented; no extra option.
- [x] (3b step 1) Error messages reference functions that do not exist / undefined variables → fixed.
- [x] (3b step 2) Silent skips in `csTargetDependencies.cmake` only emit debug messages → promote to `WARNING`.
- [x] (3b step 4) `cs_finalize_project` does reporting + install finalization + VS debugger setup → split concerns.
- [x] `templates/csTemplateConfig.cmake.in` breaks cmake-format (`@...@` substitution) → formatted/linted via `cscmake-cmake-template` (placeholder stand-ins).
- [x] (4b) Refactor the functions over the cmake-lint complexity limits (scoped `# cmake-lint: disable` today): `_cs_parse_additional_configurations` (R0912 16/12 branches, R0915 103/50 statements), `_cs_recursive_analyze_target` (R0915 54/50); `_cs_configure_config_cmake` has 7 positional args (R0913, file-level pragma in `csInstall.cmake`) → keyword args.
- [x] (3a) Naming: public camelCase API (`csUseOpenMPOnTarget`, `cs_compileEachInstalledInclude`, `csGetConfigurationWithStrictFlags`) and private `_csPopulateTargetDependencies`/`_csCheckPathExistsAndAddToTargetProperty`/`_csSetConfigurationWithStrictFlags` do not follow `cs_snake_case`; cmake-lint patterns are prefix matches so they pass. Rename with deprecated aliases for the public ones.
- [x] (3b step 1) `cs_print_target_properties` iterates `${PROP_LIST}` but builds `CMAKE_PROPERTY_LIST` → prints nothing (bug).
- [x] (4b, the three functions rewritten) Some old comments were flattened by earlier cmake-format runs (bullet lists merged into prose, e.g. `_cs_recursive_analyze_target`, `_cs_configure_config_cmake`, `_cs_parse_additional_configurations`) → rewrite them.
- [x] No CMake-level tests → smoke projects `tests/smoke/` (Phase 2), run on all 20 variants by `smoke.yml`.
- [x] (3b step 2) 46 lines over 120 columns are string literals (log messages and the code injected into `<Ns>Config.cmake`), so `C0301` is disabled. Split/shorten them (`message()` concatenates its arguments; `cs_debug_message` takes a single string, so build the text first) and re-enable `C0301`.
- [x] (3b step 3) Template `csTemplateConfig.cmake.in`: the TODO about `@EXPORT_NAMESPACE_SANITIZED@`-prefixed function/macro names (needed to avoid clashes between installed packages) is still open.
- [x] Template: the standalone `@INJECTED_FIND_PACKAGES_CODE@` line is indented inside the macro → `_cs_finalize_install` now always wraps the injected code without leading spaces on the first line (also fixes a whitespace-only line when nothing is injected, found by linting the generated Config in Phase 2).
- [x] Phase 2: cmake-lint on the installed `csSmokeConfig.cmake` (`run_smoke.py`; C0103 skipped there: names come from CMake's `<Package>_*` conventions and the user's package/export names).
- [x] (4d: read by `cs_initialize_project`) The presets set `CMAKE_C_COMPILER` for every variant, so C++-only projects get a "Manually-specified variables were not used: CMAKE_C_COMPILER" warning at configure (seen in the smoke projects) → harmless; consider setting it only when C is enabled, or document it.
- [x] (Phase 3a step 5) cmake-format does not know the `cs_*` command signatures, so calls like `cs_initialize_project(...)` / `cs_target_sources(...)` are laid out one argument per line or flattened → declare them in `.cmake-format.json` (`parse.additional_commands`: flags, keyword arguments).

### csCMake location (presets)
- [x] (3b step 6d) Evaluate making the csCMake location configurable. Today only two layouts are possible, both hard-coded:
  - default: csCMake is a sibling of the project, `${sourceParentDir}/csCMake` (in the project's `CMakePresets.json` include, its `csCMakeProjectSetup.json` include, and `WORKSPACE_ROOT` / `CS_CMAKE_ROOT` in `csCMakeProjectSetup-base.json`);
  - standalone: `<project>/workspace/csCMake` (`csCMakeProjectSetup-base-standalone.json`).
  A preset `environment` overrides the process environment, so exporting `CS_CMAKE_ROOT` / `WORKSPACE_ROOT` has no effect; `CS_CMAKE_MODULE_PATH_*` / `CS_CMAKE_PREFIX_PATH_*` only add paths. A project can define its own `cscmake-project-setup` preset (own `CS_CMAKE_ROOT`/`WORKSPACE_ROOT`), but its `CMakePresets.json` include still assumes the sibling path.
- [x] (3b step 6d) Option to evaluate: a base setup whose root comes from the environment, e.g. `csCMakeProjectSetup-base-env.json` + `-default-env.json` using `$penv{CS_CMAKE_ROOT}` / `$penv{CS_CMAKE_WORKSPACE_ROOT}` (presets v7+ also allow `$penv{}` in `include`, so `CMakePresets.json` could include `$penv{CS_CMAKE_ROOT}/presets/csv1/cs-presets-all.json`). Presets have no default for unset variables, so this must be an additional variant, not a replacement of the zero-setup sibling layout.
- [x] (3b step 6d) The standalone layout is not tested: add it to the smoke tests (a project with `workspace/csCMake` inside, using `csCMakeProjectSetup-default-standalone.json`), and likewise any configurable-root variant if added. Today the smoke tests cover the default layout with `csCMakeProjectSetup-shortBuildPath.json` (csSmokeMidB) and `csCMakeProjectSetup-default.json` (the other chain projects).

### Python code coverage
- [x] (4a) Reach **100% line + branch coverage** of `src/cscmake` (baseline 2026-11-09: 88% overall, 415 statements / 102 branches, `pytest --cov=cscmake --cov-branch`):
  - `presets/registry.py` 79%: non-default variant selection (`use_ninja_for_windows`, `use_ninja` / `use_ninjamulti` without `generate_all_combinations`), MSVC versions for Ninja on Windows, `MACOS` branches, `assert_never` fallbacks;
  - `devtools/cmake_template.py` 90%: cmake-format failure, restored placeholders differing from the original, `TemplateError` reported by `main`, the `__main__` entry point;
  - `presets/generate.py` 98%: the `__main__` entry point.
- [x] (4a) Then enforce it: `[tool.coverage.report] fail_under = 100` in `pyproject.toml` (CI already runs `pytest --cov=cscmake --cov-branch`); exclude only `if __name__ == "__main__":` blocks and the `case _: assert_never(...)` exhaustiveness checks
  (`exclude_also`), no `# pragma: no cover`.
- Scope: only `src/cscmake` (`[tool.coverage.run] source = ["cscmake"]`). The CI helpers in `tests/smoke/` (`run_smoke.py`, `ci_matrix.py`) do **not** count for coverage (decided 2026-11-09).

### Tooling (cmakelang)
- [ ] **4h — gersemi + `cscmake-lint`** (decided, user 2026-11-10: option 2 below; after 4f and 4g): gersemi formats
  csCMake, the smoke projects and the template (one-time reformat, `.gersemirc`, a gersemi extension with the `cs_*`
  signatures generated from one signature list); `cscmake-lint` (stdlib, on the `check_docs` parser) checks the naming
  patterns, a comment before every function / macro, the complexity limits and the line length; cmakelang removed
  (dev deps, constraints, pre-commit, `cscmake-cmake-template` format part); `docs/user/formatting.md`, CLAUDE.md, the
  contributing pages and the release package (gersemi config + extension instead of `.cmake-format.json`) follow;
  then Python 3.15 in the CI matrix. Until 4h: cmakelang with Python <= 3.14.
- 4e evaluation (2026-11-10), decided: option 2 (4h above):
  - **Risk, dated**: cmakelang 0.6.13 (last release) is reported failing on **Python 3.15**: `re.Scanner` rejects
    capturing groups (Red Hat bugzilla 2485807, "Cannot use capturing groups in re.Scanner"). Confirmed in our copy:
    `cmakelang/lex/__init__.py` builds a `re.Scanner` whose patterns use groups with backreferences
    (`#\[(=*)\[.*?\]\1\]`, bracket arguments): not fixable by making them non-capturing. Not reproduced (no 3.15
    here). Today's CI (3.11 to 3.14) is fine; adding 3.15 to the CI matrix, or a 3.15 dev venv, breaks `cmake-format`,
    `cmake-lint` and `cscmake-cmake-template`.
  - **Formatter: gersemi** (BlankSpruce/gersemi, PyPI, pre-commit, actively released: 0.29.2 tried, Rust backend, needs
    only pyyaml). Prototype on a copy of `csCMake.cmake`, `utils/`, `tests/smoke/` with `--line-length 120 --indent 2`:
    every comment line untouched (the `#.rst:` blocks need no `literal_comment_pattern`), the `@VAR@` template parsed
    as is (no placeholder swap needed for formatting); style differences only, e.g. `set(<var> <value> PARENT_SCOPE)` on
    one line, closing `)` on its own line for wrapped calls (~40-230 changed lines per big module, a one-time reformat).
    The `cs_*` keyword signatures are not learned from `--definitions` (our keywords are in variables, and
    `cs_initialize_project` forwards to a function): they need a gersemi extension (a Python module describing the
    commands), generated from the same signature list as `.cmake-format.json` `parse.additional_commands`.
  - **Linter: no maintained equivalent of cmake-lint** found: check-cmake (marzer), cmake_check (DaelDe, user rules),
    cmakelint (richq, basic style, used by ROS ament), ast-grep rule hooks. What we use cmake-lint for: the naming
    patterns (functions, macros, arguments, locals, globals), a comment before every function / macro (C0111), the
    complexity limits (R0912 branches, R0913 arguments, R0915 statements), line length (C0301), plus its general
    checks (C0113 missing COMMENT, ...). `cscmake-check-docs` already parses the modules (functions, comment blocks).
  - Options: (1) keep cmakelang, pin the hooks and the dev tools to Python <= 3.14 (pre-commit `language_version`;
    CI matrix stays <= 3.14) and revisit when 3.14 nears its end of life; (2) **gersemi for formatting + our own
    `cscmake-lint` for the rules we rely on** (naming, comment before every function / macro, complexity, line length),
    built on the `check_docs` parser, stdlib only; consumers' formatting docs (`docs/user/formatting.md`) and the
    release package (`.cmake-format.json` -> gersemi config + extension) change with it; (3) vendor and patch
    cmakelang's lexer (a fork to maintain). Recommendation: (2), as its own Phase 4 step after 4f / 4g (the
    reorganisation of 4g moves code anyway, a good moment for the one-time reformat); (1) until then.
- [ ] cmakelang (cmake-format/cmake-lint) 0.6.13 is the last release and unmaintained; Python 3.13/3.14 compatibility only proven by CI. If it breaks, evaluate `gersemi` (formatter) and keep/replace cmake-lint.
- [ ] cmakelang 0.6.13 bug: suppression events are not sorted by line, so a file-level `# cmake-lint: disable` disables the later function-level ones in the same file (workaround documented in CLAUDE.md; no file-level pragma left since 4b).
- [x] (Phase 3a step 5) cmake-lint name patterns are prefix matches (`re.match`), so non-conforming names pass. After the renames above, anchor the patterns in `.cmake-format.json` with `$`.
- [x] (Phase 3a step 4) Adopt the established CMake naming: lowercase snake_case function arguments and local variables (cmakelang default; UPPER_CASE stays for cache/global variables and keywords). `argument_var_pattern` / `local_var_pattern` in `.cmake-format.json` are **temporary** overrides that accept today's UPPER_CASE names (166 arguments, 98 locals). Do the rename in its own commit **after** the Phase 2 fixture project exists (configure/build/install/`find_package`) to verify it. Watch out: `_cs_configure_config_cmake` argument names must match the `@VAR@` placeholders of `templates/csTemplateConfig.cmake.in` (rename both together); CMake functions see caller variables (new collisions/shadowing); check `${OUT_VAR}`/`PARENT_SCOPE` and `cmake_parse_arguments` prefixes. Then delete both overrides.
- [ ] cmakelang 0.6.13 cannot lint CRLF files: `format.line_ending: auto` crashes cmake-lint (`set_line_ending` missing), `windows` still flags the last line (C0327). Found by the Windows smoke jobs (generated Config.cmake with CRLF): `run_smoke.py` now checks the line endings are consistent and lints an LF copy; `.gitattributes` forces LF for `*.cmake`, `*.cmake.in`, `CMakeLists.txt`.
- [ ] `cmake-lint -c` takes one or more values and swallows the following file paths ("files scanned: 0", exit 0). `cscmake-cmake-template` passes `-c` last; keep that in mind for any other cmake-lint invocation.

### Phase 3 plan (agreed 2026-11-09)
Breaking change, **no deprecation aliases**: old names are removed, a `MIGRATION.md` (old → new table for functions,
variables, properties, preset environment variables, default targets) guides the migration of the projects.
- **Branching**: csCMake `feature/productize` (from `dev`), one commit per sub-phase, review stop after each. Test bed:
  csfoundation (`workspace/`: csCMake, csCore, csCamera, csLie, csVisOpenGL; standalone layout) on `feature/productize`
  in each repo. When validated: merge (no squash) into `dev`, then migrate the other projects.
- **CI on feature branches**: `ci.yml` / `smoke.yml` also run on push to `feature/**` (added 2026-11-09: manual
  dispatch is only offered for workflows present on the default branch `main`, which has none). **Remove the
  `feature/**` trigger when `feature/productize` is merged into `dev`** (or make `dev` the default branch and rely on
  `workflow_dispatch`).
- **3a — Naming and API surface** (behaviour unchanged, smoke results identical):
  - API classification (details reviewed together): *user* (initialize/finalize, add_library/executable,
    target_sources/link_libraries, find_package, install_target, quality helpers, generate folders), *advanced*
    (`cs_get_*`/`cs_print_*` introspection), *private* (`_cs_*`, everything else).
  - Functions → `cs_snake_case` / `_cs_snake_case`, no aliases (`csUseOpenMPOnTarget`, `cs_compileEachInstalledInclude`,
    `csGetConfigurationWithStrictFlags`, `_csPopulateTargetDependencies`, `_csCheckPathExistsAndAddToTargetProperty`,
    `_csSetConfigurationWithStrictFlags`; internal ones with public names → `_cs_`).
  - One prefix everywhere: `CSCMAKE_` for cache/normal/environment/preset variables (`CS_CMAKE_*`, `WORKSPACE_ROOT`,
    `<project>_CS_CMAKE_DEBUG`, ...) and one scheme for global/target properties (`cs*` camelCase today). Done in step 2,
    plain renames; **3b**: merge the two prefix-path mechanisms (environment `CSCMAKE_PREFIX_PATH_PREFIX/SUFFIX` read
    by the presets, CMake variables `CSCMAKE_PREFIX_PATH_HEAD/TAIL` read by `cs_initialize_project`) into one.
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
  - [x] (step 6a: compile profiles, `CLANG_TIDY` rules) `cs_target_enable_clang_tidy` never ran clang-tidy (verified 2026-11-09): the generator expression is split into
    several `set_target_properties` arguments, `CXX_CLANG_TIDY` ends up empty. Fixing it turns on `-checks=*` +
    `-warnings-as-errors=*` for every project calling it → decide the check set (e.g. a `.clang-tidy` file) and
    smoke-test it. (The include-time `FATAL_ERROR` without clang-tidy was fixed in 3m: lazy lookup.)
    History: original implementation = `FATAL_ERROR` at `include(csCMake)` on any UNIX host without clang-tidy (so it
    broke macOS and gcc-only Linux hosts) and a property that never ran it; 3m = looked up on the first call, only for
    Clang on Linux (still `FATAL_ERROR` there if missing), no-op elsewhere (as the original generator expression).
    **Wanted (user, 2026-11-09)**: configurable per build configuration, e.g. `cs_initialize_project(...
    CLANG_TIDY_ON_CONFIG Paranoid)` (or a cache variable): in those configurations clang-tidy is **mandatory**
    (`FATAL_ERROR` if not installed), in the others it is **skipped**. To design: generator expression
    `$<CONFIG:...>` in `CXX_CLANG_TIDY` (check the CMake version supporting it), lookup at configure time when any
    selected configuration is in the build (multi-config generators), which compilers (Clang only, or any compiler
    with clang-tidy + compile_commands), the check set (`.clang-tidy`), smoke coverage.
  - `CMAKE_SOURCE_DIR` used for the relative install paths of headers (wrong when the csCMake project is itself a
    subproject) → the source dir of `cs_initialize_project`, stored in a global property. **Not** `PROJECT_SOURCE_DIR`:
    csfoundation subdirectories call `project()` again (`project(core ...)`), which would change the install layout;
  - csCMake-owned cache variables not `FORCE`d (user `-D` honoured); `FORCE` only where csCMake must own the value
    (`CMAKE_CONFIGURATION_TYPES`), documented;
  - `cs_initialize_project(<name>)`: `FATAL_ERROR` if `<name>` differs from `PROJECT_NAME`; stays a macro, no leaked
    variables;
  - `cs_finalize_target` **mandatory**: `cs_finalize_project` fails listing unfinalized targets and targets whose link
    properties changed after finalization; a `cmake_language(DEFER)` check fails if `cs_finalize_project` is not called;
  - verbosity policy (no forced STATUS lines per call), silent skips → `WARNING`; with it, re-enable lint `C0301`
    (49 long lines, all string literals): `cs_debug_message(<text>...)` joining its arguments like `message()` makes them
    splittable. `C0307` stays disabled: cmake-format and cmake-lint disagree on continuation indentation (2 findings),
    the formatter is the authority on layout;
  - generated Config: namespaced variables (no `COMPONENT`, `${COMPONENT}_DEPENDENT_EXPORTS` clashes), the
    `@EXPORT_NAMESPACE_SANITIZED@` TODO, `<Pkg>_FOUND`/`OPTIONAL_COMPONENTS` semantics instead of `FATAL_ERROR`;
  - `cmake_minimum_required` in `csCMake.cmake` → version check (3.31, presets v10);
  - `cs_finalize_project` fails when `project()` has no `VERSION` (`write_basic_package_version_file`): clear error
    from `cs_initialize_project`, or a default version (found by the 3b configure tests);
  - [x] (step 5) **nested csCMake projects** (a lib project `add_subdirectory`-ed into a target project): fails today
    (`duplicated element Debug`, verified 2026-11-09: all state is in global properties). Current project tracked by a
    variable set in `cs_initialize_project` (inherited by subdirectories, not tied to `PROJECT_NAME`); targets,
    components and dependency data keyed by project; each `cs_finalize_project` installs only its own components;
    build configurations shared by the build tree (nested project checks compatibility, rule to decide); links to a
    target of another csCMake project of the same build → `find_dependency(<ns> COMPONENTS ...)` in the Config
    (design together); smoke test with a nested project;
    internal names keyed by namespace: CMake export sets are global to the build tree, so two projects with a
    component of the same name (e.g. `cscmake_common`, `core`) would clash on `<component>-targets` and on the
    `CSCMAKE_COMPONENT_<component>_*` properties → `<namespace>_<component>-targets` and
    `CSCMAKE_<namespace>_COMPONENT_<component>_*`, installed file and component name unchanged (`<component>`);
  - `cs_initialize_project` signature vs cmake-lint `E1122` (duplicate keyword): `DEFAULT_CONFIG Debug Release` (one
    multi-value keyword) is lint-clean, but several mapped/custom configurations repeat the `DEFAULT_CONFIG_MAPPED x
    MAPPED_TO y` / `CUSTOM_CONFIG x BASED_ON y POSTFIX z` groups → E1122 in consumer projects. Redesign the
    configuration arguments (e.g. one group per keyword value, or a separate `cs_add_build_configuration(...)` call per
    configuration);
  - from the former Phase 4: static MSVC runtime option, split `cs_finalize_project`, configurable csCMake location;
  - double-check (likely a non-issue, prove with a test): `cs_target_link_libraries` scope keywords.
- **Chained-projects smoke test** (added before the renames, kept green through 3a/3b): mirror the csfoundation chain
  (csCore → csCamera → csImgTracker): `<X>Sol` top projects with a subproject named like the package, namespace ≠
  project name, default targets linked, components depending on each other, a third project consuming two packages.
  In 3b add two packages with the same component name (fails today: the generated Config sets
  `${COMPONENT}_DEPENDENT_EXPORTS` globally, which is why csfoundation names components `csCameraAssert`, `<P>Sol_csCMakeCommon`, ...).
- **3c — In-source docs**: CMake's own documentation format: reStructuredText in `#.rst:` blocks of the modules
  (`command`, `variable`, `prop_tgt`, `prop_gbl` with `:Reads:` / `:Writes:` fields), built by Sphinx
  (`sphinxcontrib-moderncmakedomain`, MyST pages) into the reference: commands, variables, properties; `docs.yml`
  builds it on every push (artifact) and publishes it on GitHub Pages from `main`.
- **3d — Docs** (Sphinx site, pages in MyST Markdown readable on GitHub too, diagrams in Mermaid; every user page links
  its "under the hood" advanced page and vice versa), in reviewable steps:
  1. skeleton (Mermaid support, sections) + "Contributing to the documentation" (`docs/contributing/documentation.md`);
  2. user guide `docs/user/`: getting started (wiring csCMake: sibling / standalone / environment layouts, first
     project), targets and sources, dependencies (`cs_find_package`, nested projects), install and components, build
     configurations, compile profiles (with the tiers recipe: core / app / sample), presets, troubleshooting;
  3. tutorials = the smoke projects (`tests/smoke/README.md` moves to an advanced page, snippets taken from them);
  4. advanced `docs/advanced/`: concepts and lifecycle (initialize → targets → finalize, deferred checks), target
     tracking and runtime dependencies, install/export and the generated Config, presets internals (generator,
     registry, layouts), extending csCMake, conventions; "Formatting your CMake files" (consumers reuse the `cs_*`
     signatures: cmake-format only finds `.cmake-format.*` in parent folders, csCMake is a sibling);
  5. reference completeness: an argument list for every command with arguments (most have only the signature);
  6. `README.md` slimmed to pitch, quickstart and map (links to the docs), `AGENTS.md`, `MIGRATION.md` reviewed.
- **3d+ — The docs explain themselves** (user): the documentation (a "Contributing to the docs" page, linked from the
  README) tells well how to build it (command line, VS Code task, CI artifact, Pages), how to document a module /
  command / variable / property (the `#.rst:` format with a full example, the roles, the 2-space continuation of
  fields, what is internal), how to add a page (MyST, toctree), how to update the CMake inventory, and how the docs CI
  and publishing work. CLAUDE.md keeps the short rules and links to it.
- **Versioned documentation**: decided (user): each release tag publishes its documentation with the release (see
  Phase 5 "Release package"); GitHub Pages shows the docs of `main`.
- **3e — Doc checks** (done): references and anchors: `sphinx-build -W -n` (in `docs.yml`); completeness:
  `cscmake-check-docs` (pre-commit hook, so also CI): every public `cs_*` has its `.. command::` block, every csCMake
  variable / property used in the code has an entry and every entry is used, every documented module has its page.
  Tutorial snippets equal the smoke files by construction (`literalinclude`).
- **3m — macOS** (early, right after 3a step 1, so the smoke tests find the macOS issues before 3b hardening and the
  docs): the registry has stubs only (`OS.MACOS`, `Compiler.APPLE_CLANG` + short `ac`, presets `cs-host-macos`,
  `cs-compiler-macos-appleclang-default`; `get_supported_os_version_list(OS.MACOS)` returns `[]`, "TODO add MACOS").
  - registry (decided 2026-11-09): **arm64 only** (no Intel Macs sold since 2023, macOS 27 is Apple Silicon only;
    x64 can be added later as extra variants); macOS versions = the two most recent GitHub arm64 images at
    implementation time (probably `macos15`, `macos26`; prefix like `ubuntu`); Apple Clang `default`; **three
    generators**: Ninja, Ninja Multi-Config and **Xcode** (new `Generator.XCODE`, multi-config, short form to define,
    `cs-generator-xcode` preset) → 2 versions × 3 generators = 6 variants (26 smoke jobs); short forms
    (`short_os_version`); new variant ids are added, existing ids/presets stay byte-identical; tests (incl.
    `registry.py` coverage of the `MACOS` branches).
  - presets: host/compiler/generator presets for macOS (check what `presets/common` already has), regenerate.
  - CI: `ci_matrix.py` runner labels (e.g. `macos-15`, `macos-26`; check the runner-images list), Ninja on the macOS
    images (install step if missing), Xcode selected by the image, smoke on all macOS variants.
  - expected csCMake issues (fix in 3b, or here if they block): `csClangTidy.cmake` `FATAL_ERROR` at include on UNIX
    without clang-tidy (macOS has none by default), `.dylib`/RPATH of installed shared libraries, install-time
    paths, sanitizer flags of the strict config with Apple Clang; Xcode generator: per-configuration output folders
    and postfixes of custom configurations (Paranoid), `$<CONFIG>` install include folders.
- **3f — Validation** (done): csfoundation (csCore, csLie, csCamera, csVisOpenGL) and third_party_base_libs (12 forks,
  release `v0.1.0-rc4`) migrated on `feature/productize`, CI green; merged into `dev`. Other projects (csqt6, ...):
  later, one by one (optional `cscmake-migrate` search/replace helper from the `MIGRATION.md` table, to decide).

### Phase 2 plan (agreed 2026-11-09)
- **Smoke projects** in `tests/smoke/` (consumers of csCMake through the presets, exactly like real projects):
  - `hello/` (export namespace `csSmoke`): `cs_initialize_project` with Debug, Release, RelWithDebInfo (mapped) and Paranoid (custom) configs; static lib `hellolib` (`hello_lib()` prints `hello-lib`); executable `helloapp` (calls it, prints `hello-app`); ctest: unit test of the lib + run of `helloapp` with output regex `hello-lib.*hello-app`; installed with `cs_install_target` + `cs_finalize_project(csSmoke)`.
  - `consumer/`: separate project, `find_package(csSmoke COMPONENTS hellolib REQUIRED)` from the install folder, links `csSmoke::hellolib`, ctest checks its output. Proves the installed `csSmokeConfig.cmake`.
- **Driver** `tests/smoke/run_smoke.py` (stdlib only), used by CI and by a local pytest: lays out csCMake + `hello` + `consumer` as siblings (the presets expect `${sourceParentDir}/csCMake`), runs `cmake --workflow` (multi-config: `debug-release-relWithDebInfo-paranoid`; single-config: one workflow per config), runs the **installed** `helloapp` of each config (install layout + postfixes), builds/tests the consumer, runs cmake-lint on the installed `csSmokeConfig.cmake`.
- **CI** `.github/workflows/smoke.yml`, separate from `ci.yml`: a `matrix` job prints the matrix JSON from the registry (`tests/smoke/ci_matrix.py`: variant → generator type + runner label, e.g. `ubuntu-24.04-arm`, `windows-2025-vs2026`), the `smoke` job uses `fromJSON` → all **20** variants × **4** configs. CMake/Ninja from the runner images (as csfoundation/csorchestrator do); add a setup action only if a runner turns out too old.
- **Local**: `tests/smoke/test_run_smoke.py` runs the driver for the host variants, marked `slow` + `requires("cmake")` via a new `conftest.py` (`--run-all`).

### Phase 2 — not covered by the smoke projects (trace for full completion)
- [x] (4c) Shared libraries: `csSmokeShared` (two SHARED libraries, `CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS`, installed app run on every variant); runtime dependency analysis and VS debugger PATH: configure tests `tests/cmake/test_target_dependencies.py`.
- [x] INTERFACE / header-only libraries (`csSmokeBase`).
- [x] Several components with dependencies between exports (`csSmokeBase`, `test_package_config.py`); cyclic dependency detection (4c: `test_cyclic_dependency_between_components`).
- [x] `cs_find_package` PUBLIC propagation into the installed Config (`find_dependency`): `run_smoke.py` checks every Config.
- [x] (replaced in Phase 3 by compile profiles, `cs_target_check_installed_headers`, `cscmake_clang_tidy`: covered by `csSmokeBase`) `STRICT_COMPILATION_ON_CONFIG`, `cs_compileEachInstalledInclude`, `cs_exec_clang_tidy`; `cs_target_use_openmp`: not covered (needs OpenMP on every runner).
- [x] `csCMakeProjectSetup-default-standalone.json` and `-shortBuildPath.json` setups → preset layouts `standalone-short`, `sibling-short`, `env` in the smoke tests (3b step 6d).
- [x] (4c) A consumer that does not use csCMake: `csSmokePlainConsumer`.
- [x] macOS: Phase 3 step "3m — macOS".

### Findings while writing the docs (3d step 4, to decide)
- [x] (fixed, `252eed2`: `@{osVersion}`) **Preset display names**: `presets/template/cs-single-config-generator-config.json.template` hard-coded
  `Ubuntu 24.04` in the `displayName` / `description` of every single-config preset (Windows Ninja, macOS Ninja, every
  Ubuntu version: `cmake --list-presets` shows "Configure macos Ubuntu 24.04 ..."). Names and ids are not affected; the
  fix (`@{osVersion}` or the host description) changes the generated files.
- [x] (fixed, `f95e2eb`: `PATH=<folders>;%PATH%`, nothing set without runtime libraries) **Visual Studio debugger `PATH`**: `_cs_set_vs_debugger_env_variable` set `PATH=<folders of the runtime
  libraries>` without `;%PATH%` (or `$(Path)`): check on Windows whether the debugged program loses the system `PATH`.

### Compile profiles and clang-tidy: ideas (future)
Guiding constraint (user): configurability per kind of project and per part of a project: a core library is stricter
than an application, a sample or a standalone tool; tests and samples inside a project may be looser than its library.
- [ ] **Tiers** composed from the shipped profiles, chosen with `DEFAULT_COMPILE_PROFILES`: e.g. `cscmake_tier_core`
  (strict warnings, hardening in debug configurations, UBSan + ASan and clang-tidy in a paranoid configuration),
  `cscmake_tier_app` (warnings as errors, sanitizers on request), `cscmake_tier_sample` (warnings, no `-Werror`).
  Configuration names are project-defined, so tiers need the configurations as a parameter (e.g. a helper
  `cs_add_compile_profile_tier(<name> CORE PARANOID_CONFIGS Paranoid)`) or stay documented recipes.
- [x] **Per directory**: `CSCMAKE_DEFAULT_COMPILE_PROFILES` is a directory variable read at `cs_finalize_target`, so a
  `samples/` or `tests/` folder `set()`s its own defaults: tested (`test_a_folder_sets_its_own_default_profiles`) and
  documented (user guide, compile profiles); a named helper not needed so far.
- [ ] **Per target exceptions**: `cs_target_exclude_compile_profiles(<target> <profile>...)` (vendored or generated
  code); generated sources (Qt `moc`/`uic`) marked `SKIP_LINTING` (CMake 3.27) so clang-tidy skips them.
- [ ] **`.clang-tidy` tiers** shipped as recommendations (later in the copier template): core (bugprone, cert,
  cppcoreguidelines subset, modernize, performance, readability subset, `WarningsAsErrors: '*'`), app (lighter), sample
  (minimal); a sub-folder `.clang-tidy` with `InheritParentConfig: true` relaxes tests / samples.
- [ ] **More profiles**: `cscmake_conformance` (MSVC `/Zc:preprocessor /utf-8 /permissive-`), `cscmake_hardening_release`
  (`-D_FORTIFY_SOURCE=3 -fstack-protector-strong -fcf-protection`, MSVC `/sdl /guard:cf`), `cscmake_sanitize_thread`,
  `cscmake_sanitize_undefined_fatal` (`-fno-sanitize-recover=all`: tests fail on UB), `cscmake_coverage` (`--coverage`,
  Clang source-based coverage) for a Coverage configuration.
- [ ] **More warnings, opt-in** (noisy or style): `-Wcast-qual -Wextra-semi -Wundef -Wredundant-decls -Wsuggest-override`,
  GCC `-Wuseless-cast`; MSVC `/w14287 /we4289 /w14545 /w14546 /w14547 /w14549 /w14555 /w14619`.
- [ ] **Other analyzers** as rule fields like `CLANG_TIDY`: `CPPCHECK` (`<LANG>_CPPCHECK`), `IWYU`
  (`<LANG>_INCLUDE_WHAT_YOU_USE`); clang-tidy fixes export (`<LANG>_CLANG_TIDY_EXPORT_FIXES_DIR`).
- [ ] **Warnings from dependencies**: the targets of a nested csCMake project (same build) are not `SYSTEM`, so its headers
  trigger the strict warnings of the outer project → mark them `SYSTEM` for consumers (target property, CMake 3.25).
- [ ] **MSVC ASan**: the ASan runtime DLLs must be on the debugger `PATH` (Visual Studio debugger environment).

### Side-effect assessment (Phase 4 step 4f, user 2026-11-10)
Rule (CLAUDE.md, `docs/contributing/code.md` "No hidden side effects"): csCMake changes only what its own targets need
or what the user asks; target properties of csCMake targets first, then directory / project variables, then global or
cache settings; no build behaviour in the presets. Found with the install RPATH: a value in the host presets would have
replaced OpenCV's `ocv_update(CMAKE_INSTALL_RPATH ...)` default without any sign.
- [x] (4f) Review every setting wider than a csCMake target: for each, who it reaches (csCMake targets, every target of the
  project folder including third-party projects added with `add_subdirectory` / `FetchContent`, the nested csCMake
  projects, the consumers of the installed package, the projects using the presets without csCMake), whether a value
  set by the project wins, whether it is documented and can be turned off; then keep (documented), narrow (target
  property in `cs_finalize_target` / `cs_add_*`), or make opt-in. Candidates (inventory 2026-11-10):
  - `cs_initialize_project` (project scope, reach the third-party targets of the folder too):
    `CMAKE_RUNTIME/LIBRARY/ARCHIVE_OUTPUT_DIRECTORY` (+ `_<CUSTOM>`), `CMAKE_CXX_STANDARD` / `_REQUIRED` /
    `CMAKE_CXX_EXTENSIONS` (overwritten even if the project set them?), `CMAKE_PREFIX_PATH` / `CMAKE_MODULE_PATH`
    (HEAD/TAIL), `enable_testing()`, `CMAKE_EXPORT_COMPILE_COMMANDS` (Ninja);
  - build configurations: `CMAKE_CONFIGURATION_TYPES`, `CMAKE_MAP_IMPORTED_CONFIG_<CONFIG>` (every imported target of
    the folder), the copied `CMAKE_<LANG>_FLAGS_<CUSTOM>` / linker flags cache entries, `CMAKE_MSVC_RUNTIME_LIBRARY`
    (the fallback for targets not created by `cs_add_*`: third-party targets of the folder get the csCMake runtime);
  - presets (`presets/common`, `csCMakeProjectSetup.json`): `CMAKE_C_COMPILER` / `CMAKE_CXX_COMPILER`,
    `CMAKE_BUILD_TYPE`, `CMAKE_PREFIX_PATH`, `CMAKE_MODULE_PATH`, the `CSCMAKE_*` path variables, install and build
    folders, generator toolsets and architectures (`config-generators.json`): check none is build behaviour;
  - the installed `<namespace>Config.cmake`: what it defines in the consumer's scope (functions / macros prefixed by the
    sanitized namespace, variables; `test_no_variable_leaks_into_the_consumer` covers the variables);
  - compile profiles: `PRIVATE` options only (consumers unaffected), `INTERFACE` link options of static libraries
    (sanitizer runtime): documented.
- [x] (4f: `test_the_choices_of_the_project_win`, `test_the_debug_option_of_a_package_adds_no_cache_entry`; output folders: `test_defaults_can_be_overridden_from_the_command_line`) For each kept global setting: a configure test that a value set by the project before `cs_initialize_project` (or
  per target) wins, where it should.
- Assessment (2026-11-10), every setting wider than a csCMake target. Reach: **F** = every target of the project folder
  and its sub-folders (third-party projects added with `add_subdirectory` / `FetchContent` included), **B** = the
  whole build tree, **C** = the consumers of the installed package.

  | Setting | Reach | Asked by the user? | Project value wins? | Verdict |
  |---|---|---|---|---|
  | output folders `CMAKE_{RUNTIME,LIBRARY,ARCHIVE}_OUTPUT_DIRECTORY` (+ `_<CUSTOM>`) | F | no | yes (`if(NOT ...)`) | keep: needed on Windows (DLLs next to the executables of the folder); document the reach |
  | `CMAKE_CXX_STANDARD` | F | yes (`CXX_STANDARD`) | n/a | keep |
  | `CMAKE_CXX_STANDARD_REQUIRED ON`, `CMAKE_CXX_EXTENSIONS OFF` | F | no | **no** (overwritten) | **change**: only if not defined |
  | `CMAKE_EXPORT_COMPILE_COMMANDS ON` (Ninja) | F | no | **no** (a normal variable hides `-D...=OFF`) | **change**: only if not defined |
  | `CMAKE_PREFIX_PATH` / `CMAKE_MODULE_PATH` + HEAD / TAIL | F | yes (`CSCMAKE_*_HEAD/TAIL`) | yes (appended around) | keep |
  | `enable_testing()` | F | no | n/a | keep (csCMake projects have tests); document |
  | `CMAKE_CONFIGURATION_TYPES` (cache, FORCE) | B | yes (the configurations) | no, by design ("owned by csCMake", documented) | keep |
  | `CMAKE_MAP_IMPORTED_CONFIG_<CONFIG>` | F | yes (`MAPPED_TO`, `BASED_ON`) | n/a | keep: every imported target needs the mapping for custom configurations; document the reach |
  | copied `<per-config variable>_<CUSTOM>` cache entries | B | yes (`CUSTOM_CONFIG`) | yes (no FORCE) | keep |
  | `CMAKE_MSVC_RUNTIME_LIBRARY` (fallback) | F | no | **no** | keep: every target of a build must use the same MSVC runtime to link; document the reach and that `CSCMAKE_MSVC_RUNTIME_LIBRARY_<CONFIG>` is the knob |
  | presets: compilers, generator, toolset / architecture, `CMAKE_BUILD_TYPE`, folders, search paths, test output | every project using them | yes (choosing a preset) | yes (project setup preset first in `inherits`) | keep: no build behaviour (4c reverted the install RPATH there, 4d rejected `unusedCli`) |
  | Config: `option(<ns>_DEBUG ...)` | C | no | n/a | **change**: a cache entry in every consumer; read `<ns>_DEBUG` as a plain variable (`-D<ns>_DEBUG=ON` still works) |
  | Config: `<ns>_debug_message`, `<ns>_find_dependency_for_component`, `<ns>_*` variables | C | no | n/a | keep: prefixed by the namespace, temporaries unset (`test_no_variable_leaks_into_the_consumer`) |
  | compile profiles | csCMake targets | yes | per target | keep: `PRIVATE`; the `INTERFACE` link options of static libraries are their link requirements (documented) |
  | install RPATH (4c) | csCMake targets | default, `OFF` | yes | keep |
- Done (user: all): the three changes above (`CMAKE_CXX_STANDARD_REQUIRED` / `CMAKE_CXX_EXTENSIONS` and
  `CMAKE_EXPORT_COMPILE_COMMANDS` only if not defined; no `option()` in the Config), each with a configure test that the
  project's value wins (or that the consumer has no cache entry); the lifecycle page gets the reach of each setting
  (folder, build, consumers) and the reasons for the kept ones (MSVC runtime, output folders, imported configuration
  mapping, `enable_testing`).

### Code structure assessment (Phase 4 step 4g, user 2026-11-10)
- [x] (4g, done) Re-evaluate how csCMake is divided into files and folders, and reorganise where it helps (one subject per module,
  the module named after its subject, sizes in balance). Observations (inventory 2026-11-10, `wc -l`, public commands
  per module):
  - names that do not say what is inside: `csCompileEachInstalledInclude` holds `cs_target_check_installed_headers`;
    `csPathUtils` the generated folders (`cs_get_generated_dir`, `cs_get_generated_config_dir`); `csPrintInitialState`
    `cs_print_state`; `csMSVCUtils` the Visual Studio debugger `PATH` (a use of the runtime dependencies of
    `csTargetDependencies`); `csDefaultTargets` has no public command (the base include target);
  - mixed subjects: `csAddLibraryExecutable` (303) has the target registry, `cs_finalize_target` and now the install
    RPATH (an install concern); `csInstall` (714) has the install rules, the components, their dependency graph and
    cycle check, and the generation of `<namespace>Config.cmake`; `csCMake.cmake` (369) the initialization steps;
  - the debug / print commands are spread over every module (`cs_print_*`) plus `csDebugMessage`, `csDebugUtils`,
    `csPrintInitialState`;
  - big modules: `csInstall` 714, `csBuildConfigurations` 678, `csCompileProfiles` 608, `csTargetDependencies` 550 lines;
    small ones: `csDebugMessage` 39, `csMSVCUtils` 42, `csListUtils` 45, `csOpenMP` 47;
  - folders: every module flat in `utils/` (a generic name); Python: `src/cscmake/utils/` holds a single module
    (`generate_cs_preset_variants.py`, used by `presets/`).
- Constraints: projects use `include(csCMake)` only (module include paths are internal: check the docs never promise
  more); the reference pages are one per module (`docs/reference/<module>.rst`), so renaming a module changes its URL
  (fine before 1.0, mention in CHANGELOG); `cscmake-check-docs`, the docs toctree, `.cmake-format.json`, the skill and
  CLAUDE.md name modules; import-linter layers for Python. Proposal first (target layout, moves, names), reviewed,
  then one commit per move with the installed files of the smoke projects byte-identical (as in 4b).

### Running executables: shared libraries of other packages (deferred, user 2026-11-10)
Context: how an executable finds its shared libraries, per platform (user doc: `docs/advanced/runtime-dependencies.md`,
"Running the executables"):
- Linux: `RUNPATH` of the binary (not transitive: each library needs its own), then `LD_LIBRARY_PATH`, then the system.
  macOS: libraries have an id (`@rpath/libX.dylib` with CMake's defaults), executables `LC_RPATH` entries;
  `DYLD_LIBRARY_PATH` is stripped for many processes (SIP), so it is not a reliable fallback. Windows: no RPATH; the
  executable's folder, the system, then `PATH`.
- Build folder: CMake writes the absolute folders of every linked library (Linux / macOS): runs. Windows: the project's
  DLLs share `<build>/bin[/<config>]`; other packages' DLLs only in the Visual Studio debugger (`VS_DEBUGGER_ENVIRONMENT`).
- Install folder (4c): `cs_finalize_target` sets the `INSTALL_RPATH` target property of the csCMake executables
  (`$ORIGIN/<bin to lib>`) and shared / module libraries (`$ORIGIN`; `@loader_path` on macOS), unless the target has
  its own or `CSCMAKE_INSTALL_RPATH` / `INSTALL_RPATH OFF`: a package's own executables and libraries run, relocatable
  (needed by csorchestrator bundles, built on one CI and unpacked elsewhere). `CMAKE_INSTALL_RPATH_USE_LINK_PATH`
  rejected: absolute paths of the CI machine, useless after download. Not in the presets (user, 2026-11-10): projects
  using the presets without csCMake (OpenCV, the forks) keep their upstream behaviour (OpenCV's
  `ocv_update(CMAKE_INSTALL_RPATH ...)` sets it only if not defined, so a preset value would silently replace it).
- Evidence (2026-11-10, csImgTracker workspace, Linux): the build-tree `csImgTracker` has a `RUNPATH` with the absolute
  `workspace/libs/<variant>/opencv/lib` and `qt6/lib` and runs; the installed one has none: `libopencv_*.so.500 => not
  found`, and Qt resolves to the **system** `libQt6Core` (wrong version). The downloaded OpenCV libraries have
  `RUNPATH $ORIGIN` (they find each other).

To do when the applications are migrated (csImgTracker, csSkiTracker):
- [ ] **Deploy an application with its dependencies** (situation "final application"): e.g.
  `cs_install_runtime_dependencies(<app> [DIRECTORIES ...] [PRE_EXCLUDE_REGEXES ...])`, with CMake's
  `install(RUNTIME_DEPENDENCY_SET ...)` / `install(IMPORTED_RUNTIME_ARTIFACTS ...)` (3.21+): copy the shared libraries of
  the other packages (`libs/`, `install/`) into the app's `lib/` (Linux, macOS) or `bin/` (Windows); with the install
  RPATH of 4c the installed app then runs anywhere. Exclude the system libraries. Inputs: csCMake already knows the
  runtime libraries per configuration (`cs_get_target_runtime_libraries`). Qt: plugins (platform, image formats) need
  Qt's deploy script (`qt_generate_deploy_app_script`) or `windeployqt` / `macdeployqt`. Smoke: an app using
  csSmokeShared from another package, installed with its dependencies and run.
- [ ] **Windows build folder outside Visual Studio** (ctest, a terminal, VS Code): the DLLs of other packages need
  `PATH`. Options: tests get `ENVIRONMENT_MODIFICATION PATH=path_list_prepend:<folders>` (the folders csCMake computes
  for the debugger; csCMake does not wrap `add_test`, so a helper or a step of `cs_finalize_project` over the tests of
  the project); the run scripts below; or copying `$<TARGET_RUNTIME_DLLS>` next to the executables (what
  `csSmokePlainConsumer` does, plain CMake).
- [ ] **Run scripts** (see "Run scripts (future)"): `<build>/run/<target>-<config>.sh|.bat` setting
  `LD_LIBRARY_PATH` / `PATH` from `CSCMAKE_RUNTIME_LIBRARIES_<CONFIG>`: also the interim answer for installed apps that
  use other packages' libraries, until the deployment command exists.

### Open after Phase 3
- [ ] Other projects still on the v0.1.0 presets (found 2026-11-10): csopencvcpu (and probably csopencvcuda): the
  OpenCV fork's `csCMakeProjectSetup.json` includes `presets/csCMakeProjectSetup-base.json` and inherits
  `cscmake-project-setup-base` (gone in v0.2.0: `presets/csCMakeProjectSetup.json`, `cscmake-common-project-setup`, the
  `CSCMAKE_*` environment, MIGRATION.md "Project setup presets"); csqt6 (its release is used by csfoundation; Qt itself
  is built by its `configure`, check what else uses csCMake).
- [ ] When csfoundation is on `dev` with the third_party_base_libs release built from `dev` (`v0.1.0-rc5`): delete the
  `feature/productize` branches, remote and local, in csCMake, csfoundation, csCore, csLie, csCamera, csVisOpenGL,
  third_party_base_libs and its 12 forks (user).

### Phase 5 — Release package (agreed)
A `release` workflow on `v*.*.*` tags: after `ci`, `smoke` and `docs` pass for the tag, create the GitHub Release of
the tag with, as assets:
- `csCMake-<version>.tar.gz` / `.zip`: what a consumer needs (`csCMake.cmake`, `utils/`, `templates/`,
  `presets/`; no tests, no Python sources), unpacked as a `csCMake/` folder (the sibling layout of the presets);
- `csCMake-docs-<version>.zip`: the built documentation of the tag (durable: build artifacts expire after 90 days);
- release notes from the CHANGELOG section of the version.
Decided (user, 2026-11-10): version **v0.2.0** (v1.0.0 when more projects are on the API); `release.yml` calls
`ci`, `smoke`, `docs` as reusable workflows (they drop their own tag trigger), then `publish`; `SHA256SUMS`; the Python
package is not released; pre-release tags are GitHub pre-releases.

### Run scripts (future)
- [ ] Per-target scripts to run an executable from a terminal with its runtime `PATH`: at the end of
  `cs_finalize_project`, `file(GENERATE)` `<build>/run/<target>-$<CONFIG>.bat` / `.sh` from the target property
  `CSCMAKE_RUNTIME_LIBRARIES_<CONFIG>` (folders of the DLLs, as for the Visual Studio debugger environment); maybe also
  VS Code launch environments. No cache variable needed (derived per configure).

### Project template with copier (future)
- [ ] Consumer project scaffolding with copier (`copier copy` / `copier update`): `CMakePresets.json`,
  `csCMakeProjectSetup.json`, top `CMakeLists.txt` (`cs_initialize_project(NAMESPACE ...)`), pre-commit config,
  cmake-format/lint style. Split ownership: the **style policy** (line width, anchored lint patterns, disabled codes) in
  the template repository (csCMake itself could take it via `copier update`); the **`cs_*` command signatures** stay in
  csCMake (versioned with the API), e.g. `cmake-format/cscmake-commands.py`, loaded by the template's
  `.cmake-format.py` from the csCMake checkout (two files: no merge conflicts on `copier update`; `.py` allows comments,
  JSON does not).

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
| 3 | done | Signed off 2026-11-10. Productize (3a, 3m, 3b, 3c, 3d, 3e, 3f) on `feature/productize`, merged into `dev` (`--no-ff`); validated on csfoundation and third_party_base_libs (CI green, release `v0.1.0-rc4`). Pages: Settings → Pages → Source "GitHub Actions" (user), publishes from `main`. |
| 4 | in progress | Internal quality (non-breaking) on `dev`: 4a done (`f71995c`), 4b done (`00093d7`), 4c done (`9037b82`, pushed), 4d done (`05050d9`), 4e done (decision: gersemi + own linter, step 4h); 4f done (side-effect assessment), 4g done (modules/ reorganisation); next 4h (gersemi + `cscmake-lint`). |
| 5 | in progress | v0.2.0: step 1 (release tool, workflow, CHANGELOG, docs) under review; then merge `dev` into `main`, tag. |

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

### 2026-11-09 (Phase 3a step 1 — function renames)
- 37 functions renamed to `cs_snake_case` / `_cs_snake_case` (case-insensitive replacement: some calls were written in
  lowercase), no aliases; `cs_target_*` for functions acting on a target; "export" → "component" in the
  introspection and internal names; internal functions with public names moved to `_cs_`. Map applied to the CMake
  sources, the smoke projects, README.md, the skill and the smoke README (not to PLAN.md history).
- `MIGRATION.md` started (functions; variables, properties, default targets/namespace to come).
- Local: `pytest --run-all` 49 passed (4 host variants).

### 2026-11-09 (Phase 3m — macOS and Ubuntu 26.04 variants)
- GitHub runner images checked (runner-images README): arm64 `macos-15` (Xcode 16.4 default), `macos-26`
  (= `macos-latest`, Xcode 26.6), both with CMake 4.4.5 and Ninja 1.13.2, no clang-tidy; macOS 14 retired 2026-11-02.
- Registry: `MacOSVersions` (`macos15`, `macos26`), arm64 only, Apple Clang, `Generator.XCODE` (multi-config, short
  `xc`), Ninja / Ninja Multi-Config / Xcode → 6 new variants (26 total); short OS version `m15`/`m26`.
  `presets/common/config-generators.json`: `cs-generator-xcode` (+ arm64 architecture placeholder). Regenerated: 36
  new files, existing presets unchanged (5 files with additions only).
- `ci_matrix.py`: `macos<version>` → `macos-<version>` runner. Tests: 26 variants, macOS ids/arch/generator types,
  short forms, Xcode-only without Ninja.
- `csClangTidy.cmake`: clang-tidy looked up on the first `cs_target_enable_clang_tidy` call and only for Clang on
  Linux (was: `FATAL_ERROR` at `include(csCMake)` on any UNIX host without clang-tidy, e.g. macOS). Found while
  checking: the function never set `CXX_CLANG_TIDY` (see 3b).
- Ubuntu 26.04 added like 22.04 / 24.04 (user request): GitHub `ubuntu-26.04` / `ubuntu-26.04-arm` are GA (gcc 15.2,
  clang + clang-tidy 20/21/22, CMake 4.4.5, Ninja 1.13.2) → 8 variants (gcc/clang × Ninja/Ninja Multi-Config ×
  x64/arm64). Total 34 variants (34 smoke jobs); regenerated presets: additions only.
- Fix after the first GitHub run (Xcode variants): `cs_target_check_installed_headers` generated its `.cpp` files in
  `gen-$<CONFIG>/`, so the sources of the header-check targets varied by configuration, which the Xcode generator
  rejects ("has source files which vary by configuration"). The content is the same in every configuration: written
  once in the shared `gen/` folder (`file(GENERATE)` accepts the same output for all configurations).
- Second fix (Windows clang-cl smoke after the first fix): `cscmake_base_include` publishes `gen/` and `gen-<Config>/`
  as include folders but csCMake never created them; `gen-<Config>/` only existed because the header check wrote its
  files there. clang-cl reports the missing folder (`-Wmissing-include-dirs`, an error with the strict options):
  `_cs_target_base_project_include_dir` now creates them at configure time.
- Not run locally (no Mac, host is Ubuntu 24.04): the macOS and Ubuntu 26.04 smoke jobs on GitHub are the first real
  test.

### 2026-11-09 (Phase 3a step 2 — variables and properties renamed)
- `CS_CMAKE_*` → `CSCMAKE_*`, `WORKSPACE_ROOT` → `CSCMAKE_WORKSPACE_ROOT`, `<project>_CS_CMAKE_DEBUG` →
  `<project>_CSCMAKE_DEBUG` (CMake code, hand-written and template presets, regenerated presets: environment names only,
  preset ids unchanged).
- Global and target properties `cs*` → `CSCMAKE_*` (component terminology); per-configuration target properties use
  the configuration in upper case (`CSCMAKE_RUNTIME_LIBRARIES_<CONFIG>`, the getters upper-case their argument).
- Caught by the smoke tests: the property regex also renamed the module path `include(utils/csTargetDependencies)`.
- `MIGRATION.md`: variables and properties tables. Local: `pytest --run-all` 56 passed (4 host variants).

### 2026-11-09 (Phase 3a step 3 — namespace in cs_initialize_project, default targets)
- `cs_initialize_project(NAMESPACE <ns> CXX_STANDARD ...)` (the positional project name is gone; an old call fails with
  a hint to `MIGRATION.md`), `cs_finalize_project()` without argument (same), `cs_get_namespace()`. The namespace is the variable
  `CSCMAKE_NAMESPACE` (directory scope, inherited by subdirectories), not a global property: a nested csCMake project
  gets its own (first piece of the 3b per-project state).
- Default targets: real name `<project>_cscmake_*` (unique in the build tree), `EXPORT_NAME` `cscmake_*`, alias
  `<ns>::cscmake_*`: the same name in the build tree and installed (`cscmake_base_include`, `cscmake_compile_options`,
  `cscmake_compile_options_strict`, `cscmake_msvc_parallel_compile`, `cscmake_strict_warnings`); component
  `<ns>_cscmake_common` (keeps the namespace prefix until the generated Config variables are namespaced in 3b).
- Smoke projects migrated; `run_smoke.py` checks the installed default targets (`<ns>::cscmake_*` exactly).
  `MIGRATION.md`: namespace and default targets.

### 2026-11-09 (Phase 3a step 4 — lowercase arguments and local variables)
- Every function/macro argument and local variable of `csCMake.cmake` / `utils/*.cmake` lowercased (renamer working per
  function: `${X}` references and bare tokens, never property names after `PROPERTY`/`PROPERTIES`, the third argument
  of `get_target_property`, generator expressions, escaped `\${...}` or plain string text); `cmake_parse_arguments`
  prefix `arg` (`arg_<KEYWORD>`). Hand-fixed: `cs_target_use_openmp(target_name visibility)` (`TARGET` keyword), short
  or `_`-prefixed names (`i`→`idx`, `N`→`count`, `_values`→`values`, `_file`→`file_path`), locals only used bare
  (`*_SIZE`), the keyword lists of `_cs_parse_additional_configurations` (lowercased by the renamer, caught by the
  smoke configure).
- Config template: `@VAR@` placeholders lowercase (= the arguments of `_cs_configure_config_cmake`), template-local
  names lowercase (`component`, `component_name`, file-level `_dependent_component_list`, `_find_components_empty`).
- `.cmake-format.json`: temporary `argument_var_pattern` / `local_var_pattern` overrides removed: cmake-lint clean with
  the cmakelang defaults.
- Checks: `--warn-uninitialized` configure of csSmokeBase: no warning before or after; generated Configs differ only in
  the template-local names, installed targets files identical; `pytest --run-all` 56 passed (4 host variants).

### 2026-11-09 (Phase 3a step 5 — anchored lint patterns, cs_* signatures for cmake-format)
- `.cmake-format.json`: every cmake-lint name pattern set explicitly and anchored with `$` (cmakelang uses `re.match`:
  `csCamelCase` used to pass `[0-9a-z_]+`); fixed the two dynamic locals with an upper-case suffix
  (`target_${config_ucase}_folders_path`, ...).
- `parse.additional_commands` for the public `cs_*` commands (keywords, flags, positional counts): cmake-format lays
  out `cs_initialize_project(NAMESPACE x CXX_STANDARD 17 ...)` one keyword group per line instead of one token per line.
  Reformatted smoke projects and `utils/`: whitespace/layout only (checked token by token).
- CLAUDE.md: update the signatures with the public API; naming patterns.
- `DEFAULT_CONFIG` declared multi-value: the smoke projects and README use `DEFAULT_CONFIG Debug Release` (the
  repeated `DEFAULT_CONFIG` form is still accepted by `cs_initialize_project`, but cmake-lint reports E1122 with the
  signature; caught by the pre-commit hook: my lint check had filtered `[C...]` codes only).

### 2026-11-10 (Phase 3b step 1 — bugs)
- New `tests/cmake/`: configure-only CMake tests (pytest writes a `LANGUAGES NONE` project including csCMake,
  configures it with Ninja, reads `cstest_report(<key> <value>)`; ~0.1 s each, no compiler). Each test below fails on
  the code before the fix.
- `_cs_target_try_to_finalize`: quoted `foreach` → all but the first pending dependency were dropped, so a target
  finalized before its project dependencies existed missed their runtime libraries (`CSCMAKE_RUNTIME_LIBRARIES_<CONFIG>`,
  the Visual Studio debugger PATH). Test with two imported shared libraries, app finalized first and last.
- `cs_print_target_properties`: iterated an undefined variable (printed nothing); now `${CMAKE_COMMAND}`, `<CONFIG>`
  expanded for every configuration of the project (was `CMAKE_BUILD_TYPE`, empty with multi-config), `<LANG>` → CXX.
- `cs_print_components`: printed all components as "default".
- Messages: labels/advice naming functions that do not exist (`cs_set_default_build_config`,
  `csPrintFindPackagesForTarget`, `_csPopulatecsTargetDependencies`, ...), undefined variables
  (`${strict_compilation_on_config}`, `${custom_config}` in the mapped-config loop), "USE cs_initialize_project(...)".
- `csInstall.cmake`: `_cs_configure_config_cmake` gets the install folder as an argument (was read from the caller's
  scope), no duplicate sanitizing; unused argument of `_cs_sort_component_dependencies` removed; PDB files installed to
  `${CMAKE_INSTALL_BINDIR}` (was `bin`). Three upper-case locals missed by the step-4 renamer lowercased.
- Checked, not a bug: `cs_target_link_libraries` scope keywords (test).

### 2026-11-10 (Phase 3b step 2 — behaviour)
- `csCMake.cmake`: no `cmake_minimum_required` (it reset the including project's policies); `CMAKE_VERSION` ≥ 3.31
  check, csCMake code inside `cmake_policy(PUSH)` / `VERSION 3.31` / `POP` (functions record the policies where they
  are defined). README: CMake ≥ 3.31.
- `cs_initialize_project`: error without `project(... VERSION ...)`; temporaries `_cs_init_*` unset (no leak);
  `CSCMAKE_SOURCE_DIR` (directory variable) = base of the relative header install paths (was `CMAKE_SOURCE_DIR`, wrong
  for a csCMake project added with `add_subdirectory`); debug option `<project>_CSCMAKE_DEBUG` defined here.
- Cache policy: csCMake defaults are cache variables without `FORCE` (overridable with `-D`); values derived from the
  arguments are project-scope normal variables, set at any depth with `_cs_set_in_project_scope` and applied by the
  macro (`_cs_apply_project_scope_variables`); output folders kept if set; `CMAKE_CONFIGURATION_TYPES` stays `FORCE`.
- Messages: `cs_debug_message(<text>...)` concatenates its arguments (no "force" argument), nothing printed by default
  (44 csCMake lines per smoke configure before, 0 now); missing imported library file → `WARNING`; long strings split,
  lint `C0301` enabled (skipped only for the installed Config, which contains user-chosen names); the injected Config
  code built with `string(APPEND)` (generated text unchanged).
- Tests (`tests/cmake/test_initialize_project.py`, 8, each fails before): missing `VERSION`, no leaked variables, derived
  values not in the cache, `-D` overrides, debug option, missing imported file warning, header install path of a csCMake
  subproject. Generated Configs of the smoke chain: only the two shortened template messages differ.
- `MIGRATION.md`: behaviour tables and actions. PLAN: run scripts (future).
- Docs rule (user, 2026-11-10): comments, README, docstrings and docs describe the current behaviour only; history in
  this changelog and in commit messages, `MIGRATION.md` as old → new tables and actions (CLAUDE.md rule). Comments,
  one error message, a test docstring and the MIGRATION namespace/behaviour sections rewritten accordingly.

### 2026-11-10 (Phase 3b step 3 — generated package configuration)
- Reproduced with configure tests installing two packages (`tests/cmake/test_package_config.py`, `install()` helper:
  configure + build + install of a `LANGUAGES NONE` project): B's component `x` finds package A while B's Config loops
  on its components; A's Config overwrote `core_DEPENDENT_EXPORTS` (both have a component `core`), B then skipped
  `b_base` ("imported targets referenced but missing: B::b_base").
- Template: per-component dependency lists `<ns>_<component>_DEPENDENCIES`; loop/work variables `<ns>_*` /
  `_<ns>_*`, unset at the end (no leak, tested); unknown component → `<ns>_<component>_FOUND` FALSE, if required
  `<ns>_FOUND` FALSE + `<ns>_NOT_FOUND_MESSAGE` (`OPTIONAL_COMPONENTS`, non-required and required cases tested);
  `<ns>_<component>_FOUND` TRUE for loaded components; dependencies found once per component (namespaced list instead
  of one global flag per component); injected `find_dependency` code = one `if` block per component.
- `@PACKAGE_INIT@` not used (it expands CMake's helper macros, which fail our lint): `configure_file(@ONLY)`;
  `<ns>_BASE_DIR` = Config folder + relative path to the prefix computed at install time (`@config_dir_to_prefix@`,
  correct for any `CMAKE_INSTALL_LIBDIR`; tested).
  Computed against the build folder (fix after the Windows CI run: `file(RELATIVE_PATH)` with `/` is not an
  absolute path on Windows).
- Common component `cscmake_common` (namespace prefix dropped: Config variables are namespaced). Nested projects:
  internal export set / property names to key by namespace (step 5, user question).
- `cscmake-cmake-template`: a placeholder inside a lowercase identifier gets a lowercase stand-in
  (`_@NS@_components`), so lint naming checks apply to the template's private variables (tests).
- `MIGRATION.md`: installed package configuration table.

### 2026-11-10 (Phase 3b step 4 — mandatory finalize calls)
- `cs_finalize_target` records the target's links (`_CSCMAKE_FINALIZED_LINKS`, from `LINK_LIBRARIES` and
  `INTERFACE_LINK_LIBRARIES`; aliases resolved). `cs_finalize_project` → `_cs_check_targets_finalized`: one error
  listing the targets not finalized, one for the targets whose links changed after `cs_finalize_target`.
- `cs_initialize_project` defers `_cs_check_project_finalized(<namespace> <source dir>)` to the end of its
  `CMakeLists.txt` (`cmake_language(DEFER)`, values fixed with `EVAL`): fails without `cs_finalize_project()`
  (global property `_CSCMAKE_PROJECT_FINALIZED_<namespace>`).
- `cs_finalize_project` split: `_cs_check_targets_finalized`, `_cs_finalize_runtime_dependencies` (analysis + Visual
  Studio debugger environment), `_cs_finalize_install`.
- Tests: `tests/cmake/test_finalize.py` (complete project, target not finalized, links after finalize, missing
  `cs_finalize_project`); the existing configure tests now finalize their targets and project. README, `MIGRATION.md`
  (mandatory calls). csfoundation compliance is checked at its migration (3f).

### 2026-11-10 (Phase 3b step 5 — nested csCMake projects)
- Decisions (recommended options, user "go"): the first csCMake project of the build defines the configurations, a
  nested project uses a subset defined the same way; links between projects of the same build → automatic
  `find_dependency(<ns> COMPONENTS <component> REQUIRED CONFIG)` (no version); configure tests (no smoke project).
- Configurations: definitions recorded per configuration (`CSCMAKE_BUILD_CONFIGURATION_<config>_DEFINITION`:
  `default`, `mapped <fallbacks>`, `custom <base and fallbacks> postfix <postfix>`); a nested `cs_initialize_project`
  checks its configurations against them (`_cs_check_build_configuration`) and registers nothing; same
  `STRICT_COMPILATION_ON_CONFIG` if given; per-config variable list computed once per build tree.
- Per-project state keyed by namespace: `CSCMAKE_<ns>_PROJECT_TARGETS`, `CSCMAKE_<ns>_[DEFAULT_]COMPONENTS`,
  `CSCMAKE_<ns>_COMPONENT_<c>_*`, export sets `<ns>_<component>-targets` (installed files and component names
  unchanged); target property `CSCMAKE_NAMESPACE`.
- Tests (`tests/cmake/test_nested_projects.py`, both failing before): outer + nested inner with a component `core` in
  each and a link between them, installed into one prefix, consumed with `find_package(outer)` (inner found through
  `find_dependency`, only the components needed); a nested configuration missing from the build → error.
- README: "Nested csCMake projects"; `MIGRATION.md`: namespaced global property names.

### 2026-11-10 (Windows Ninja variants, user request during 3b step 5)
- csorchestrator-managed projects build Windows with Ninja (csqt6 CI: `csv1-windows-v10-x64-generic-msvc-msvc_2022_17-ninja`,
  MSVC environment from `TheMrMilchmann/setup-msvc-dev@v4`), but csCMake generated no preset for it: the registry's
  `use_ninja_for_windows` switched Windows to *either* Visual Studio *or* Ninja (default Visual Studio).
- Registry: Windows variants = Visual Studio generators + (`use_ninja_for_windows`, default on) Ninja / Ninja
  Multi-Config with an explicit MSVC version: msvc / msvcclang × 2022_17 / 2026_18 → 8 variants (42 total); short
  compiler versions `22` / `26`. Generator: compiler version lowercase in preset names (as in the variant id, e.g.
  `csv1-windows-v10-x64-generic-msvc-msvc_2022_17-ninja`); existing presets unchanged (48 files added).
- `presets/common/config-compilers.json`: `cs-compiler-windows-{msvc,msvcclang}-msvc_{2022_17,2026_18}`: `cl` /
  `clang-cl`, toolset `v143` / `v145` and architecture `x64` with `"strategy": "external"` (IDEs set up the developer
  environment, plain `cmake` expects it).
- CI: `ci_matrix.py` runner by MSVC version + `msvc_dev_env` matrix field; `smoke.yml` runs `setup-msvc-dev@v4` for
  those jobs. Not run locally (Linux host): the GitHub smoke run is the first real test (to check: clang-cl on PATH
  in the developer environment, `v145` toolset name for VS 2026).
- Alignment note: csorchestrator's own registry copy still has the exclusive `use_ninja_for_windows`.
- Nested projects in the smoke tests (user question): the configure tests cover csCMake's logic; a compiled nested
  smoke project would add real builds on every generator (Visual Studio, Xcode), shared libraries and the debugger
  environment across two projects → add with the remaining smoke gaps (shared libraries, ...), not required now.

### 2026-11-10 (Phase 3b step 6c — one prefix-path mechanism)
- Step 6 split into commits (user): 6c prefix paths, 6b static MSVC runtime, 6d csCMake location (layouts `sibling`,
  `sibling-short`, `standalone`, `standalone-short`, `env`; one generated setup file), 6a compile profiles (agreed:
  conditional rules per configuration / compiler / platform incl. clang-tidy, applied at `cs_finalize_target`,
  `cs_add_compile_profile_rule` / `cs_target_use_compile_profiles`, project defaults; review the default and strict
  profiles, rename strict if a better name fits).
- Presets: `CMAKE_PREFIX_PATH` = the workspace folders only; `CSCMAKE_{PREFIX,MODULE}_PATH_{HEAD,TAIL}` passed from the
  process environment (`$penv{...}`) as cache variables (`-D` overrides); `CSCMAKE_PREFIX_PATH_PREFIX/SUFFIX` gone.
  `cs_initialize_project` joins HEAD / value / TAIL without empty items. Tests: configure test (join), preset test (both
  base files pass the four variables). README, `MIGRATION.md`.

### 2026-11-10 (Phase 3b step 6b — static MSVC runtime)
- No new option: `CSCMAKE_MSVC_RUNTIME_LIBRARY_<CONFIG>` are overridable cache variables (step 2); a custom
  configuration copies the runtime of its base. README "MSVC runtime library": defaults, the static-runtime command
  line (or preset `cacheVariables`), same runtime for every library linked into one executable. Configure test: the
  override reaches `MSVC_RUNTIME_LIBRARY` of the targets, also for Paranoid (based on Debug).

### 2026-11-10 (Phase 3b step 6d — csCMake location: preset layouts)
- The two hand-written bases differed only in two environment values, and the three generated setup files repeated
  the per-variant presets. Now: `presets/csCMakeProjectSetup.json` (generated, once): `cscmake-common-project-setup`
  (build/install folders, search paths from the environment values `CSCMAKE_WORKSPACE_ROOT`, `CSCMAKE_ROOT`,
  `CSCMAKE_BUILD_SUB_DIR`) + the 42 `cscmake-project-setup-<variant>`; `presets/layout/<layout>.json` (generated from
  the `LAYOUTS` table of `generate.py`, template `layout.json.template`): `sibling`, `sibling-short`, `standalone`,
  `standalone-short` (user), `env`, `env-short`, each includes the common file and defines `cscmake-project-setup`
  with the three values. A project's `csCMakeProjectSetup.json` includes one layout (or defines its own).
- Presets rule found by experiment: a preset can only inherit presets of its file or of files it includes → the
  layouts include the common file (not the reverse); environment values referencing each other and the variant
  presets resolve across inheritance (checked with a minimal preset project).
- `cscmake-common-project-setup` (not `cscmake-project-setup-common`: the `cscmake-project-setup-` prefix is the one of
  the per-variant presets).
- Smoke: Base / MidA / Top `sibling`, MidB `sibling-short`; new `csSmokeStandalone` (`standalone-short`, own workspace,
  csCMake copied into it by `run_smoke.py`) and `csSmokeEnv` (`env`, `run_smoke.py` sets `CSCMAKE_WORKSPACE_ROOT` /
  `CSCMAKE_ROOT`, `$penv{CSCMAKE_ROOT}` includes, finds csSmokeBase). Tests: layouts, common file. `.gitattributes`:
  LF for the new generated files. README "Project setup presets", `MIGRATION.md` table.

### 2026-11-10 (Phase 3b step 6a — compile profiles)
- `utils/csCompileProfiles.cmake`: `cs_add_compile_profile_rule(PROFILE <p> [CONFIGS] [COMPILERS] [FRONTENDS] [PLATFORMS]
  [COMPILE_OPTIONS] [COMPILE_DEFINITIONS] [LINK_OPTIONS] [PROFILES] [CLANG_TIDY])`, `cs_target_use_compile_profiles`,
  `cs_get_target_compile_profiles`; `cs_initialize_project(... DEFAULT_COMPILE_PROFILES <p>...|NONE)` (default
  `cscmake_default`). Applied once by `cs_finalize_target`: conditions → generator expressions (nested profiles: AND),
  compile options / definitions PRIVATE, link options PRIVATE + INTERFACE for static / object libraries (sanitizer
  runtime: found by the smoke chain, csSmokeMidA's Paranoid build links the UBSan-compiled installed csSmokeBase);
  INTERFACE libraries skipped. `CLANG_TIDY`: generator expression in `CXX_CLANG_TIDY` (checked: CMake runs it only in
  the matching configurations), mandatory where the rule matches the build at configure time (configurations,
  compiler, frontend, platform), warning with Visual Studio / Xcode.
- Shipped profiles (user review): `cscmake_default` (MSVC `/MP /Zc:__cplusplus`), `cscmake_warnings` (same essential
  checks on every compiler; added `-Woverloaded-virtual -Wimplicit-fallthrough -Wmisleading-indentation`, and the MSVC
  off-by-default warnings `/w15038` (initialization order, user question), `/w14265 /w14263 /w14264 /w14242 /w14254
  /w14826 /w14062 /w14296 /w14905 /w14906 /w14928 /w14640`; clang-cl gets `/W4 /permissive-` instead of the GCC-style
  list), `cscmake_warnings_as_errors`, `cscmake_strict_warnings` (the former "strict"), `cscmake_sanitize_undefined`,
  `cscmake_sanitize_address` (new), `cscmake_hardening` (new: `_GLIBCXX_ASSERTIONS`, `_LIBCPP_HARDENING_MODE`),
  `cscmake_clang_tidy`.
- Removed: option targets `cscmake_compile_options[_strict]`, `cscmake_msvc_parallel_compile`,
  `cscmake_strict_warnings` (only `cscmake_base_include` remains), `STRICT_COMPILATION_ON_CONFIG`,
  `cs_get_strict_build_configuration`, `cs_target_enable_clang_tidy` / `csClangTidy.cmake`.
  `cs_target_check_installed_headers(<target> [COMPILE_PROFILES ...])`.
- Smoke: csSmokeBase profile `csSmokeBase_paranoid` (project default): UBSan + hardening in Paranoid, clang-tidy with
  Clang on Linux (`.clang-tidy`); header check with `cscmake_strict_warnings`. Tests: `test_compile_profiles.py`
  (conditions, nesting, defaults, static link options, unknown profile, clang-tidy mandatory / not in the build;
  skipped on Windows: they compile). README "Compile profiles" (profiles and warnings tables), `MIGRATION.md`.

### 2026-11-10 (Phase 3c step 1 — docstrings)
- One docstring format (`CLAUDE.md`): a header line at the top of each module; public `cs_*`: summary, signature,
  details, `Arguments:` / `Reads:` / `Writes:` as `* ` bullet lists; private `_cs_*`: summary (+ details) and `Reads:` /
  `Writes:` when it touches state. `Reads:` / `Writes:` bullets start with the kind (`variable`, `cache variable`,
  `environment variable`, `global property`, `target property`) and are the source of the variables / properties
  reference (next step).
- Applied to `csCMake.cmake` and every `utils/*.cmake` module; the compile profiles overview moved to the module header.

### 2026-11-10 (Phase 3b step 6a follow-up — hardening levels)
- Xcode (macOS CI, Paranoid): Xcode defined `_LIBCPP_HARDENING_MODE` (debug mode) and `cscmake_hardening` defined it
  again (macro redefined, `-Werror`). With Xcode, `cs_initialize_project` sets
  `CMAKE_XCODE_ATTRIBUTE_CLANG_CXX_STANDARD_LIBRARY_HARDENING` to `none` unless the project sets it
  (`_cs_set_generator_variables`, also `CMAKE_EXPORT_COMPILE_COMMANDS` with Ninja): the compile profiles choose the
  checks, as with the other generators. Amended into the step 6a commit.
- Two levels: `cscmake_hardening` (libc++ fast mode, `_GLIBCXX_ASSERTIONS`: release-usable) and
  `cscmake_hardening_debug` (libc++ debug mode, `_GLIBCXX_ASSERTIONS`: test configurations). Not in `cscmake_default`
  (it applies to every configuration and hardening changes the behaviour of a buggy program): README recipe for the
  debug configurations. Smoke Paranoid uses `cscmake_hardening_debug`; `test_hardening_levels`.

### 2026-11-10 (Phase 3b step 6a follow-up — hardening names)
- `cscmake_hardening` → `cscmake_hardening_fast` (the libc++ mode in the name, next to `cscmake_hardening_debug`).
- Smoke: csSmokeBase profile `csSmokeBase_paranoid` → `csSmokeBase_checks`: `cscmake_hardening_debug` in Debug and
  Paranoid, `cscmake_hardening_fast` in Release and RelWithDebInfo (UBSan and clang-tidy in Paranoid as before). README
  recipe with both levels.

### 2026-11-10 (Phase 3b step 6a follow-up — Xcode hardening, second attempt)
- macOS CI (Xcode, Paranoid) still failed compiling the header check with the `CLANG_CXX_STANDARD_LIBRARY_HARDENING`
  override (`none`): presumably Xcode then defines `_LIBCPP_HARDENING_MODE_NONE` (log without the compiler error).
  Override removed (`_cs_set_generator_variables` keeps `CMAKE_EXPORT_COMPILE_COMMANDS`); with Xcode the hardening
  profiles add `-Wno-macro-redefined`: Xcode's definition comes first on the command line (first log), the one of the
  profile wins. Other targets keep the Xcode setting. To confirm on GitHub.

### 2026-11-10 (Phase 3c step 2 — reference in CMake's documentation format)
- User question "are we reinventing the wheel?": CMake documents its modules in reStructuredText (`#.rst:` comments,
  Sphinx CMake domain); adopted instead of a custom Markdown generator for the `Reads:` / `Writes:` sections.
- Every documented module: a `#.rst:` header (title, summary, `Commands`), one `#.rst:` block per public command
  (`.. command::`, signature, details, arguments, `:Reads:` / `:Writes:` links), and the variables and properties it
  writes (`.. variable::`, `.. prop_tgt::`, `.. prop_gbl::`, internal ones marked "Internal"). Private functions keep
  plain `#` comments; `csListUtils` and `csMSVCUtils` (no public content) have no page.
- `.cmake-format.json`: `literal_comment_pattern` keeps `#.rst:` blocks as written (plain comments still reflowed);
  cmake-lint takes them as docstrings (C0111) and checks their line length.
- `docs/`: `conf.py` (CMake domain, MyST, `nitpicky`, `primary_domain = "cmake"`; `prop_tgt` / `prop_gbl` registered
  as directives, so properties are described in the module that writes them instead of one page per property;
  intersphinx to cmake.org 3.31 through the local inventory `docs/_inventories/cmake-3.31.inv`, with a resolver for its
  `<type>:<name>` object names), `index.md`, `reference/<module>.rst`. `sphinx-build -W -n` clean.
- Build: command line or VS Code task "Docs: build"; not in pre-commit (user choice); `.github/workflows/docs.yml`:
  build on every push / pull request (artifact), deploy to GitHub Pages from `main`. Built HTML not committed.
- Dev dependencies `sphinx`, `sphinxcontrib-moderncmakedomain`, `myst-parser` (minimums in `constraints-minimum.txt`).
  README "Documentation", `CLAUDE.md` docs rule, agent skill updated.
- CMake inventory (user: documented, with a tool): `cscmake-update-cmake-inventory`
  (`src/cscmake/devtools/cmake_inventory.py`, stdlib): downloads `objects.inv` of `CMAKE_DOCS_VERSION` (also read by
  `docs/conf.py`), checks it is a Sphinx inventory of CMake objects, writes `docs/_inventories/cmake-<version>.inv`,
  removes other versions; VS Code task "Docs: update CMake inventory", `docs/_inventories/README.md`, tests
  (`test_cmake_inventory.py`: no network, committed inventory matches the version).
- Workflows `ci`, `smoke`, `docs` also run on release tags `v*.*.*` (as csfoundation; also matches `v1.2.3-rc1`).

### 2026-11-10 (Phase 3d step 1 — docs skeleton, contributing to the documentation)
- `docs/contributing/documentation.md`: where each part of the docs lives, building (command line, VS Code task, CI
  artifact, Pages), documenting a module / command (the real `cs_target_sources` block as example) / variable /
  property (directives and roles table, placeholders, internal entries, CMake's own names), private functions, writing
  pages (MyST, Mermaid, cross-references), checklist for a new or changed public command. Linked from the README and
  `CLAUDE.md`.
- Mermaid: `sphinxcontrib-mermaid` (dev dependency), MyST `myst_fence_as_directive = ["mermaid"]`: the same
  ` ```mermaid ` blocks render on GitHub and in the site.
- Release package with the docs (Phase 5, user): recorded in "Phase 5 — Release package".
- VS Code: `bierner.markdown-mermaid` recommended (Mermaid in the Markdown preview).

### 2026-11-10 (Phase 3d step 2 — user guide)
- `docs/user/`: getting started (workspace and layouts with a Mermaid diagram, the files of a project, configure /
  build / install / test), targets and sources (installed headers, include paths, generated files, links, mandatory
  finalize, header check, OpenMP, debug messages), dependencies (`cs_find_package` PUBLIC / PRIVATE, installed and
  nested csCMake projects, runtime dependencies; project folder named like the package), installed packages
  (components, installed layout, the generated Config and its variables), build configurations (mapped and custom,
  postfixes, output folders, MSVC runtime, nested projects), compile profiles (rules, defaults, clang-tidy, shipped
  profiles, hardening, recipe: strictness per kind of project and per folder), presets (names, layouts, folders,
  search paths, without presets), troubleshooting (the error messages of csCMake).
- Checked against the code and by running them: the getting-started project built with the documented workflow preset
  in a scratch workspace (installed layout as documented), and a consumer project using it (`<ns>_<component>_FOUND`,
  `<ns>_BASE_DIR`, `find_dependency` in its installed Config). Corrections found on the way: `CMakePresets.json`
  includes only `cs-presets-all.json` (the csCMake presets include `csCMakeProjectSetup.json`), install presets are
  build presets, workflows run build, install, test per configuration.
- Per-folder default profiles tested (`test_a_folder_sets_its_own_default_profiles`).
- `docs/conf.py`: MyST `deflist` (troubleshooting) and `myst_heading_anchors = 3` (GitHub-style `page.md#heading`
  links in the site too).
- Pages write names as plain inline code (the MyST roles show as raw text on GitHub and in the VS Code preview, user
  feedback): `docs/conf.py` links inline code naming exactly one documented command / variable / property.

### 2026-11-10 (Phase 3d step 3 — tutorials, smoke tests page)
- `docs/tutorials/`: the smoke projects as tutorials, in build order (a package with components: csSmokeBase; using a
  package, flat and `Sol` layouts: csSmokeMidB, csSmokeMidA; an application: csSmokeTop; other layouts: csSmokeEnv,
  csSmokeStandalone). Files included with `literalinclude` (the tested code, always), each preceded by a link to the
  file for GitHub readers.
- `tests/smoke/README.md` → `docs/advanced/smoke-tests.md` (first advanced page); the README points to it and to the
  tutorials (the smoke files keep referring to it).
- `docs/conf.py`: links to repository files outside `docs/` become links to GitHub at the commit built (`GITHUB_SHA` in
  CI, `git HEAD` locally) instead of downloads.

### 2026-11-10 (Phase 3d step 4 — advanced pages, formatting, contributing to the code)
- `docs/advanced/`: lifecycle (include, `cs_initialize_project` step by step, project scope, targets, finalize target
  and project, deferred check; Mermaid), runtime dependencies (walk at `cs_finalize_target`, resolution at
  `cs_finalize_project`, uses), installed packages internals (components, finalization steps, the generated Config),
  presets internals (files, registry, generator and templates, project setup and layouts, adding a variant).
- `docs/user/formatting.md`: formatting the CMake files of a project with the `cs_*` signatures of csCMake
  (`-c ../csCMake/.cmake-format.json [own config] --`, checked: the later file overrides, the signatures stay, `--`
  needed before the files, also in pre-commit hooks).
- `docs/contributing/code.md`: layout, CMake conventions, what a new or changed public command involves, checks.
- Findings recorded above ("Findings while writing the docs").

### 2026-11-10 (Phase 3d step 5 — argument lists in the reference)
- Every public command with arguments has its argument list (definition list after the details) in its `#.rst:`
  block: 37 commands (`cs_initialize_project`, `cs_add_compile_profile_rule`, `cs_target_sources` had one). "An alias
  is accepted" only where the command resolves aliases (`cs_finalize_target`, `cs_target_use_compile_profiles`,
  `cs_target_check_installed_headers`).

### 2026-11-10 (Phase 3d step 6 — README, AGENTS.md, MIGRATION.md)
- `README.md`: pitch, documentation map (site from `main`, the Markdown pages), quick start (workspace, the two preset
  files, a `CMakeLists.txt`, one workflow command), what csCMake does (each item linked to its page), requirements,
  layout, development. The details moved to the user guide (step 2); the pre-commit hooks list to
  `docs/contributing/code.md`.
- `AGENTS.md`: entry point for coding agents, pointing to `CLAUDE.md` (the rules), `PLAN.md`, the skill and the docs.
- `MIGRATION.md`: the rows mapping to names removed in step 6a (`cs_get_strict_build_configuration`,
  `CSCMAKE_STRICT_BUILD_CONFIGURATION`) now say "removed"; links to the docs instead of README sections; a pointer to
  the documentation of the new API.
- Skill: the smoke projects are described in `docs/advanced/smoke-tests.md` and the tutorials.

### 2026-11-10 (Phase 3e — documentation checks)
- `cscmake-check-docs` (`src/cscmake/devtools/check_docs.py`, stdlib): every public `cs_*` function / macro has a
  `.. command::` block of the same name right above it (and no block elsewhere); every csCMake variable / property used
  by the code (`CSCMAKE_*`, `_CSCMAKE_*`, `<prefix>_CSCMAKE_*`; `${...}` parts as placeholders) matches a
  `variable` / `prop_tgt` / `prop_gbl` entry (entry placeholders match anything) and every entry is used (names outside
  this naming, `CLANG_TIDY_EXE`, as written); every module with a reference header has its `docs/reference` page.
  Problems as `<file>:<line>: <message>`. On this repository: 42 commands, 50 entries, 53 names, no problem.
- Pre-commit hook `check-docs` (on the CMake modules and `docs/reference`), so also in CI; tests
  (`test_check_docs.py`: the repository, each kind of problem on a small fake repository, name extraction, placeholders).
- Documented in `docs/contributing/documentation.md` ("Completeness check"), `docs/contributing/code.md`, `CLAUDE.md`.

### 2026-11-10 (Phase 3f step 1 — csfoundation: branches, csCore)
- Branches `feature/productize` (local, not pushed) in csfoundation and in its workspace clone of csCore; the workspace
  clone of csCMake on `feature/productize` (54cd066).
- csCore migrated with the `MIGRATION.md` tables: `cs_initialize_project(NAMESPACE csCore ...)` (`DEFAULT_CONFIG Debug
  Release`), `cs_finalize_project()`, layout `sibling-short`, `csCoreSol::csCoreSol_csCMakeBaseInclude` →
  `csCore::cscmake_base_include`, links to `..._csCMakeCompileOptionsDefault` removed (`cscmake_default` applies),
  `math`: `cs_target_use_compile_profiles(math cscmake_strict_warnings)`, `cs_compileEachInstalledInclude(<t>
  ..._csCMakeCompileOptionsStrict)` → `cs_target_check_installed_headers(<t> COMPILE_PROFILES
  cscmake_strict_warnings)`, `csAssert.cmake` (installed, used by the other projects): generated-folder getters renamed,
  header check. `cs_exec_clang_tidy` removed: it never ran clang-tidy (3b finding), csCore has no `.clang-tidy`;
  enabling clang-tidy is a separate decision.
- Built and tested in the csfoundation workspace, Ubuntu 22.04, Ninja Multi-Config, the four configurations, fresh
  configure: GCC (289 tests) and Clang (288 tests), all passed; no new warning with the strict profile.
- Finding: `cmake --install` keeps the files of the old layout (`targets/csCoreSol_csCMakeCommonTargets.cmake`):
  `MIGRATION.md` now says to install into an empty prefix.

### 2026-11-10 (Phase 3f step 2 — csLie, csCamera, csVisOpenGL)
- User rules for the migrated projects: install only the libraries consumers need (no tests, no samples); keep the
  build path layout each project had (csCore `sibling-short`, the others `sibling`). Final pass test (user): `cd
  csfoundation && rm -rf workspace && ./csfoundation_project.py && ./csfoundation_project.py generate-github-workflow`,
  run once the branches are pushed (the orchestrator clones them from GitHub).
- csCore: test executables no longer installed, their Catch2 `PRIVATE`; `testUtils` stays installed (the tests of
  csLie and csCamera use it); TODO in its Readme: clang-tidy.
- csLie, csCamera, csVisOpenGL: branches `feature/productize`, migrated as csCore. csLie's `STRICT_COMPILATION_ON_CONFIG
  Paranoid` (UBSan in Paranoid for the targets linking the strict options: its header check) → profile
  `csLie_paranoid` used by `cs_target_check_installed_headers`. Fixed while migrating: the tests of csLie and csCamera
  called `cs_find_package(<library> PUBLIC csCore COMPONENTS testUtils ...)` on the library, so the installed Configs
  required `testUtils` (and Catch2): now `PRIVATE` on the test target. The csVisOpenGL sample is finalized, not
  installed.
- csfoundation (branch `feature/productize`): `common_repo_ref = "feature/productize"`; `.vscode/settings.json`
  `git.repositoryScanMaxDepth: 2` (Source Control lists the repositories of `workspace/`).
- Built in order in the csfoundation workspace (GCC, Ninja Multi-Config, four configurations, fresh): csCore 289,
  csLie 64, csCamera 4 tests passed; csVisOpenGL built (no tests). Installed Configs checked: no test dependency, no
  test or sample installed.

### 2026-11-10 (fixes before the merge, user)
- `252eed2`: preset display names and descriptions of the single-config presets use the OS version of the variant
  (names unchanged).
- `f95e2eb`: Visual Studio debugger environment `PATH=<runtime library folders>;%PATH%` per configuration with runtime
  libraries, unset otherwise (it emptied `PATH` for every target without imported DLLs); configure test
  `test_visual_studio_debugger_path`. The debugger itself is checked on Windows only.
- csfoundation CI on the feature branch (user): its workflow runs on pushes to `main` / `dev` only, and the manual run
  needs the workflow on the default branch (`main` has the older `csBaseLibs.yml`). `csfoundation_project.py` passes
  `on_push_branches=["main", "dev", "feature/productize"]` to `create_default_orchestrator`, workflow regenerated
  (`generate-github-workflow`, also the first check of the pass test). **When merging into `dev`**: remove
  `feature/productize` there and set `common_repo_ref` back to `"dev"`, regenerate; remove `feature/**` from the csCMake
  workflows. The local pass test was stopped (user: test in CI) after GCC and half of Clang, all passing.
- csfoundation CI, Windows clang-cl: csCore `math/CMakeLists.txt` adds `-Wall` to `Angles.cpp` on clang-cl (where it
  means `-Weverything`); the old strict target turned the C++98 compatibility warnings off for clang-cl, the new
  `cscmake_warnings` (`/W4`) did not, so `/WX` made them errors. Fixed in csCMake (user: csCMake the source of truth,
  production code unchanged): `cscmake_warnings` adds `-Wno-c++98-compat -Wno-c++98-compat-pedantic` on Clang and
  AppleClang (clang-cl included); configure test `test_warnings_turn_off_the_cpp98_compatibility_warnings_on_clang`.
  `-Wno-c++20-extensions` (old target) left out until a build needs it.
- csfoundation CI, clang-cl of Visual Studio 2022 only (2026 passes): `-Wc++20-extensions` errors from libassert's
  macros (an empty variadic macro argument, `CSCORE_ASSERT_SAFE_MATH`), again under `-Wall` = `-Weverything` of
  `Angles.cpp`. `cscmake_warnings` adds `-Wno-c++20-extensions` for clang-cl only (`COMPILERS Clang FRONTENDS MSVC`):
  on Linux and macOS, `-Wpedantic` keeps reporting C++20 extensions in older-standard code. Test renamed
  `test_warnings_turn_off_the_compatibility_warnings_on_clang`.
- third_party_base_libs (user: close the loop before the merge): `feature/productize` in it and its 12 forks. Every fork:
  `csCMakeProjectSetup.json` includes `presets/layout/sibling.json`; fmt-eigen and tclap (the two using `cs_*`):
  `NAMESPACE fmt-eigen` / `NAMESPACE tclap`, `cs_finalize_project()`, `<ns>::cscmake_base_include` (package and target
  names unchanged; first namespace with a hyphen, works). third_party_base_libs: `common_repo_ref` and
  `on_push_branches` as csfoundation. Release `v0.1.0-rc4` tagged on the feature branch, csfoundation
  `release_tag="v0.1.0-rc4"`. **When merging into `dev`**: the same trigger and `common_repo_ref` reverts in
  third_party_base_libs; a release tag from `dev` afterwards.

### 2026-11-10 (Phase 3 sign-off, merge into dev)
- Signed off (user): csfoundation CI green on `feature/productize` (all variants, both Windows clang-cl), third_party_base_libs
  release `v0.1.0-rc4` published and used by csfoundation. `feature/**` push triggers removed from `ci`, `smoke`, `docs`;
  `feature/productize` merged into `dev` (`--no-ff`). Merge order (user): csCMake, then third_party_base_libs and its
  forks with a release tag from `dev`, then csfoundation and its four projects on that release.

### 2026-11-10 (Phase 5 step 1 — release tooling)
- `cscmake-release` (`src/cscmake/devtools/release.py`, tests): from the tag and the built docs, `csCMake-<v>.tar.gz` /
  `.zip` (`csCMake/` folder, `PACKAGE_CONTENT`), `csCMake-docs-<v>.zip`, `SHA256SUMS`, `release-notes.md` (the
  `CHANGELOG.md` section); fails when the tag does not match `pyproject.toml` or the section is missing.
- `.github/workflows/release.yml`: on `v*.*.*` tags, `ci` / `smoke` / `docs` as reusable workflows (`workflow_call`,
  their tag triggers removed), then `publish` (`gh release create`, `--prerelease` for `-` tags).
- `CHANGELOG.md` (v0.2.0, v0.1.0); `pyproject.toml` 0.2.0; `MIGRATION.md` "from v0.1.0 to v0.2.0"; docs: Releasing page,
  getting started (a release or a clone), README status. Checked: the unpacked package builds tclap.

### 2026-11-10 (Phase 4 plan, step 4a — Python coverage)
- Phase 4 steps (user: start now, on `dev`): 4a Python coverage 100% and enforced; 4b CMake complexity (the
  `R0912`/`R0915`/`R0913` pragmas, flattened comments); 4c smoke gaps (shared library, components depending on each
  other and the cyclic dependency error, a consumer without csCMake); 4d presets: no unused `CMAKE_C_COMPILER` warning
  for C++-only projects; 4e cmakelang replacement evaluation.
- 4a: 94% → 100% line + branch coverage of `src/cscmake`: tests for the comment / empty line / end of file after a
  `.. command::` block (`check_docs`), `download` (`cmake_inventory`, `file://` URL), the template tool without a
  config, with a cmake-format failure, with changed placeholders, a clean lint, `TemplateError` in `main`
  (`cmake_template`), a missing package entry (`release`), the Linux generator preference without
  `generate_all_combinations` (`registry`). `pyproject.toml`: `fail_under = 100`, `exclude_also` for the `__main__`
  blocks and `case _: assert_never(...)`. CI (`shell: bash`, `pipefail`) fails on it.

### 2026-11-10 (Phase 4 step 4b — CMake complexity)
- No complexity pragma left (only the intentional `W0106` of `cs_print_state_info`):
  - `_cs_parse_additional_configurations`: arguments, namespace, standard and profiles; the configurations through
    `_cs_add_mapped_configurations`, `_cs_add_custom_configurations` (with `_cs_set_custom_config_output_directories`),
    `_cs_split_base_config` (the comma parsing both had) and `_cs_set_msvc_runtime_library_variables`; the triples /
    quintuples read with `list(POP_FRONT)`; messages unchanged;
  - `_cs_recursive_analyze_target`: a work list; one dependency per `_cs_analyze_dependency`, the debug summary in
    `_cs_debug_analyzed_target`; the unused `TYPE` read and the empty `else()` removed;
  - `_cs_configure_config_cmake`: keyword arguments (`cmake_parse_arguments(PARSE_ARGV ...)`, one value each, so the
    lists and the injected code keep their `;` and newlines); the file-level `R0913` pragma of `csInstall.cmake` removed.
- Checked: all tests with the local smoke builds (`--run-all`, 162 passed); the installed files of csSmokeBase and
  csSmokeMidA (Configs, target files, four configurations) byte-identical to the ones of `f71995c`.

### 2026-11-10 (Phase 4 step 4c — smoke gaps, install RPATH)
- Found: an installed executable linking a shared library of its own package does not run on Linux (no install RPATH:
  `libX.so: cannot open shared object file`); also in csImgTracker (see "Running executables: shared libraries of other
  packages"). The smoke projects used only static and interface libraries.
- Install RPATH by default (user: "like linking a target", on by default, can be turned off): `cs_finalize_target`
  sets the `INSTALL_RPATH` target property of executables (`$ORIGIN/<bin to lib>`, from `CMAKE_INSTALL_BINDIR` /
  `CMAKE_INSTALL_LIBDIR`) and shared / module libraries (`$ORIGIN`), `@loader_path` on macOS, nothing on Windows; kept
  when the target has its own (not empty; CMake initializes it from `CMAKE_INSTALL_RPATH`). Off:
  `cs_initialize_project(... INSTALL_RPATH OFF)` or the directory variable `CSCMAKE_INSTALL_RPATH`. First tried in the
  host presets, moved (user): presets used without csCMake (OpenCV `csopencvcpu`, the forks; Qt does not use them) must
  keep their upstream behaviour. Configure tests `tests/cmake/test_install_rpath.py`; user guide (installed packages,
  "Shared libraries"), runtime dependencies page.
- Smoke: `csSmokeShared` (two SHARED libraries, one using the other, and an application whose installed copy is run in
  the four configurations); `csSmokePlainConsumer` (plain CMake, `find_package(csSmokeShared COMPONENTS text)`, ctest
  from the build folder; Windows: `$<TARGET_RUNTIME_DLLS>` copied; Debug and Release: `Project.plain` in
  `run_smoke.py`, no Config checks). Checked locally: installed `csSmokeSharedApp` runs (`RUNPATH $ORIGIN/../lib` on the
  app and the libraries).
- Cyclic dependencies between components: message `[cs_finalize_project] cyclic dependency between the components: a ->
  b -> a: ...` (was the internal function name), configure test `test_cyclic_dependency_between_components`.
- Docs: smoke tests page (two projects, graph), presets (install RPATH), runtime dependencies ("Running the
  executables"). Deferred (user): deployment command, Windows build folder outside Visual Studio, run scripts.

### 2026-11-10 (rule: no hidden side effects)
- User: no unintended, obscure side effects (lesson of the install RPATH first put in the host presets). Rule added to
  CLAUDE.md and `docs/contributing/code.md` (CMake conventions); assessment of the existing global settings planned as
  Phase 4 step 4f ("Side-effect assessment", with the inventory of candidates).
- User: re-evaluate the code structure (files, folders) and reorganise where needed: Phase 4 step 4g ("Code structure
  assessment", with the observations of today's layout).

### 2026-11-10 (Phase 4 step 4d — unused CMAKE_C_COMPILER warning)
- The presets give `CMAKE_C_COMPILER` (projects with C sources need it: without it the Clang variants would build C
  with the default `cc`); a C++-only project got "Manually-specified variables were not used by the project:
  CMAKE_C_COMPILER". `cs_initialize_project` reads it (a debug message): CMake counts a value read (not
  `if(DEFINED)`) as a use. Rejected under the "no hidden side effects" rule: `warnings.unusedCli: false` in the
  presets (would hide the unused variables of every project using them, e.g. a mistyped option in a project's own
  setup preset); removing `CMAKE_C_COMPILER` from the presets. Projects using the presets without csCMake keep the
  warning. Configure test `test_the_c_compiler_of_the_presets_is_not_reported_unused` (fails on `4da7212`).

### 2026-11-10 (Phase 4 step 4e — cmakelang evaluation)
- Evaluation in "Tooling (cmakelang)": Python 3.15 breaks cmakelang's lexer (reported, confirmed in the code); gersemi
  prototyped as formatter (comments untouched, templates parsed, `cs_*` signatures need an extension); no maintained
  linter replacement. Recommendation: gersemi + an own `cscmake-lint` for the rules we use, after 4f / 4g; until
  then keep cmakelang with Python <= 3.14. Decided (user): option 2, Phase 4 step 4h.

### 2026-11-10 (Phase 4 step 4f — side-effect assessment)
- Assessment table in "Side-effect assessment". Changed: `CMAKE_CXX_STANDARD_REQUIRED` / `CMAKE_CXX_EXTENSIONS` set
  only if not defined (new macro `_cs_set_cxx_standard`, also keeps `cs_initialize_project` under the statement limit);
  `CMAKE_EXPORT_COMPILE_COMMANDS` `ON` only if empty (CMake creates it as an empty cache entry with Ninja: `NOT
  DEFINED` would never be true); the Config reads `<ns>_DEBUG` as a plain variable (was `option()`: a cache entry in
  every consumer). Configure tests fail on `754dfc2`, pass now. Lifecycle page: "What reaches beyond the csCMake
  targets" (reach and reason of each kept setting).

### 2026-11-10 (fix: installed include folders follow the selected configuration)
- CI (`9037b82`+): the smoke plain consumer failed to generate on Visual Studio (MSVC, clang-cl) and Xcode: `Imported
  target "csSmokeShared::sharedText" includes non-existent path .../include/MinSizeRel`. The packages exported
  `include/$<CONFIG>`, evaluated with the consumer's configuration (Visual Studio and Xcode generate MinSizeRel too); the
  imported configuration mapping chooses the libraries only. Now `cscmake_base_include` exports one entry per
  configuration, `$<$<CONFIG:<config>>:$<INSTALL_PREFIX>/include/<config>>` (`_cs_installed_include_dirs`):
  `$<CONFIG:...>` in the usage requirements of imported targets also matches the mapped configurations
  (`MAP_IMPORTED_CONFIG_<CONFIG>`; CMake >= 4.2 with CMP0199 NEW: the selected one), so headers and library come from
  the same configuration; an unmapped missing configuration gets no folder (generates; built, it needs a mapping).
  Absolute entries (`$<INSTALL_PREFIX>`): CMake prefixes relative ones even when they evaluate to nothing. Install
  side unchanged (`cs_get_install_include_dir`, `include/$<CONFIG>` evaluated at install: kept, documented as the
  install destination). Configure tests `tests/cmake/test_installed_include_dirs.py` (fail on `8678142`); docs:
  installed packages, build configurations, packages internals.

### 2026-11-10 (Phase 4 step 4g — code structure)
- User: proposal approved, OpenMP in a folder for integrations (`modules/integrations/`, more to come), one commit (mechanical).
- `utils/` -> `modules/`, by subject (110 functions moved by a script: each with the comment block above it, each placed
  once, checked): `csProject` (`cs_initialize_project`, `cs_finalize_project`, `cs_get_namespace`, the project scope
  mechanism, from `csCMake.cmake` and `csBuildConfigurations`), `csTargets` (was `csAddLibraryExecutable`; the install
  RPATH moved to `csInstall`), `csBaseInclude` (`csDefaultTargets` + the generated folders of `csPathUtils`),
  `csTargetDependencies` (+ `csMSVCUtils`, the Visual Studio debugger `PATH`; name kept, not `csRuntimeDependencies`:
  it also has the project dependencies of the targets), `csInstall` / `csPackageConfig` (component graph and
  `<namespace>Config.cmake`), `csCheckInstalledHeaders` (was `csCompileEachInstalledInclude`), `csCompileProfiles` /
  `csCompileProfilesShipped` (the `cscmake_*` definitions), `csDebug` (`csDebugMessage`, `csDebugUtils`,
  `csPrintInitialState`), `csInternal` (`csListUtils` + path helpers, no page), `integrations/csOpenMP`.
  `csCMake.cmake`: entry point only (version, policies, includes, root folder). Variables / properties documented in
  the module that writes them.
- Python: `src/cscmake/utils/generate_cs_preset_variants.py` -> `src/cscmake/presets/render.py` (test
  `tests/cscmake/presets/test_render.py`); import-linter layers `presets | devtools`, presets `generate` above
  `registry | render`.
- Followed: reference pages (`:doc:` links between them: `.. cmake-module::` pages are not `:module:` targets) and
  toctree, `cscmake-check-docs` (`modules/**/*.cmake`), pre-commit, `run_smoke.py`, `release.py`, README, AGENTS.md,
  CLAUDE.md, the skill, contributing pages, `.vscode/launch.json`; CHANGELOG "Unreleased" (renamed reference pages).
- Checked: fast checks, the installed files of csSmokeBase and csSmokeShared byte-identical to `2ab2dfa` (44 files, 4
  configurations), local smoke run.
