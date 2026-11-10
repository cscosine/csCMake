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
  once by `cs_finalize_project`, following `$<LINK_ONLY:...>` links too.

### Removed

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
