# csCMake — Plan

The open work of csCMake: what comes next, in order, and the ideas kept for later. History up to v0.4.0 (phases 0-5,
the decisions and the session log): `PLAN.md` at tag `v0.4.0` and the git history; user-visible changes:
`CHANGELOG.md`; decisions worth keeping: the docs, "Design decisions".

## Status

- `main` is tagged `v0.4.0` (phases 0-5 done: plumbing, preset generator, smoke tests, productize, internal quality,
  release package). Development on `dev`.
- Next: Phase 6, then 1.0.

## Governance

- Each phase (or step) is at least one commit; never squash phases.
- Human review at the end of every step: agents stop and wait, do not push, do not mark a step done without the
  reviewer.
- Update `PLAN_STATE` and the changelog below at the end of each session.

## Phase 6 — API review before 1.0 (proposed, user 2026-11-10)
All three steps can change the public API: they belong before the 1.0 stability promise, not after. 6a comes first:
it shrinks what 6b and 6c have to organise. How the 6a findings flow into the next steps:

| Finding | Done in | Effect on the next steps |
|---|---|---|
| B1, B2, B4-B6, C1, C3, C5, S1-S5 | 6a | none on the API; smaller, cleaner code for 6b / 6c |
| D1 (+ B3) runtime DLLs with CMake's genex | 6a | removes ~400 lines and 26 of the ~113 debug call sites (6c smaller; S3 removes ~15 more); drops `cs_get_target_runtime_libraries` and the `CSCMAKE_*RUNTIME_LIBRARIES*` / `CSCMAKE_LINKED_*` properties (6b inventory smaller); the runtime deployment ideas ("Later") use the genex too |
| D5 per-configuration cache copies, D7 C files | 6a | none on the API (D7 to decide) |
| D8 clang-tidy: kept (user) | 6a / later | C4 renames the cache variable (6b); maturity with csCore: "Professional C++ projects" |
| D2 printers, getters internal, D3, D6, C4 | 6b | the inventory starts from the 6a proposal below |
| D4 version compatibility | 6b | a new `cs_initialize_project` keyword (or not) |
| S6, C2 (messages) | 6c | the message review covers the error messages too |

**6a. General code review (first).**
- The whole CMake code (`csCMake.cmake`, `modules/`, the Config template): repeated code to factor (e.g. the
  per-configuration loops, property get/append patterns, the argument checks), antipatterns (global or directory state
  where a target property fits, `macro` where a `function` is enough, string building of lists, `PARENT_SCOPE`
  chains, dead branches, workarounds for CMake versions below the minimum), naming and comments that no longer match.
- Every public command no project uses (all but 9, see 6b): what it is for, who would call it; drop it if it has no
  real use (MIGRATION entry), otherwise it goes to a tier in 6b.
- Output: a findings list here (finding, file, proposal), agreed, then fixed in small steps; installed packages of the
  smoke projects byte-identical except where a finding changes behaviour on purpose.

**6a findings (review 2026-11-10, to agree; B = bug, D = design, S = simplification, C = cleanup).**

Bugs, confirmed or to confirm with a configure test first:
- [x] (fixed, under review) B1 (confirmed) `cs_target_check_installed_headers`: one target and one generated file per header, named after
  `NAME_WE`: `a/util.h` + `b/util.h`, or `util.h` + `util.hpp`, fail with "add_library cannot create target
  lib_util". Fix: one STATIC library per checked target with one generated `.cpp` per header, named after the
  relative path (also fewer targets).
- [x] (fixed, under review; found by the B1 test) B6 `cs_target_sources(<t> PUBLIC|INTERFACE[_INSTALL] <relative>)`
  failed at generate ("Target contains relative path in its INTERFACE_SOURCES"): the paths are wrapped in
  `$<BUILD_INTERFACE:...>`, which CMake does not make absolute. Every caller used `PRIVATE`, so header-only libraries
  with `INTERFACE_INSTALL` were never tried. Fix: absolute paths (relative to the current folder).
  Also: headers at the base of the project were checked with `#include </x.h>` (empty install folder).
- [x] (fixed: a clear error) B2 (confirmed) single-config generator with an empty `CMAKE_BUILD_TYPE` (no preset): accepted silently, the
  build has none of the configurations (no flags of the configuration, no postfix, compile profile rules with
  `CONFIGS` never apply); the check `if(NOT ${CMAKE_BUILD_TYPE} IN_LIST ...)` degenerates. Fix: a clear error, or
  default to the first configuration when the project has not set one (to decide).
- [ ] B3 (to confirm) runtime dependency analysis (`csTargetDependencies`, VS debugger `PATH`): imported locations are
  read per configuration of the build (`IMPORTED_LOCATION_<CONFIG>`), ignoring `CMAKE_MAP_IMPORTED_CONFIG_<CONFIG>`
  and `MAP_IMPORTED_CONFIG_*`: a package with Release only, or a custom configuration (Paranoid -> Debug), gets no
  DLL folder for that configuration; link items in generator expressions (`$<LINK_ONLY:...>`, which CMake writes
  for the private links of static libraries, `$<$<CONFIG:...>:...>`) are recorded as "non targets" and not followed.
- [x] (fixed: find_package propagated for PUBLIC / INTERFACE and PRIVATE on static libraries; debug lines) B4 `cs_target_use_openmp`: `cs_find_package(... PUBLIC ...)` whatever the visibility (a PRIVATE use still adds
  `find_dependency(OpenMP)` to the installed Config); two `message(NOTICE ...)` on every configure; the non-ClangCL
  message talks about Windows on every platform.
- [x] (fixed) B5 `cs_print_state` prints `CMAKE_CURRENT_LIST_DIR` as "csCMake path": it is the caller's folder.

Design (behaviour or API changes):
- [ ] D1 the runtime dependency analysis (~400 lines, fixed-point loop over the targets, deprecated properties
  `LINK_INTERFACE_LIBRARIES*`, file dependencies `LINK_DEPENDS` / `INTERFACE_LINK_DEPENDS` read as libraries) does
  what CMake does since 3.21 / 3.27 with `$<TARGET_RUNTIME_DLLS:tgt>` / `$<TARGET_RUNTIME_DLL_DIRS:tgt>` (minimum
  3.31: available), evaluated at generate time with the imported-configuration mapping: the debugger environment
  becomes `PATH=$<JOIN:$<TARGET_RUNTIME_DLL_DIRS:tgt>,;>;%PATH%`. Fixes B3. Only DLL platforms: on Linux / macOS the
  build tree uses RPATH, and deployment (later) uses `install(RUNTIME_DEPENDENCY_SET)`. Drops
  `CSCMAKE_RUNTIME_LIBRARIES_<CONFIG>`, `CSCMAKE_DIRECT_RUNTIME_LIBRARIES_<CONFIG>`, `CSCMAKE_LINKED_*`,
  `cs_get_target_runtime_libraries` (check the run-scripts idea can use the same genex: yes, `file(GENERATE)`).
  `CSCMAKE_PROJECT_DEPENDENCIES` (component dependencies) stays, computed from the links directly.
- [ ] D2 `cs_print_*`: they print only when the debug switch is on, so a project calling `cs_print_target_properties`
  to troubleshoot sees nothing. A command the project calls explicitly should always print. With 6b / 6c.
- [ ] D3 `cs_target_link_libraries` replaces in-project aliases by the real target, then calls `target_link_libraries`
  (the result equals `target_link_libraries`, `test_target_link_libraries.py`): is it still needed? If the analysis
  (D1, component dependencies) resolves aliases itself, it is `target_link_libraries` plus debug lines: keep as the
  documented entry point, or drop (9 consumer calls), to decide.
- [ ] D4 `<namespace>ConfigVersion.cmake` is always `COMPATIBILITY AnyNewerVersion` (a consumer asking 1.0 accepts
  2.0): an option of `cs_initialize_project` (e.g. `VERSION_COMPATIBILITY SameMajorVersion`), default to decide.
- [ ] D5 a custom configuration copies every per-configuration variable for 16 languages (65 cache entries per
  configuration, e.g. `CMAKE_ASM-ATT_FLAGS_PARANOID`), most of them empty: copy only the ones defined (or the enabled
  languages).
- [ ] D6 `cs_install_target(<target> <component> [DEFAULT])` parses `ARGC` by hand; `cs_find_package(<target> <mode>
  <find_package args>)` validates the mode after `find_package` ran and stores the arguments as one string: keyword
  style and early checks (with 6b).
- [ ] D7 compile profiles apply their options to every language of the target (`-Wold-style-cast` on a C file warns):
  wrap them in `$<COMPILE_LANGUAGE:CXX>` (or per-rule `LANGUAGES`), to decide.
- [ ] D8 clang-tidy: the old `cs_target_enable_clang_tidy` / `cs_exec_clang_tidy` were removed in Phase 3 (they never
  ran clang-tidy), but the compile profiles brought it back: the rule keyword `CLANG_TIDY`, the shipped profile
  `cscmake_clang_tidy`, the cache variable `CLANG_TIDY_EXE`, `_cs_apply_clang_tidy` (~40 lines, mandatory where a rule
  matches, a warning with Visual Studio / Xcode). Tested: configure tests (`test_compile_profiles.py`) and the smoke
  project `csSmokeBase` (Paranoid, Clang on Linux, its `.clang-tidy`). No project uses it (csfoundation: none).
  Decided (user 2026-11-10): **keep**, and mature it with a real user: csfoundation csCore runs clang-tidy through a
  compile profile (see "Professional C++ projects", clang-tidy); C4 renames the cache variable.

Simplifications (no behaviour change, installed files byte-identical):
- [ ] S1 eleven getters repeat `get_*_property` + `if(values) ... else "" ...` (NOTFOUND handling): `get_property()`
  returns an empty value for an unset property; one line each, or gone with 6b.
- [ ] S2 "several configurations" is computed in three places (`cs_get_install_include_dir`,
  `_cs_installed_include_dirs`, the multi-config subfolder in `cs_initialize_project` and
  `_cs_set_custom_config_output_directories`); the relative install folder of the current directory
  (`file(RELATIVE_PATH ... CSCMAKE_SOURCE_DIR ...)`) in three: one helper each.
- [ ] S3 component graph: cycle check (recursive over every path: exponential on diamonds) and topological sort
  (re-queue loop, ~60 lines) as one depth-first search with a "visiting" mark: sorted dependencies and cycles in one
  pass.
- [ ] S4 `cs_target_sources`: three identical loops per visibility, one `target_sources()` per file; `PRIVATE`
  sources wrapped in `$<BUILD_INTERFACE:...>` for no reason (to check: relative paths).
- [ ] S5 `_cs_list_add_list_unique_values` / `_cs_list_add_unique_value` in loops: `list(APPEND)` +
  `list(REMOVE_DUPLICATES)`; `get_filename_component` -> `cmake_path`; the help list of variables goes through a file
  in the build folder (`cmake_var_full_list.txt`) instead of `OUTPUT_VARIABLE`.
- [ ] S6 the debug-only work runs when debug is off: `cs_print_state` loops over every per-configuration variable of
  every configuration, `cs_print_components` sorts again; return early (with 6c).

Cleanup:
- [x] (done, 26 conditions) C1 unquoted dereferences in conditions: `if(NOT ${value} IN_LIST ...)`, `if(${x} STREQUAL ...)` (a value
  that names a variable is dereferenced twice, an empty one breaks the condition: B2): `if(NOT value IN_LIST ...)`,
  quoted strings; about 25 places.
- [ ] C2 error messages: some without the `[command]` prefix (`cs_install_target`, `cs_find_package`, OpenMP,
  `_cs_add_target_to_project_targets` "variable do not exists"), some naming internal functions
  (`[_cs_parse_additional_configurations]`, `[_cs_process_configurations]`, `[_cs_add_custom_build_configuration]`)
  instead of the command the user called; one wording.
- [x] (done) C3 `_cs_add_target_to_project_targets` checks `CSCMAKE_<CONFIG>_POSTFIX` and the MSVC runtime variable per
  configuration to detect a missing `cs_initialize_project`: one check of `CSCMAKE_NAMESPACE` with a clear message.
- [ ] C4 `find_program(CLANG_TIDY_EXE ...)`: an unprefixed cache variable (could clash with a project's own):
  `CSCMAKE_CLANG_TIDY_EXE`, documented (MIGRATION).
- [x] (done for the dead branch; the printers with D2) C5 dead code: the empty `elseif(propagate_mode STREQUAL "PRIVATE")` branch, `set(targets "")` before a getter,
  the `count GREATER 0` / `list(LENGTH)` dances in the printers.

Public commands not used by any project (the starting point of the 6b inventory): `cs_get_*` (19), `cs_print_*` (8), `cs_get_namespace`,
`cs_debug_message`. Proposal: keep `cs_get_generated_dir` / `cs_get_generated_config_dir` (generated headers),
`cs_get_build_configurations`, `cs_get_install_include_dir`; the other getters become internal (state accessors of
csCMake); the eight printers become two that always print (`cs_print_target(<target>)`: csCMake view of a target,
plus its CMake properties with `ALL_PROPERTIES`; `cs_print_project()`: configurations, targets, components,
dependencies, search paths).

Order proposal: B1, B2, B4, B5, C1, C3-C5 and S1-S5 (small, safe,
one commit each or grouped); then D1 (with B3, needs Windows CI) and D5; D7 to decide. D2, D3, D4, D6 go to 6b; S6 and
C2 to 6c.

**6b. Public API surface: core vs utilities.**
- Today: ~43 public `cs_*` commands in one flat namespace. Consumers (csfoundation, trackers, scanned 2026-11-10)
  use 9: `cs_initialize_project`, `cs_finalize_project`, `cs_add_library`, `cs_add_executable`, `cs_target_sources`,
  `cs_target_link_libraries`, `cs_find_package`, `cs_install_target`, `cs_finalize_target`. The rest are getters
  (`cs_get_*`, 19, mostly used by csCMake itself), printers (`cs_print_*`, 8) and `cs_debug_message`; after D1 one
  getter less.
- From 6a: the proposal under "Public commands not used by any project"; D2 (printers always print), D3
  (`cs_target_link_libraries` kept or dropped), D4 (version compatibility keyword), D6 (keyword arguments for
  `cs_install_target` / `cs_find_package`), C4 if clang-tidy stays.
- Proposal, three tiers, each with a clear statement in the docs:
  * **Core** (the lifecycle and the target commands, + compile profiles, OpenMP): what a project writes; stable.
  * **Inspection / troubleshooting** (two printers after D2: `cs_print_target(<target>)`, `cs_print_project()`):
    "use when a target, a link or a package does not do what you expect"; always print; the existing
    `docs/user/troubleshooting.md` page says when to use which; output stable in content, not in format. Their output
    follows the 6c conventions (indent, context).
  * **Queries** (`cs_get_*`): only those a project has a real use for stay public and stable; the others become
    `_cs_*` (internal, free to change).
- Steps: inventory table (command, tier, used by csCMake / projects, keep / internal / rename), agree it, then rename
  with MIGRATION entries; reference split by tier (core pages first, a "Utilities" section).

**6c. Debug mechanism.**
- Today: a cache option `<project>_CSCMAKE_DEBUG` (on/off for the whole configure), `cs_debug_message` prints
  `STATUS` lines, ~116 call sites with ad-hoc text and hand-made indentation (`"  "`), no structure; the generated
  Config has its own `<Ns>_DEBUG`. After 6a about a third of the call sites are gone (D1 the dependency analysis, S3 the component graph);
  after 6b the printers are two commands that always print: 6c is about the debug trace of the lifecycle
  (initialize, targets, finalize, components, Config) and its switch.
- From 6a: S6 (no debug work when debug is off), C2 (one wording for the error messages, reviewed with the debug
  messages).
- CMake has the pieces for a mature design (3.17+): log levels (`message(VERBOSE|DEBUG|TRACE)`, `--log-level`,
  `CMAKE_MESSAGE_LOG_LEVEL`), `CMAKE_MESSAGE_INDENT` (a list: append on entry, automatically restored at function
  exit), `CMAKE_MESSAGE_CONTEXT` + `--log-context` (`[myProject.cs_finalize_target.mylib]` prefixes, filterable).
- Proposal (to agree):
  * levels: `VERBOSE` what csCMake does (one line per target / component / package), `DEBUG` why (resolved
    dependencies, components, generated files), `TRACE` everything (properties, paths);
  * nesting: each `cs_*` command pushes its name on the context and indents its sub-steps (dependency walk shown
    as a tree);
  * scoping: the switch is a normal variable read at each message, so it can be set around a call
    (`set(<project>_CSCMAKE_DEBUG ON)` ... `unset(...)`) or per target (a `CSCMAKE_DEBUG` target property); maybe
    `cs_debug(PUSH <level>)` / `cs_debug(POP)`;
  * the same conventions in the generated Config (`find_package` diagnostics: which components, which dependencies);
  * a review of every message: says what happens and to what, no internal variable names without context;
  * tests: configure with the switch and check the structure of the output (levels, context, indent).
- Open question: keep `<project>_CSCMAKE_DEBUG` as the on switch (forcing the level), or rely on `--log-level`
  only (standard, but global to all projects of the build).

## Then: 1.0

- Before 1.0: Phase 6 done; the projects still on the v0.1.0 presets migrated: csopencvcpu and csopencvcuda (the
  OpenCV fork's `csCMakeProjectSetup.json` includes `presets/csCMakeProjectSetup-base.json` and inherits
  `cscmake-project-setup-base`, gone since v0.2.0: see MIGRATION.md "Project setup presets"), csqt6 (its release is
  used by csfoundation).
- Clean first stable release (to decide):
  - User idea: after Phase 5, a full clean-up and a first clean release, without references to the past (PLAN removed).
  - Proposal: keep the repository and its history (blame, tags `v0.1.0` / `v0.2.0` used by third_party_base_libs and
    csfoundation, Pages, CI); remove `PLAN.md` from the repository: decisions -> docs "Design decisions", user-visible
    changes -> `CHANGELOG.md`, open items -> `TODO.md`; MIGRATION "from 0.x to 1.0". Tag 1.0.0 (API
    stability promise) once more projects use the API (csqt6, csopencvcpu, a tracker). A new single-commit repository
    stays possible at the 1.0 moment (old one archived), same cost then as now.
- Tracking after 1.0 (decided, user 2026-11-10): open items in one `TODO.md` (sections per area: API, debug, presets,
  docs, smoke, other projects; one checkbox line per item); no GitHub issues for now.

## Later (ideas, not scheduled)

### Professional C++ projects (user 2026-11-10, to plan)
Goal: a project made with csCMake + the template gives a professional experience, in VS Code as in Visual Studio:
autocomplete, tests listed and run one by one, executables run and debugged from the IDE (with their DLLs), a single
file compiled, coverage, documentation. Owner: **csCMake** (CMake behaviour), **template** (copier: files rendered
into each project), **csorchestrator** (CI). Today: presets, `compile_commands.json` with Ninja, compile profiles
(warnings, sanitizers, hardening, clang-tidy), `enable_testing()`, the Visual Studio debugger `PATH`.

Quality
- [ ] **clang-tidy, mature** (csCMake + template): csCore adopts it first (a profile in a Paranoid or Lint
  configuration, its `.clang-tidy`); then the `.clang-tidy` tiers (core / app / sample) in the template; generated
  sources skipped (`SKIP_LINTING`); fixes export; a CI job.
- [ ] **Coverage** (csCMake + csorchestrator): a `cscmake_coverage` profile (GCC `--coverage`, Clang source-based
  `-fprofile-instr-generate -fcoverage-mapping`) for a Coverage configuration; a report target (gcovr / llvm-cov,
  HTML + Cobertura XML); CI publishes it. MSVC: OpenCppCoverage, or Clang-cl only.
- [ ] **clang-format** (template): a shipped `.clang-format`, pre-commit hook, format on save; a check in CI.
- [ ] **More analyzers / sanitizers**: TSan profile, cppcheck / IWYU as rule fields, MSVC `/analyze`; MSVC ASan DLL on
  the debugger `PATH` (see "Compile profiles").

Tests
- [ ] **Test framework integration** (csCMake): GoogleTest / Catch2 with `gtest_discover_tests` /
  `catch_discover_tests`, so IDEs list each test case, not one entry per executable; a helper (e.g.
  `cs_add_test_executable`) that sets labels, timeouts and, on Windows, the DLL `PATH` of the tests
  (`ENVIRONMENT_MODIFICATION` from `$<TARGET_RUNTIME_DLL_DIRS>`, after 6a D1): `ctest` and the test explorers run
  them outside Visual Studio.
- [ ] **Test presets** in the generated presets (if missing) and JUnit output (`ctest --output-junit`) for CI.

IDE experience (template, csCMake where noted)
- [ ] **VS Code setup rendered by the template**: `extensions.json` (CMake Tools, clangd or C/C++, CodeLLDB on
  macOS / Linux, C++ TestMate optional), `settings.json` (`cmake.useCMakePresets`, IntelliSense provider, format on
  save), `launch.json` (debug the CMake Tools launch target: `${command:cmake.launchTargetPath}`, `cppvsdbg` /
  `cppdbg` / `lldb` per platform).
- [ ] **IntelliSense**: clangd on `compile_commands.json` (Ninja presets only: the Visual Studio and Xcode generators
  do not write it) or Microsoft C/C++ with CMake Tools as configuration provider (works with every generator); choose
  one default and document both; check Ninja Multi-Config (one `compile_commands.json` per configuration).
- [ ] **Run / debug with the DLLs outside Visual Studio** (csCMake): VS Code and terminals need the `PATH` the Visual
  Studio debugger gets: generate per target an environment file / run script (see "Runtime deployment", run
  scripts) and use it in `launch.json` (`envFile`) and the tests.
- [ ] **Compile a single file**: CMake Tools "Compile Active File" works with Ninja / Makefiles (not Visual Studio /
  Xcode generators): document; the Ninja presets are the IDE default.
- [ ] **Visual Studio (Open Folder)**: uses `CMakePresets.json` directly; check the debugger environment there
  (`launch.vs.json`) and document.

Project basics
- [ ] **Documentation of C++ projects** (csCMake + template): Doxygen (doxygen-awesome theme, or Sphinx + Breathe like
  csCMake) with a `cs_add_documentation` helper / `docs` target, a docs preset, published per release by CI.
- [ ] **Version header** (csCMake): generated `<ns>/version.h` from `project(VERSION)` (+ git hash), installed.
- [ ] **Export header and symbol visibility** (csCMake): `generate_export_header` and hidden visibility by default
  for shared libraries, instead of `WINDOWS_EXPORT_ALL_SYMBOLS`.
- [ ] **Build speed**: compiler cache (ccache / sccache as `CMAKE_CXX_COMPILER_LAUNCHER`, opt-in: user preset or
  environment, not build behaviour), precompiled headers / unity builds documented.
- [ ] **Packaging**: CPack for applications (archives, installers), with the runtime deployment.

### Runtime deployment (when the applications are migrated: csImgTracker, csSkiTracker)
How executables find shared libraries, per platform, and what csCMake does today: docs
`docs/advanced/runtime-dependencies.md`. Open:
- [ ] **Deploy an application with its dependencies** (situation "final application"): e.g.
  `cs_install_runtime_dependencies(<app> [DIRECTORIES ...] [PRE_EXCLUDE_REGEXES ...])`, with CMake's
  `install(RUNTIME_DEPENDENCY_SET ...)` / `install(IMPORTED_RUNTIME_ARTIFACTS ...)` (3.21+): copy the shared libraries of
  the other packages (`libs/`, `install/`) into the app's `lib/` (Linux, macOS) or `bin/` (Windows); with the install
  RPATH of 4c the installed app then runs anywhere. Exclude the system libraries. Inputs: csCMake already knows the
  runtime libraries per configuration (after 6a D1: `$<TARGET_RUNTIME_DLLS>` on Windows; `RUNTIME_DEPENDENCY_SET` elsewhere). Qt: plugins (platform, image formats) need
  Qt's deploy script (`qt_generate_deploy_app_script`) or `windeployqt` / `macdeployqt`. Smoke: an app using
  csSmokeShared from another package, installed with its dependencies and run.
- [ ] **Windows build folder outside Visual Studio** (ctest, a terminal, VS Code): the DLLs of other packages need
  `PATH`. Options: tests get `ENVIRONMENT_MODIFICATION PATH=path_list_prepend:<folders>` (the folders csCMake computes
  for the debugger; csCMake does not wrap `add_test`, so a helper or a step of `cs_finalize_project` over the tests of
  the project); the run scripts below; or copying `$<TARGET_RUNTIME_DLLS>` next to the executables (what
  `csSmokePlainConsumer` does, plain CMake).
- [ ] **Run scripts**: at the end of `cs_finalize_project`, `file(GENERATE)` `<build>/run/<target>-$<CONFIG>.sh|.bat`
  setting `PATH` from `$<TARGET_RUNTIME_DLL_DIRS:tgt>` (Windows; Linux / macOS run through the build RPATH) (maybe VS Code launch environments too):
  also the interim answer for installed apps that use other packages' libraries, until the deployment command exists.

### Compile profiles and clang-tidy
Guiding constraint (user): configurability per kind of project and per part of a project: a core library is stricter
than an application, a sample or a standalone tool; tests and samples inside a project may be looser than its library.
- [ ] **Tiers** composed from the shipped profiles, chosen with `DEFAULT_COMPILE_PROFILES`: e.g. `cscmake_tier_core`
  (strict warnings, hardening in debug configurations, UBSan + ASan and clang-tidy in a paranoid configuration),
  `cscmake_tier_app` (warnings as errors, sanitizers on request), `cscmake_tier_sample` (warnings, no `-Werror`).
  Configuration names are project-defined, so tiers need the configurations as a parameter (e.g. a helper
  `cs_add_compile_profile_tier(<name> CORE PARANOID_CONFIGS Paranoid)`) or stay documented recipes.
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

### Smoke coverage
- [ ] `cs_target_use_openmp`: not covered by the smoke projects (needs OpenMP on every runner).

### csorchestrator alignment
- csorchestrator side: `TODO-cscmake-alignment.md` on its `dev` (drift test against `presets/csv1/variants.json`,
  Ubuntu 26.04, macOS, a selection per project). Adding a variant in csCMake then fails csorchestrator's drift test
  until it catches up (or pins an older csCMake ref).

### Project template with copier
- [ ] Consumer project scaffolding with copier (`copier copy` / `copier update`): `CMakePresets.json`,
  `csCMakeProjectSetup.json`, top `CMakeLists.txt` (`cs_initialize_project(NAMESPACE ...)`), pre-commit config,
  gersemi / cscmake-lint style. Split ownership: the **style policy** (line width, indentation) in
  the template repository (csCMake itself could take it via `copier update`); the **`cs_*` command signatures** stay in
  csCMake (versioned with the API): `gersemi/cscmake.py`, referenced by the template's `.gersemirc` from the csCMake
  checkout (no merge conflicts on `copier update`).

### Organisation: shared standards (to decide)
- Repositories: the copier template (adopted by every project), csCMake, csorchestrator, then the other projects; aligned
  on the same standards.
- Proposal: rules rendered into each repository, not fetched at build time (no code dependency between repositories):
  `cs-template` (copier: presets includes, pre-commit, `.clang-format`, `.clang-tidy` tiers, gersemi config, `.vscode`,
  shared CLAUDE.md / AGENTS.md rules, licence, CI stub; its docs are the human handbook: naming, versioning, branching,
  releases, "no hidden side effects"); `cscosine/.github` (org profile, default CONTRIBUTING / SECURITY, issue and PR
  templates, maybe reusable workflows); csCMake (CMake API, presets, `cs_*` signatures for the formatter, pinned by
  tag); csorchestrator (builds, generated CI, releases; reads csCMake's variant list). The template pins compatible
  csCMake / csorchestrator versions: updating the template aligns a project.
- Order: finish csCMake (Phase 6, 1.0) -> `cs-template` with csCMake as first adopter -> csorchestrator (and its
  variant matrix from csCMake) -> the other projects one by one.

## PLAN_STATE

| Phase | Status | Notes |
|-------|--------|-------|
| 0-5 | done | Signed off 2026-11-09 / 2026-11-10; released up to v0.4.0 (details: `PLAN.md` at `v0.4.0`). |
| 6 | in progress | 6a: findings listed (B1-B5, D1-D7, S1-S6, C1-C5), to agree; then 6b API tiers, 6c debug. |

## CHANGELOG

### 2026-11-10 (PLAN reduced after v0.4.0)
- PLAN.md reduced to the open work (user); the full plan and session log up to v0.4.0 stay in git (`v0.4.0`).

### 2026-11-10 (Phase 6a — code review findings)
- Whole CMake code read; findings B1-B5 (B1, B2 reproduced with a configure), D1-D7, S1-S6, C1-C5 in "Phase 6"; the
  unused public commands assessed (input for 6b). Nothing changed in the code yet.
- D8 decided (user): clang-tidy kept, matured with csCore. "Professional C++ projects" listed (quality, tests, IDE
  experience, project basics), with owners (csCMake, template, csorchestrator).

### 2026-11-10 (Phase 6a — B1, B6)
- B1: `cs_target_check_installed_headers` builds one library `<target>_installed_headers`, one generated source per
  header named after its path (`gen/shc/<path>.cpp`); headers at the base of the project included correctly; no
  target without headers. B6 (found by its test): `cs_target_sources` gives absolute paths to `target_sources`.
  Configure + build tests `tests/cmake/test_check_installed_headers.py` (fail on the old code); docs (targets,
  tutorial, smoke tests page).

### 2026-11-10 (Phase 6a — B2, B4, B5, C1, C3, C5)
- B2: an empty or unknown `CMAKE_BUILD_TYPE` (single-config) fails with the configurations of the project. B4:
  `cs_target_use_openmp` propagates `find_package(OpenMP)` only when consumers link OpenMP, checks the scope, debug
  lines instead of notices. B5: `cs_print_state` shows the csCMake folder. C1: conditions quote their values. C3: one
  "call cs_initialize_project first" check in `cs_add_library` / `cs_add_executable`. C5: `cs_find_package` checks
  its mode with a prefixed message (the printers' dead code goes with D2). Tests: build type, target before
  initialize, OpenMP propagation, csCMake path.
