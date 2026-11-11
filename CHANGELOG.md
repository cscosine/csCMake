# Changelog

The changes of each csCMake release. Releases and their assets (the csCMake package, the documentation): GitHub
Releases of this repository. How a release is made: [Releasing](docs/contributing/releasing.md).

## Unreleased

### Changed

- The Visual Studio debugger environment of a target comes from CMake's `$<TARGET_RUNTIME_DLL_DIRS>`: the DLLs of
  every linked target, per configuration, with the configuration CMake selects for each imported target (a package
  installed in Release only, a custom configuration mapped to Debug, private links of static libraries: their DLLs
  were missing). Set on executables and shared / module libraries.
- The targets a target depends on (`CSCMAKE_PROJECT_DEPENDENCIES`, the dependencies between components) are resolved
  once when the project is finalized, following `$<LINK_ONLY:...>` links too.
- A `VS_DEBUGGER_ENVIRONMENT` set by the project is kept: csCMake adds its lines after the project's, and merges its
  folders into the project's `PATH` line (`DEBUGGER_PATH` of `cs_target_runtime_environment`).
- A custom configuration creates cache entries only for the per-configuration variables defined for its base (e.g. 6
  instead of 65 for a C++ project: no empty `CMAKE_Fortran_FLAGS_PARANOID` ...).

- The clang-tidy executable of the compile profiles: cache variable `CSCMAKE_CLANG_TIDY_EXE` (was `CLANG_TIDY_EXE`, a
  name projects may use themselves).
- `cs_find_package` checks its mode (`PUBLIC` / `PRIVATE`) before `find_package` runs.

- `cs_target_link_libraries` passes its arguments to `target_link_libraries` as they are (aliases kept: CMake and
  csCMake resolve them), and fails at the call for links added after the project is finalized (e.g. from a parent
  project).

- The project is finalized automatically at the end of the `CMakeLists.txt` of `cs_initialize_project`
  (`cmake_language(DEFER)`): compile profiles, dependencies, install rules and `<namespace>Config.cmake`. A target
  takes the folder values of `CSCMAKE_DEFAULT_COMPILE_PROFILES` (into `CSCMAKE_COMPILE_PROFILES`) and
  `CSCMAKE_INSTALL_RPATH` (its install RPATH) when `cs_add_library` / `cs_add_executable` creates it.
  `cs_print_target` / `cs_print_project` called in the project print after the finalization.

- Messages with CMake's log levels: `VERBOSE` what csCMake does (one line per project, target, package, component,
  dependency), `DEBUG` the details; `--log-context` prefixes `[<namespace>.<command>]`, sub-steps indented; a
  `block()` with `CMAKE_MESSAGE_LOG_LEVEL` shows the messages of some calls only. The installed `<namespace>Config.cmake`
  says what it loads at `VERBOSE`. `cs_find_package` says whether the package was found, its version and folder; the
  rules of the compile profiles applied to each target are listed at `DEBUG`. Error messages name the public command,
  not internal functions, and say what to do.

- The installed `<namespace>ConfigVersion.cmake` accepts the requests of the same major version
  (`SameMajorVersion`: 1.4 for `find_package(<namespace> 1.2)`, not 2.0; it accepted any older request before):
  `VERSION_COMPATIBILITY` of `cs_initialize_project` chooses another one.

- `cs_install_target(<target> COMPONENT <component> [DEFAULT])`: the component after the keyword `COMPONENT`, like the
  other `cs_target_*` commands and `install(... COMPONENT)` (see MIGRATION.md).

### New

- Compile profile rules take `LANGUAGES <language>...`: the source languages of their compile options and definitions,
  `CXX` when not given. The shipped profiles give C sources only the options valid in C (warnings, warnings as errors,
  sanitizers, `/MP`): C files no longer get `-Wold-style-cast` and the other C++-only options. Rules of a project
  without `LANGUAGES` no longer apply to its C sources: add `LANGUAGES C CXX` where they should.
- `cs_target_runtime_environment(<target> [PATH <folder>...] [SET <name>=<value>...] [DEBUGGER_PATH ...])`: what
  CMake cannot know about the run-time environment of a target (plugins, libraries loaded at run time, variables such
  as `QT_PLUGIN_PATH`), added to its Visual Studio debugger environment; `DEBUGGER_PATH` `BEFORE` (default) / `AFTER`
  / `OFF` for a target whose `VS_DEBUGGER_ENVIRONMENT` the project writes itself.

- `cs_initialize_project(... VERSION_COMPATIBILITY AnyNewerVersion|SameMajorVersion|SameMinorVersion|ExactVersion)`.

- `cs_print_target(<target>)` and `cs_print_project()`: what csCMake knows about a target (component, headers,
  packages, profiles, run-time environment, dependencies, CMake properties) or the project (configurations, search
  paths, targets, components and their dependencies), always printed. The reference has a "Commands by tier" page,
  the troubleshooting page says when to use which printer.

### Removed

- `cs_finalize_target` and `cs_finalize_project`: the project and its targets are finalized automatically (see
  MIGRATION.md: delete the calls).
- The debug option `<project>_CSCMAKE_DEBUG`, `cs_debug_message` and the `<namespace>_DEBUG` of the installed packages:
  CMake's log levels (`--log-level=VERBOSE|DEBUG`).
- `cs_print_target_properties` and `cs_print_state` (debug messages only): `cs_print_target` and `cs_print_project`.
- 20 commands no project uses became internal (see MIGRATION.md): `cs_get_namespace`,
  `cs_get_default_build_configurations`, the component and per-target getters (`cs_get_components`,
  `cs_get_target_find_packages`, ...), and the printers other than `cs_print_target_properties` and `cs_print_state`.
  The public API: 19 commands.
- `cs_get_target_runtime_libraries` and the target properties `CSCMAKE_RUNTIME_LIBRARIES_<CONFIG>`,
  `CSCMAKE_DIRECT_RUNTIME_LIBRARIES_<CONFIG>`, `CSCMAKE_LINKED_PROJECT_TARGETS`, `CSCMAKE_LINKED_NON_TARGETS`: use
  `$<TARGET_RUNTIME_DLLS>` / `$<TARGET_RUNTIME_DLL_DIRS>` (see MIGRATION.md).

### Fixed

- `cs_target_check_installed_headers`: headers with the same name (`a/util.h` and `b/util.h`, `util.h` and
  `util.hpp`) and headers at the base of the project are checked; the check is one library
  `<target>_installed_headers` (instead of one library `<target>_<header>` per header).
- `cs_target_sources`: `PUBLIC` / `INTERFACE` files (and `*_INSTALL`) given by relative path no longer fail at the
  generate step.
- Single-config generators: an empty `CMAKE_BUILD_TYPE` fails the configure (it built none of the configurations of
  the project); the message for an unknown one lists the configurations.
- `cs_target_use_openmp`: `find_package(OpenMP)` goes to the installed package only when its consumers link OpenMP
  (`PUBLIC`, `INTERFACE`, or `PRIVATE` on a static library); no messages on every configure.
- `cs_add_library` / `cs_add_executable` before `cs_initialize_project`: a clear message.
- `cs_print_state` prints the folder of csCMake.

## v0.4.0 (2026-11-10)

The documentation site and the supported variants as data. No change of the `cs_*` commands or of the presets.

### New

- `presets/csv1/variants.json`: the supported variants as data (id, fields, short forms, generator type, build
  configurations), generated with the presets, for tools that follow them.

### Documentation

- A new theme (Furo, light and dark), a landing page with what csCMake solves (examples with and without csCMake),
  and a "Design decisions" page.

## v0.3.0 (2026-11-10)

Fixes for projects consumed in configurations they were not built in, install RPATH, and gersemi as formatter. No
change of the `cs_*` commands. Action for projects formatting with csCMake's `.cmake-format.json`: switch to gersemi
(see Formatting your CMake files).

### Changed

- Formatting: gersemi, with the `cs_*` signatures in the extension `gersemi/cscmake.py` and the configuration
  `.gersemirc` (both in the release package, instead of `.cmake-format.json`); see Formatting your CMake files.
- The CMake modules are in `modules/` (`modules/integrations/` for third-party integrations, e.g. OpenMP), reorganised
  by subject: the reference pages are renamed (`csProject`, `csTargets`, `csBaseInclude`, `csPackageConfig`,
  `csCheckInstalledHeaders`, `csCompileProfilesShipped`, `csDebug`). The commands are unchanged: projects include
  `csCMake` only.
- `CMAKE_CXX_STANDARD_REQUIRED`, `CMAKE_CXX_EXTENSIONS` and `CMAKE_EXPORT_COMPILE_COMMANDS` set by a project are kept.
- The installed `<namespace>Config.cmake` reads `<namespace>_DEBUG` as a plain variable: no cache entry in the
  consumers.

### New

- Install RPATH: installed executables and shared libraries find the shared libraries of their package (Linux, macOS);
  `INSTALL_RPATH OFF` of `cs_initialize_project` or `CSCMAKE_INSTALL_RPATH` turns it off.

### Fixed

- A consumer configuration that a package was not built in (e.g. `MinSizeRel` with Visual Studio and Xcode) no longer
  fails with a non-existent include folder: the include folders of a package follow the configuration CMake selects
  for it (`CMAKE_MAP_IMPORTED_CONFIG_<CONFIG>`), like its libraries.
- C++-only projects: no "not used" warning for the `CMAKE_C_COMPILER` of the presets.

## v0.2.0 (2026-11-10)

A consistent API, compile profiles, macOS, and documentation. This release breaks compatibility with v0.1.0, with no
deprecated aliases: [MIGRATION.md](MIGRATION.md) lists every rename and the actions to take.

### Breaking

- Commands, variables and properties renamed to `cs_<name>` / `CSCMAKE_*`; introspection commands renamed; internal
  commands become `_cs_*`.
- `cs_initialize_project(NAMESPACE <namespace> ...)` and `cs_finalize_project()`: the namespace is the package name and
  the prefix of the installed targets. The base include target is `<namespace>::cscmake_base_include`.
- Compile options are compile profiles: the strict and default option targets, `STRICT_COMPILATION_ON_CONFIG`,
  `cs_exec_clang_tidy` and `cs_compileEachInstalledInclude` are replaced by `cs_add_compile_profile_rule`,
  `cs_target_use_compile_profiles` and `cs_target_check_installed_headers`.
- Project setup presets: the project's `csCMakeProjectSetup.json` includes a layout, `presets/layout/<layout>.json`.
- Mandatory calls, checked at configure time: `cs_finalize_target` for every target, after its links;
  `cs_finalize_project` at the end of the top `CMakeLists.txt`.
- CMake 3.31 or newer; `project()` needs a `VERSION`.
- Configure in a fresh build folder and install into an empty prefix.

### New

- Compile profiles: `cscmake_default`, `cscmake_warnings`, `cscmake_warnings_as_errors`, `cscmake_strict_warnings`,
  sanitizers (`cscmake_sanitize_undefined`, `cscmake_sanitize_address`), standard library hardening
  (`cscmake_hardening_fast`, `cscmake_hardening_debug`) and `cscmake_clang_tidy`; rules by configuration, compiler,
  command-line style and platform; default profiles per project or per folder.
- macOS presets (Apple Silicon, Apple Clang, Ninja, Ninja Multi-Config and Xcode).
- Workspace layouts (`presets/layout/`): `sibling`, `standalone` and the new `env`, each also with short build paths.
- Installed package configuration: per-component `<namespace>_<component>_FOUND`; an unknown component makes
  `find_package` fail cleanly (`REQUIRED`, `OPTIONAL_COMPONENTS` and `QUIET` work).
- Overridable cache variables: postfixes per configuration, MSVC runtime library per configuration, output folders.
- Visual Studio debugger `PATH` per configuration from the runtime libraries of the target.
- Documentation site: user guide, tutorials, advanced pages and the reference of every command, variable and property.
- Release package: `csCMake-<version>.tar.gz` / `.zip`, the documentation zip and `SHA256SUMS` on every release.

### Fixed

- `cs_target_sources` resolves relative paths from the current source folder.
- Headers keep their path relative to the folder of `cs_initialize_project` when the project is added with
  `add_subdirectory`.
- Debug messages are printed only with `<project>_CSCMAKE_DEBUG`.

## v0.1.0 (2026-07-07)

First tagged version: the `cs_*` commands, installed packages with components, and the generated presets for Linux and
Windows.
