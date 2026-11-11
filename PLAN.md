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

## Phase 6 — API review before 1.0 (in progress, user 2026-11-10)
All three steps can change the public API: they belong before the 1.0 stability promise, not after. 6a comes first:
it shrinks what 6b and 6c have to organise. How the 6a findings flow into the next steps:

| Finding | Done in | Effect on the next steps |
|---|---|---|
| B1, B2, B4-B6, C1, C3, C5, S1-S5 | 6a | none on the API; smaller, cleaner code for 6b / 6c |
| D1 (+ B3) runtime DLLs with CMake's genex | 6a | removes ~400 lines and 26 of the ~113 debug call sites (6c smaller; S3 removes ~15 more); drops `cs_get_target_runtime_libraries` and the `CSCMAKE_*RUNTIME_LIBRARIES*` / `CSCMAKE_LINKED_*` properties (6b inventory smaller); the runtime deployment ideas ("Later") use the genex too |
| D5 per-configuration cache copies, D7 C files | 6a | D7: `LANGUAGES` of the compile profile rules (MIGRATION) |
| D8 clang-tidy: kept (user) | decided in 6a | C4 renames the cache variable (6b); maturity with csCore: "Professional C++ projects" |
| D2 printers, getters internal, D3, D6, C4 | 6b | the inventory starts from the 6a proposal below |
| D4 version compatibility | 6b | a new `cs_initialize_project` keyword (or not) |
| S6, C2 (messages) | 6c | the message review covers the error messages too |
| Unused public commands: keep / internal / drop | 6a, last step | the 6b inventory starts from what is left |

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
- [x] (fixed) B1 (confirmed) `cs_target_check_installed_headers`: one target and one generated file per header, named after
  `NAME_WE`: `a/util.h` + `b/util.h`, or `util.h` + `util.hpp`, fail with "add_library cannot create target
  lib_util". Fix: one STATIC library per checked target with one generated `.cpp` per header, named after the
  relative path (also fewer targets).
- [x] (fixed; found by the B1 test) B6 `cs_target_sources(<t> PUBLIC|INTERFACE[_INSTALL] <relative>)`
  failed at generate ("Target contains relative path in its INTERFACE_SOURCES"): the paths are wrapped in
  `$<BUILD_INTERFACE:...>`, which CMake does not make absolute. Every caller used `PRIVATE`, so header-only libraries
  with `INTERFACE_INSTALL` were never tried. Fix: absolute paths (relative to the current folder).
  Also: headers at the base of the project were checked with `#include </x.h>` (empty install folder).
- [x] (fixed: a clear error) B2 (confirmed) single-config generator with an empty `CMAKE_BUILD_TYPE` (no preset): accepted silently, the
  build has none of the configurations (no flags of the configuration, no postfix, compile profile rules with
  `CONFIGS` never apply); the check `if(NOT ${CMAKE_BUILD_TYPE} IN_LIST ...)` degenerates. Fix: a clear error, or
  default to the first configuration when the project has not set one (to decide).
- [x] (fixed by D1: CMake evaluates the DLLs per configuration with the mapping; checked on Windows by CI only) B3 (to confirm) runtime dependency analysis (`csTargetDependencies`, VS debugger `PATH`): imported locations are
  read per configuration of the build (`IMPORTED_LOCATION_<CONFIG>`), ignoring `CMAKE_MAP_IMPORTED_CONFIG_<CONFIG>`
  and `MAP_IMPORTED_CONFIG_*`: a package with Release only, or a custom configuration (Paranoid -> Debug), gets no
  DLL folder for that configuration; link items in generator expressions (`$<LINK_ONLY:...>`, which CMake writes
  for the private links of static libraries, `$<$<CONFIG:...>:...>`) are recorded as "non targets" and not followed.
- [x] (fixed: find_package propagated for PUBLIC / INTERFACE and PRIVATE on static libraries; debug lines) B4 `cs_target_use_openmp`: `cs_find_package(... PUBLIC ...)` whatever the visibility (a PRIVATE use still adds
  `find_dependency(OpenMP)` to the installed Config); two `message(NOTICE ...)` on every configure; the non-ClangCL
  message talks about Windows on every platform.
- [x] (fixed) B5 `cs_print_state` prints `CMAKE_CURRENT_LIST_DIR` as "csCMake path": it is the caller's folder.

Design (behaviour or API changes):
- [x] (done; B3 fixed with it; the Visual Studio check green in CI) D1 the runtime dependency analysis (~400 lines, fixed-point loop over the targets, deprecated properties
  `LINK_INTERFACE_LIBRARIES*`, file dependencies `LINK_DEPENDS` / `INTERFACE_LINK_DEPENDS` read as libraries) does
  what CMake does since 3.21 / 3.27 with `$<TARGET_RUNTIME_DLLS:tgt>` / `$<TARGET_RUNTIME_DLL_DIRS:tgt>` (minimum
  3.31: available), evaluated at generate time with the imported-configuration mapping: the debugger environment
  becomes `PATH=$<JOIN:$<TARGET_RUNTIME_DLL_DIRS:tgt>,;>;%PATH%`. Fixes B3. Only DLL platforms: on Linux / macOS the
  build tree uses RPATH, and deployment (later) uses `install(RUNTIME_DEPENDENCY_SET)`. Drops
  `CSCMAKE_RUNTIME_LIBRARIES_<CONFIG>`, `CSCMAKE_DIRECT_RUNTIME_LIBRARIES_<CONFIG>`, `CSCMAKE_LINKED_*`,
  `cs_get_target_runtime_libraries` (check the run-scripts idea can use the same genex: yes, `file(GENERATE)`).
  `CSCMAKE_PROJECT_DEPENDENCIES` (component dependencies) stays, computed from the links directly.
- [x] (6b-5) D2 `cs_print_*`: they print only when the debug switch is on, so a project calling `cs_print_target_properties`
  to troubleshoot sees nothing. A command the project calls explicitly should always print. With 6b / 6c.
- [x] (6b-2) D3 `cs_target_link_libraries` replaces in-project aliases by the real target, then calls `target_link_libraries`
  (the result equals `target_link_libraries`, `test_target_link_libraries.py`): is it still needed? If the analysis
  (D1, component dependencies) resolves aliases itself, it is `target_link_libraries` plus debug lines: keep as the
  documented entry point, or drop (9 consumer calls), to decide.
- [x] (6b-3) D4 `<namespace>ConfigVersion.cmake` is always `COMPATIBILITY AnyNewerVersion` (a consumer asking 1.0 accepts
  2.0): an option of `cs_initialize_project` (e.g. `VERSION_COMPATIBILITY SameMajorVersion`), default to decide.
- [x] (done) D5 a custom configuration copies every per-configuration variable for 16 languages (65 cache entries per
  configuration, e.g. `CMAKE_ASM-ATT_FLAGS_PARANOID`), most of them empty: copy only the ones defined (or the enabled
  languages).
- [x] (6b-4) D6 `cs_install_target(<target> <component> [DEFAULT])` parses `ARGC` by hand; `cs_find_package(<target> <mode>
  <find_package args>)` validates the mode after `find_package` ran and stores the arguments as one string: keyword
  style and early checks (with 6b).
- [x] (done: `LANGUAGES` per rule, default CXX; user) D7 compile profiles apply their options to every language of the target (`-Wold-style-cast` on a C file warns):
  wrap them in `$<COMPILE_LANGUAGE:CXX>` (or per-rule `LANGUAGES`), to decide.
- [x] (decided: keep) D8 clang-tidy: the old `cs_target_enable_clang_tidy` / `cs_exec_clang_tidy` were removed in Phase 3 (they never
  ran clang-tidy), but the compile profiles brought it back: the rule keyword `CLANG_TIDY`, the shipped profile
  `cscmake_clang_tidy`, the cache variable `CLANG_TIDY_EXE`, `_cs_apply_clang_tidy` (~40 lines, mandatory where a rule
  matches, a warning with Visual Studio / Xcode). Tested: configure tests (`test_compile_profiles.py`) and the smoke
  project `csSmokeBase` (Paranoid, Clang on Linux, its `.clang-tidy`). No project uses it (csfoundation: none).
  Decided (user 2026-11-10): **keep**, and mature it with a real user: csfoundation csCore runs clang-tidy through a
  compile profile (see "Professional C++ projects", clang-tidy); C4 renames the cache variable.

Simplifications (no behaviour change, installed files byte-identical):
- [x] (done, 15 getters) S1 eleven getters repeat `get_*_property` + `if(values) ... else "" ...` (NOTFOUND handling): `get_property()`
  returns an empty value for an unset property; one line each, or gone with 6b.
- [x] (done: `_cs_relative_install_folder`, `_cs_headers_per_configuration`; the multi-config subfolders differ, genex vs folder, kept) S2 "several configurations" is computed in three places (`cs_get_install_include_dir`,
  `_cs_installed_include_dirs`, the multi-config subfolder in `cs_initialize_project` and
  `_cs_set_custom_config_output_directories`); the relative install folder of the current directory
  (`file(RELATIVE_PATH ... CSCMAKE_SOURCE_DIR ...)`) in three: one helper each.
- [x] (done: the cycle check visits each component once; the sort kept, a depth-first sort gives another valid order and would change the generated Configs) S3 component graph: cycle check (recursive over every path: exponential on diamonds) and topological sort
  (re-queue loop, ~60 lines) as one depth-first search with a "visiting" mark: sorted dependencies and cycles in one
  pass.
- [x] (done: one loop, one `target_sources()` per scope; the unused relative folder removed; `$<BUILD_INTERFACE>` kept) S4 `cs_target_sources`: three identical loops per visibility, one `target_sources()` per file; `PRIVATE`
  sources wrapped in `$<BUILD_INTERFACE:...>` for no reason (to check: relative paths).
- [x] (done; `get_filename_component` goes with D1) S5 `_cs_list_add_list_unique_values` / `_cs_list_add_unique_value` in loops: `list(APPEND)` +
  `list(REMOVE_DUPLICATES)`; `get_filename_component` -> `cmake_path`; the help list of variables goes through a file
  in the build folder (`cmake_var_full_list.txt`) instead of `OUTPUT_VARIABLE`.
- [ ] (-> 6c) S6 the debug-only work runs when debug is off: `cs_print_state` loops over every per-configuration variable of
  every configuration, `cs_print_components` sorts again; return early (with 6c).

Cleanup:
- [x] (done, 26 conditions) C1 unquoted dereferences in conditions: `if(NOT ${value} IN_LIST ...)`, `if(${x} STREQUAL ...)` (a value
  that names a variable is dereferenced twice, an empty one breaks the condition: B2): `if(NOT value IN_LIST ...)`,
  quoted strings; about 25 places.
- [ ] (-> 6c) C2 error messages: some without the `[command]` prefix (`cs_install_target`, `cs_find_package`, OpenMP,
  `_cs_add_target_to_project_targets` "variable do not exists"), some naming internal functions
  (`[_cs_parse_additional_configurations]`, `[_cs_process_configurations]`, `[_cs_add_custom_build_configuration]`)
  instead of the command the user called; one wording.
- [x] (done) C3 `_cs_add_target_to_project_targets` checks `CSCMAKE_<CONFIG>_POSTFIX` and the MSVC runtime variable per
  configuration to detect a missing `cs_initialize_project`: one check of `CSCMAKE_NAMESPACE` with a clear message.
- [x] (6b-1) C4 `find_program(CLANG_TIDY_EXE ...)`: an unprefixed cache variable (could clash with a project's own):
  `CSCMAKE_CLANG_TIDY_EXE`, documented (MIGRATION).
- [x] (done for the dead branch; the printers with D2) C5 dead code: the empty `elseif(propagate_mode STREQUAL "PRIVATE")` branch, `set(targets "")` before a getter,
  the `count GREATER 0` / `list(LENGTH)` dances in the printers.

- [x] (done: the 20 internal ones renamed `_cs_*`, MIGRATION; 22 public) **Last 6a step: the public commands no project uses** (keep / make internal / drop, MIGRATION entries; then
  the 6b inventory starts from what is left). Inventory 2026-11-11: projects (csfoundation, trackers, OpenCV forks,
  csqt6, third_party_base_libs) call 9 commands: `cs_initialize_project`, `cs_finalize_project`, `cs_add_library`,
  `cs_add_executable`, `cs_target_sources`, `cs_target_link_libraries`, `cs_find_package`, `cs_install_target`,
  `cs_finalize_target`. The documented features without a project yet (compile profiles, OpenMP, the header check,
  `cs_target_runtime_environment`) stay public. The other 29 (calls in csCMake / tests / docs pages):

  | Command | What for | csCMake / tests / docs | Proposal |
  |---|---|---|---|
  | `cs_get_build_configurations` | the configurations of the build | 11 / 0 / 0 | **keep**: per-configuration code of a project (loops over the configurations) |
  | `cs_get_generated_dir`, `cs_get_generated_config_dir` | the folders for generated headers (`configure_file`, per configuration) | 4, 1 / 0 / 1 | **keep**: generated headers are a project need |
  | `cs_get_install_include_dir` | the install folder of the headers (per configuration) | 1 / 0 / 1 | **keep**: installing extra files next to the headers |
  | `cs_get_project_targets` | the targets of the project | 3 / 0 / 0 | **keep**: a project applying something to all its targets (e.g. IDE folders) |
  | `cs_get_namespace` | the namespace of the project | 2 / 0 / 0 | **internal**: the project gave it; `CSCMAKE_NAMESPACE` is documented |
  | `cs_get_default_build_configurations` | the default ones among them | 2 / 0 / 0 | **internal** |
  | `cs_get_components`, `cs_get_default_components`, `cs_get_component_targets`, `cs_get_component_find_packages`, `cs_get_component_dependencies`, `cs_get_component_dependencies_sorted`, `cs_get_target_component` | the component bookkeeping of the package | 1-6 / 0 / 0-1 | **internal**: state of the generated Config; inspection through the printer |
  | `cs_get_target_find_packages`, `cs_get_target_sources_to_install`, `cs_get_target_sources_to_install_absolute_path`, `cs_get_target_project_dependencies`, `cs_get_target_compile_profiles` | per-target bookkeeping | 1-3 / 0-1 / 0 | **internal**: inspection through the printer |
  | `cs_print_target_properties` | every set property of a target | 0 / 1 / 1 | **keep, renamed** `cs_print_target` in 6b (D2: always prints, plus the csCMake view: sources to install, find packages, component, dependencies, profiles) |
  | `cs_print_state` | search paths, configurations | 2 / 1 / 0 | **keep, renamed** `cs_print_project` in 6b (plus targets and components) |
  | `cs_print_project_targets`, `cs_print_components`, `cs_print_target_find_packages`, `cs_print_target_sources_to_install`, `cs_print_all_configurations_variables`, `cs_print_configuration_variables` | pieces of the two above | 0-1 / 0-1 / 0-2 | **drop** as public (folded into the two printers in 6b; internal until then) |
  | `cs_debug_message` | a message under the csCMake debug switch | 85 / 0 / 1 | **decide in 6c** (with the switch) |

  Internal = renamed `_cs_*` (same code), the reference entries removed, MIGRATION rows "removed: <what to use>".
  Result: public API 9 core + 5 features (`cs_add_compile_profile_rule`, `cs_target_use_compile_profiles`,
  `cs_target_use_openmp`, `cs_target_check_installed_headers`, `cs_target_runtime_environment`) + 5 queries + 2 printers
  (+ `cs_debug_message`, pending 6c): 22 instead of 43.

Status (2026-11-11): every 6a finding done or moved (6b, 6c); the unused public commands are the last 6a step.

**6b plan (agreed, user 2026-11-11):**
- [x] (done) 6b-1: C4 `CLANG_TIDY_EXE` -> `CSCMAKE_CLANG_TIDY_EXE`; `cs_find_package` checks `PUBLIC` / `PRIVATE` before
  `find_package` runs.
- [x] (done) 6b-2 (D3): keep `cs_target_link_libraries`, and fail fast: links added after `cs_finalize_target` fail at the call.
- [x] (done) 6b-3 (D4): `cs_initialize_project(... VERSION_COMPATIBILITY AnyNewerVersion|SameMajorVersion|SameMinorVersion|
  ExactVersion)`, default `SameMajorVersion`.
- [x] (done) 6b-4 (D6): `cs_install_target(<target> COMPONENT <component> [DEFAULT])` (keywords after the target, like the
  other `cs_target_*` commands and `install(... COMPONENT)`; breaking, MIGRATION); `cs_find_package(<target>
  PUBLIC|PRIVATE ...)` kept (scope after the target, like `target_link_libraries`).
- [x] (done) 6b-5 (D2): `cs_print_target(<target>)` and `cs_print_project()`, always printing, instead of
  `cs_print_target_properties` / `cs_print_state` (MIGRATION); the 6c conventions later.
- [x] (done) 6b-6: reference grouped by tier (core, features, queries, troubleshooting); the troubleshooting page says when to
  use which printer.

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

**6c. Debug mechanism. Done 2026-11-11 (6c-1..6c-5).**
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
- Inventory (2026-11-11, after 6d): 42 `cs_debug_message` call sites. 19 of them trace the component algorithms in
  `csPackageConfig` (populate, cycles, sort: `---- analyze ...`); the others dump arguments (`[cs_target_sources]
  target x: ${ARGN}`) or name internal functions (`[_cs_parse_additional_configurations] ...`). Errors: 41
  `FATAL_ERROR`; 8 name an internal function (`[_cs_parse_additional_configurations]`, `[_cs_add_custom_build_configuration]`,
  `[_cs_get_namespace]`); the finalization's ones say `[csCMake]`. The Config template has its own `<Ns>_DEBUG`
  (4 messages).
- Verified with CMake (2026-11-11): `cmake_language(GET_MESSAGE_LOG_LEVEL <var>)` gives the current level (cheap test
  for S6); a normal `CMAKE_MESSAGE_LOG_LEVEL` set in a `block()` or folder raises the level there only, but
  `--log-level` on the command line wins over it; `CMAKE_MESSAGE_INDENT` / `CMAKE_MESSAGE_CONTEXT` appended in a
  function are restored when it returns; `--log-context` prints `[context]` prefixes.
- Proposal:
  * **Levels** (CMake's own): `VERBOSE` = what csCMake does, one line per thing (project initialized with its
    configurations; each target created with its type, profiles, install RPATH; each package found; each component
    installed; at the finalization each target's dependencies, each component's dependencies, the Config written);
    `DEBUG` = the details (arguments, imported configuration mapping, copied configuration variables, debugger
    environment, the project print of `cs_print_project`). The algorithm traces of `csPackageConfig` are dropped
    (tested code; the result is printed at `VERBOSE`).
  * **Switch**: CMake's: `--log-level=VERBOSE|DEBUG` for the build, `set(CMAKE_MESSAGE_LOG_LEVEL DEBUG)` in a folder or
    in a `block()` around a call for a part of it. `<project>_CSCMAKE_DEBUG` and `_cscmake_debug_option` removed.
  * **Context and indent**: every public command appends `<namespace>` (when known) and its own name to
    `CMAKE_MESSAGE_CONTEXT` (`--log-context` -> `[myLib.cs_add_library]`), and its sub-steps indent with
    `CMAKE_MESSAGE_INDENT` (the finalization: one level per target / component). Only inside csCMake's functions: the
    project's own messages are untouched.
  * **S6**: work done only for messages (lists joined, the project print) under `_cs_log_level_at_least(<level> out)`
    (`GET_MESSAGE_LOG_LEVEL`).
  * **`cs_debug_message`**: removed (a project writes `message(DEBUG ...)`); internal helper `_cs_message(<level>
    ...)` if one is useful. Public API: 19 commands.
  * **The Config**: `<Ns>_DEBUG` removed; its messages at `VERBOSE` / `DEBUG` with context `<Ns>Config`
    (`--log-level=VERBOSE` in the consumer shows which components and packages are loaded).
  * **C2, errors**: one form `[<public command>] <subject>: <what is wrong>; <what to do>` (no internal names; the
    finalization: `[csCMake] <namespace>: ...`); reviewed with every message.
  * **Docs**: troubleshooting "Debugging csCMake" (levels, `block()`, `--log-context`), the printers for one target.
  * **Tests**: default configure prints no csCMake line; `--log-level=VERBOSE` / `DEBUG` give the expected lines,
    context and indent; a `block()` raises the level for one call only; the Config at `VERBOSE`.
- Steps (each reviewed before its commit): 6c-1 levels, switch, context / indent, S6 helper, `cs_debug_message`
  removed, tests; 6c-2 every message rewritten or dropped, module by module (C2 with it); 6c-3 the Config; 6c-4 docs.
- Decisions (user, 2026-11-11): all four as proposed: CMake's switch only; `cs_debug_message` removed; the Config's
  `<Ns>_DEBUG` removed; the `csPackageConfig` traces dropped.
- (found) The Config gets no message context: `find_dependency` returns from the file when a package is missing, the
  context would stay in the consumer.

**6d. Automatic finalization (user 2026-11-11; after 6b, before 6c). Done 2026-11-11.**
- Today: each target ends with `cs_finalize_target(<target>)` (compile profiles, `INSTALL_RPATH`, records its links),
  the project with `cs_finalize_project()` (checks, run-time dependencies, install rules and Config). Forgetting one is
  an error. `cs_initialize_project` already defers a check to the end of its CMakeLists.txt (`cmake_language(DEFER)`).
- Proposal: `cs_initialize_project` defers the finalization itself to the end of the CMakeLists.txt that called it:
  every target of the project, then the project. Core tier = initialize, add, sources, links, find_package, install.
- Needs care:
  * finalization reads directory variables in the target's folder (`CSCMAKE_DEFAULT_COMPILE_PROFILES`,
    `CSCMAKE_INSTALL_RPATH`, `CMAKE_INSTALL_BINDIR` / `LIBDIR`); a deferred call sees the root folder's values. Fix:
    `cs_add_library` / `cs_add_executable` copy them into target properties at creation (as CMake does with
    `CMAKE_<X>` -> `<X>`); finalization reads the properties only;
  * the fail-fast of `cs_target_link_libraries` stays (late links can now come only from a parent project or other
    deferred code);
  * targets not made by `cs_add_*` (the check target of `cs_target_check_installed_headers`) registered the same way;
  * nested projects: each defers to the end of its own CMakeLists.txt, inner finalized before the outer continues;
  * what a project writes after `cs_finalize_project` today: checked, nothing (csImgTracker, csSkiTracker end there);
  * (found) the printers: called in a project not finalized yet, they defer themselves after the finalization.
- The two commands are removed (MIGRATION: delete the lines); no deprecation step.
- Tests: smoke projects without the calls install byte-identical files; a subfolder with its own
  `CSCMAKE_DEFAULT_COMPILE_PROFILES`; late links fail; calls in the wrong order give actionable errors.
- Before 6c: it removes the `[cs_finalize_target]` / `[cs_finalize_project]` messages 6c would review.

## Then: 1.0

- Before 1.0: Phase 6 done; the projects still on the v0.1.0 presets migrated: csopencvcpu and csopencvcuda (the
  OpenCV fork's `csCMakeProjectSetup.json` includes `presets/csCMakeProjectSetup-base.json` and inherits
  `cscmake-project-setup-base`, gone since v0.2.0: see MIGRATION.md "Project setup presets"), csqt6 (its release is
  used by csfoundation).
- Licences (user 2026-11-10): check the licences of everything csCMake uses or ships, and comply (notices,
  attribution, compatibility with csCMake's own licence): what the release package and the docs zip contain
  (the built docs embed Furo, sphinx-design, Sphinx assets and fonts; `docs/_inventories` is cmake.org data), code
  derived from others (e.g. the per-configuration variable list "inspired by" comment in `csBuildConfigurations`),
  the dev tools (gersemi, ruff, mypy, pytest, import-linter, pre-commit: used, not shipped) and the presets
  (toolchain names only). Output: a third-party notices file in the package if needed, a licence section in the
  docs, and the same check in the template for the projects.
- Clean first stable release (to decide):
  - User idea: after Phase 5, a full clean-up and a first clean release, without references to the past (PLAN removed).
  - Proposal: keep the repository and its history (blame, tags `v0.1.0` / `v0.2.0` used by third_party_base_libs and
    csfoundation, Pages, CI); remove `PLAN.md` from the repository: decisions -> docs "Design decisions", user-visible
    changes -> `CHANGELOG.md`, open items -> `TODO.md`; MIGRATION "from 0.x to 1.0". Tag 1.0.0 (API
    stability promise) once more projects use the API (csqt6, csopencvcpu, a tracker). A new single-commit repository
    stays possible at the 1.0 moment (old one archived), same cost then as now.
- Before 1.0 (user 2026-11-11):
  * run-time environment scripts (Windows). **Done 2026-11-11, CI to check (Windows smoke).** `cs-env.bat` +
    `cs-env.ps1` in the top build folder (next to the `.sln`) for the whole build, nested projects included; per
    configuration `cs-env/<Config>.bat|.ps1` (`file(GENERATE)`), chosen by the dispatchers (given, the only one, or
    all identical; else error / prompt on double-click); `cs-env.local.*`; `-ps`; `CSCMAKE_RUNTIME_SCRIPTS`
    (default ON on Windows only); same variable with two values: configure error. Tests: `test_runtime_scripts.py`
    (text); Windows smoke runs both scripts for each configuration of csSmokeShared (CSSMOKE_CONFIG, PATH order) and
    without a configuration (only one: works; several: error);
  * a "Compatibility" docs page: public = the "Commands by tier" page, documented variables and properties, preset
    names of `csv1`; semantic versioning;
  * the docs examples are the smoke projects (`literalinclude`: csSmokeStandalone minimal, csSmokeBase / MidA / Top
    multi-library and consumed packages);
  * the smoke moves the install folder (relocatable packages: relative Config paths, `$ORIGIN` RPATH). **Done
    2026-11-11, CI to check (every variant).** After every project: `install/` moved to `install-relocated/`, no
    installed `.cmake` file may name `install/`, the installed applications run from there, csSmokeTop and
    csSmokePlainConsumer built again from new build folders with the packages found there only;
  * scope sentence in README and docs; the CMake 3.31 line of getting-started gets "(the csv1 presets use preset
    schema 10)" (no page of its own, user 2026-11-11); which docs version Pages shows.
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
- [ ] **Windows build folder outside Visual Studio** (ctest, VS Code; a terminal: `cs-env.bat` / `cs-env.ps1`, done
  2026-11-11): the DLLs of other packages need `PATH`. Options: tests get `ENVIRONMENT_MODIFICATION PATH=path_list_prepend:<folders>` (the folders csCMake computes
  for the debugger; csCMake does not wrap `add_test`, so a helper or a step of `cs_finalize_project` over the tests of
  the project); the run scripts below; or copying `$<TARGET_RUNTIME_DLLS>` next to the executables (what
  `csSmokePlainConsumer` does, plain CMake).
- [x] **Run scripts**: one pair for the whole build instead of one per target, `cs-env.bat` / `cs-env.ps1` (done
  2026-11-11, "Before 1.0").

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
| 6 | in progress | 6a signed off 2026-11-11 (CI green on every variant, incl. the Visual Studio debugger check): B1-B6, D1, D5, D7, S1-S5, C1, C3, C5; D8 decided; 20 unused commands internal: 22 public. 6b signed off 2026-11-11 (CI green on `b5a8937`); 6d, 6c (incl. 6c-5 message review) done: public API 19 commands; Phase 6 complete, sign-off after CI. |

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
- S1: 15 getters read with `get_property()` (empty when unset) instead of `get_target_property` + NOTFOUND branch.

### 2026-11-10 (Phase 6a — S2-S5; v0.4.0 released)
- v0.4.0 release run green (4 assets).
- S2: `_cs_relative_install_folder`, `_cs_headers_per_configuration`. S3: the component cycle check visits each
  component once (24 components with ~75 000 paths: 1 s; 16 levels: 5.4 s -> 0.3 s; generated Config identical);
  test with a timeout (`configure(..., timeout=)`). S4: `cs_target_sources` one loop per scope. S5: list helper with
  `REMOVE_DUPLICATES`, the variable list of CMake read without a file in the build folder.

### 2026-11-10 (Phase 6a — D1, B3)
- `csTargetDependencies` rewritten (~580 -> ~120 lines): `CSCMAKE_PROJECT_DEPENDENCIES` by one walk in
  `cs_finalize_project` (`LINK_LIBRARIES`, `INTERFACE_LINK_LIBRARIES`, aliases, `$<LINK_ONLY:...>`); the Visual Studio
  debugger `PATH` from `$<TARGET_RUNTIME_DLL_DIRS>` (B3). Removed: `cs_get_target_runtime_libraries`, the
  `CSCMAKE_*RUNTIME_LIBRARIES*` / `CSCMAKE_LINKED_*` properties, the missing-file warning, two unused helpers.
  Host smoke (Ninja, GCC) before / after: the 84 installed text files identical (Config, targets, headers). MIGRATION
  section for the next release; docs (runtime dependencies, dependencies).

### 2026-11-11 (Phase 6a — D1 follow-up: runtime folders, project environment, Visual Studio check)
- `cs_target_runtime_environment(<target> [PATH ...] [SET <name>=<value> ...])` (user: extra folders for plugins /
  dynamically loaded libraries, variables such as `QT_PLUGIN_PATH`, as a `cs_` command; documented as rarely needed):
  stored in `CSCMAKE_RUNTIME_DIRS` / `CSCMAKE_RUNTIME_ENVIRONMENT`, rendered by `cs_finalize_project` in the debugger
  environment (later also the run scripts and the test environment). A `VS_DEBUGGER_ENVIRONMENT` of the project is kept,
  its `PATH` line merged: `cs_target_runtime_environment(<t> DEBUGGER_PATH BEFORE|AFTER|OFF)` (default `BEFORE`; per
  target only, user: no project-wide setting until a project needs one; not `PREPEND` / `APPEND`: `set_property()`
  takes them as its own keywords). Configure tests for every case.
- Smoke: csSmokeSharedApp calls `cs_target_runtime_environment` (a folder and a variable per configuration); on the Visual Studio variants `run_smoke.py`
  checks the `LocalDebuggerEnvironment` of its `.vcxproj` for every configuration (extra folder first, then
  `bin/<config>`, then `%PATH%`); parser and check unit-tested.

### 2026-11-11 (Phase 6a — D5)
- A custom configuration copies only the per-configuration variables defined for its base (C++ project, Paranoid: 65
  cache entries -> 6, the non-empty values identical); configure test (fails on the old code); docs (build
  configurations, lifecycle).

### 2026-11-11 (Phase 6a — D7)
- Compile profile rules: `LANGUAGES` (default `CXX`), the compile options and definitions wrapped in
  `$<COMPILE_LANGUAGE:...>`; the shipped profiles split into C-and-C++ rules (warnings valid in C, `-Werror` / `/WX`,
  sanitizers, `/MP`) and C++-only rules (`-Wold-style-cast` ..., `/permissive-`, `/Zc:__cplusplus`, hardening).
  Test on `compile_commands.json` (a C and a C++ source); expectations of the profile tests updated; docs, MIGRATION.

### 2026-11-11 (Phase 6a — status)
- 6a section brought up to date: the committed findings marked done, D8 closed (kept), D2-D4, D6, C4 marked for 6b and
  S6, C2 for 6c; the unused public commands (keep / internal / drop) recorded as the last 6a step.

### 2026-11-11 (Phase 6a — unused public commands)
- 20 commands made internal (`_cs_*`, plain comments instead of reference entries, no gersemi signatures):
  `cs_get_namespace`, `cs_get_default_build_configurations`, the 7 component getters, the 5 per-target getters, 6
  printers. Public: 22 (9 core, 5 features, 5 queries, 2 printers, `cs_debug_message`). MIGRATION rows with what to use;
  user docs (install, targets) no longer name them; csPackageConfig has no public command (its page: properties).

### 2026-11-11 (Phase 6b — plan, 6b-1)
- 6b plan agreed (user): D3 keep `cs_target_link_libraries` and fail fast; D4 `VERSION_COMPATIBILITY`, default
  `SameMajorVersion`; D6 `cs_install_target(<target> COMPONENT <c> [DEFAULT])`, `cs_find_package` kept; D2 two
  printers; reference by tier.
- 6b-1: `CSCMAKE_CLANG_TIDY_EXE` (MIGRATION); `cs_find_package` checks its mode before `find_package` (test).
- 6b-2: `cs_target_link_libraries` = `target_link_libraries` (the alias rewriting dropped: the dependency walk of D1 and
  CMake's export resolve aliases; host smoke: the 84 installed text files identical) + a fail-fast check for links
  after `cs_finalize_target`; tests (the late check of `cs_finalize_project` stays, for plain `target_link_libraries`).
  Assessment of the alias rewriting (user: "aliases were messing up, nested projects"): it served the old dependency
  analysis, which compared names without resolving aliases; the walk of D1 resolves them (also in `$<LINK_ONLY:...>`),
  CMake's export too. Checked with a nested project (outer with a static library linking the inner project's alias
  privately, an alias used before its target exists, a shared library linking aliases of both projects; Ninja
  Multi-Config, Debug + Release): old and new code install the 24 text files identically, a plain consumer links and
  runs; permanent test `test_links_through_aliases_give_the_component_dependencies` (passes with both).

### 2026-11-11 (Phase 6a sign-off)
- CI green on `47cb846` (every variant; the Visual Studio debugger environment checked on the `.vcxproj`): 6a signed off.
- 6b-3: `VERSION_COMPATIBILITY` (default `SameMajorVersion`, checked; `CSCMAKE_VERSION_COMPATIBILITY` set by every
  project, nested ones included) used by `write_basic_package_version_file`; tests: a 2.0.0 package against requests 1.0,
  2.0, 2.0.0, 2.5 (default, `AnyNewerVersion`, `ExactVersion`), an unknown value; MIGRATION, CHANGELOG.
- 6b-4: `cs_install_target(<target> COMPONENT <component> [DEFAULT])` (`cmake_parse_arguments`; the former form fails
  with the signature and MIGRATION); every call site (modules, smoke projects, tests, docs, README) updated.
- 6b-5: `cs_print_target(<target>)` (the csCMake view, then the CMake properties) and `cs_print_project()`
  (configurations, search paths, targets, components and dependencies), always printed; `cs_initialize_project` /
  `cs_finalize_project` print the project with the debug switch only, and compute nothing without it (S6 for the
  printers); the six internal printer pieces removed. Tests.
- 6b-6: `docs/reference/commands.rst` ("Commands by tier": core, features, queries, troubleshooting); the
  troubleshooting page: "Inspecting a target or the project".

### 2026-11-11 (6d and 1.0 items)
- New 6d (automatic finalization, before 6c; the finalize commands removed, no deprecation step); the 1.0 list gains
  a compatibility page, docs examples from the smoke projects, a relocation smoke step, the scope and CMake 3.31
  notes. The preset / setup pair stays (project and per-variant settings, e.g. the OpenCV forks).

### 2026-11-11 (Phase 6d)
- `cs_initialize_project` defers `_cs_finalize_project` to the end of its CMakeLists.txt: `_cs_finalize_target` (compile
  profiles, `_CSCMAKE_FINALIZED`) for every target, run-time dependencies, install, Config, debug print.
  `cs_finalize_target` / `cs_finalize_project`, the "not finalized" / "links changed" checks and the deferred check
  removed. `cs_add_*` copy `CSCMAKE_DEFAULT_COMPILE_PROFILES` into `CSCMAKE_COMPILE_PROFILES` and set the install
  RPATH at creation. `cs_target_link_libraries` / `cs_target_runtime_environment` fail after the finalization; the
  printers defer themselves after it. Error prefixes of the finalization: `[csCMake]`.
- Tests: `after_finalize()` helper (a deferred block); `test_finalize.py` rewritten (profiles defined late still
  apply, nested project finalized first, folder variables taken at creation); late links / runtime environment fail.
- Host smoke: the 170 installed files and the compile commands of the 28 build trees identical to 6b.
- 6b signed off: CI green on `b5a8937` (every variant).

### 2026-11-11 (Phase 6c)
- Decisions: CMake's log levels only; `cs_debug_message`, `<project>_CSCMAKE_DEBUG`, `_cscmake_debug_option`, the
  Config's `<Ns>_DEBUG` removed; the 19 algorithm traces of `csPackageConfig` dropped.
- `csDebug`: `_cs_log_level_at_least` (`GET_MESSAGE_LOG_LEVEL`, S6), `_cs_message_context` (namespace once + command);
  `_cs_print_project(<level> <header>)`. `VERBOSE`: project, targets, packages, components installed, at the
  finalization each target's dependencies, each component, the Config; `DEBUG`: arguments, sources, links, profiles,
  configuration mapping and copies, installed files, install RPATH, debugger environment, the project at the end.
- C2: the 8 errors naming internal functions now name `cs_initialize_project` (configuration syntax rewritten with
  the form and an example) or `[csCMake]` (no project).
- Config: `VERBOSE` `<Ns>: component <c>` / unknown component; `DEBUG` `<Ns>: find_dependency(...)`.
- Tests: levels (none / VERBOSE / DEBUG), context and indent, a `block()`, the Config at each level; docs:
  troubleshooting "Debugging csCMake", targets, install, lifecycle, packages, contributing.

### 2026-11-11 (Phase 6c-5: message review)
- Committed 6c as `19f8103`. Review of what is missing (user: "is the debug info informative enough?"):
  `VERBOSE` for `cs_target_use_compile_profiles`, `cs_target_runtime_environment` (what it adds),
  `cs_target_check_installed_headers` (how many headers), `cs_find_package` (found or not, version, folder), a nested
  project (configurations from the first project); `DEBUG` for each compile profile rule when defined and when applied
  to a target (marked when not for this compiler or platform, nested profiles indented).
- Every error checked against `[<command>] <subject>: <what is wrong>; <what to do>`: 12 rewritten (two csCMake
  folders, DEFAULT_CONFIG, configuration given twice (one unreachable check removed), nested configurations, build
  type, header check, profile rule, undefined profile, not a target, OpenMP scope, `SET PATH=`, `CSCMAKE_DEBUGGER_PATH`).
- Tests: `tests/cmake/test_messages.py` (5). Host smoke: installed files and compile commands identical to 6c.
- Coverage of `check_docs.py` line 148 (CI, `19f8103`): no entry outside the `CSCMAKE_*` naming is left in the
  repository (`_cscmake_debug_option` removed); a unit test documents a lowercase variable, used and unused.
### 2026-11-11 (run-time environment scripts)
- User: a single `.bat` and `.ps1` next to the `.sln` with the accumulated `PATH` of the shared libraries, the
  debugger variables and manual tuning; double-click opens a terminal, or used from a terminal. Per configuration only
  when needed (user: "if they differ, ask; if equal, good to go"): the DLL folders are generator expressions (known at
  generate time), so one file per configuration is written and the dispatcher compares them when it runs.
- `_cs_defer_runtime_scripts` (first `cs_initialize_project`: defers to the end of the top folder),
  `_cs_write_runtime_scripts`, `_cs_runtime_scripts_environment`, `_cs_add_runtime_script_variables`
  (`csTargetDependencies`); `templates/csTemplateEnv.bat.in|.ps1.in`; variable `CSCMAKE_RUNTIME_SCRIPTS`.
- Docs: user guide (dependencies: "Running from a terminal on Windows"), internals, reference. Removed the stale
  "debug option" from the nested projects list of the user guide.
- Tests: `tests/cmake/test_runtime_scripts.py` (9), smoke unit test of the output check. Host smoke: installed files
  and compile commands identical to 6c-5, no scripts on Linux.
### 2026-11-11 (relocation smoke step; CMake 3.31 item)
- Committed the run-time environment scripts as `33cfa8f`.
- `run_smoke.py`: `check_relocation` after every project (`relocate_install`, `relocated_prefixes`,
  `rebuild_against_relocated_install`); `check_installed_apps` takes the install folder of the project. Host smoke:
  the rebuilt consumers find csSmokeShared, csSmokeMidA, csSmokeMidB, csSmokeBase in `install-relocated/`; first try
  found nothing to delete (build folders are per configuration, `<project>/<config>`), fixed. Docs: smoke-tests.
- User: "why CMake 3.31" needs no page: a parenthesis on the getting-started line (docs batch).
