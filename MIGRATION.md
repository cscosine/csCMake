# Migrating from v0.1.0 to v0.2.0

v0.2.0 renames the csCMake API to consistent names and fixes behaviours that cannot be fixed compatibly.
There are **no deprecated aliases**: the old names are removed, a project using them fails at configure time with
`Unknown CMake command "<old name>"`. Apply the tables below (plain search and replace: CMake command names are
case-insensitive, look for every spelling).

The documentation of the new API: the [user guide](docs/user/getting-started.md) and the reference (see
[README](README.md#documentation)).

## Functions

Functions acting on a target are named `cs_target_*` (like CMake's `target_*`); every other public function is
`cs_snake_case`, the internal ones `_cs_snake_case`.

### Public functions renamed

| Old | New |
|---|---|
| `csUseOpenMPOnTarget` | `cs_target_use_openmp` |
| `cs_compileEachInstalledInclude` | `cs_target_check_installed_headers` |
| `cs_exec_clang_tidy` | a compile profile with `cscmake_clang_tidy` (see "Compile profiles") |
| `cs_get_generate_folder_common` | `cs_get_generated_dir` |
| `cs_get_generate_folder_config` | `cs_get_generated_config_dir` |

### Introspection functions renamed

Getters and debug printers of the csCMake state. An install export is called a *component* everywhere, as in
`find_package(<Package> COMPONENTS ...)`.

| Old | New |
|---|---|
| `cs_get_all_targets` | `cs_get_project_targets` |
| `cs_print_all_target` | `cs_print_project_targets` |
| `cs_get_specified_build_configurations` | `cs_get_build_configurations` |
| `cs_get_specified_build_configurations_default` | `cs_get_default_build_configurations` |
| `csGetConfigurationWithStrictFlags` | removed: compile profiles choose the configurations (see "Compile options: compile profiles") |
| `cs_get_install_folder_suffix` | `cs_get_install_include_dir` |
| `cs_get_exported_list` | `cs_get_components` |
| `cs_get_exported_list_default` | `cs_get_default_components` |
| `cs_get_target_exported_to` | `cs_get_target_component` |
| `cs_get_exported_targets` | `cs_get_component_targets` |
| `cs_get_exported_find_packages` | `cs_get_component_find_packages` |
| `cs_get_exported_depends` | `cs_get_component_dependencies` |
| `cs_get_exported_depends_sorted` | `cs_get_component_dependencies_sorted` |
| `cs_print_exported_list_details` | `cs_print_components` |
| `cs_get_target_dependencies_libraries_finalized` | `cs_get_target_runtime_libraries` |
| `cs_get_target_dependencies` | `cs_get_target_project_dependencies` |
| `cs_print_state_info` | `cs_print_state` |

### Functions that became internal

Not part of the API any more: do not call them (they may change without notice). If you need one, open an issue.

| Old | Internal name |
|---|---|
| `cs_set_base_path` | `_cs_set_root_dir` |
| `cs_get_base_path` | `_cs_get_root_dir` |
| `cs_copy_configuration_type` | `_cs_copy_build_configuration` |
| `cs_extract_unique_folders_list_from_file_list` | `_cs_unique_parent_dirs` |
| `cs_get_build_configurations_variables` | `_cs_get_per_config_variables` |
| `cs_get_target_dependencies_libraries` | `_cs_get_target_direct_runtime_libraries` |
| `cs_get_target_dependencies_not_imported_targets` | `_cs_get_target_linked_project_targets` |
| `cs_get_target_dependencies_not_targets` | `_cs_get_target_linked_non_targets` |

## Variables

Every csCMake variable starts with `CSCMAKE_` (or `<project>_CSCMAKE_`).

### Set in your presets or on the command line

| Old | New | Kind |
|---|---|---|
| `WORKSPACE_ROOT` | `CSCMAKE_WORKSPACE_ROOT` | preset environment (set by the layouts, `presets/layout/*.json`) |
| `CS_CMAKE_ROOT` | `CSCMAKE_ROOT` | preset environment |
| `CS_CMAKE_PREFIX_PATH_PREFIX` / `CS_CMAKE_PREFIX_PATH_SUFFIX` | `CSCMAKE_PREFIX_PATH_HEAD` / `CSCMAKE_PREFIX_PATH_TAIL` | environment (passed by the presets) or `-D` |
| `CS_CMAKE_CSV1_SUB_DIR`, `CS_CMAKE_CSV1_SUB_DIR_SHORT`, `CS_CMAKE_CSV1_SINGLE_CONFIG_SUB_DIR` | `CSCMAKE_CSV1_SUB_DIR`, `CSCMAKE_CSV1_SUB_DIR_SHORT`, `CSCMAKE_CSV1_SINGLE_CONFIG_SUB_DIR` | preset environment |
| `CS_CMAKE_PREFIX_PATH_HEAD` / `CS_CMAKE_PREFIX_PATH_TAIL` | `CSCMAKE_PREFIX_PATH_HEAD` / `CSCMAKE_PREFIX_PATH_TAIL` | `-D` or environment (passed by the presets) |
| `CS_CMAKE_MODULE_PATH_HEAD` / `CS_CMAKE_MODULE_PATH_TAIL` | `CSCMAKE_MODULE_PATH_HEAD` / `CSCMAKE_MODULE_PATH_TAIL` | `-D` or environment (passed by the presets) |
| `<project>_CS_CMAKE_DEBUG` | `<project>_CSCMAKE_DEBUG` | CMake option (`-D...=ON`) |

`$env{WORKSPACE_ROOT}` / `$env{CS_CMAKE_ROOT}` references in your own preset files must be renamed too.

Unchanged: `CSCMAKE_<CONFIG>_POSTFIX`, `CSCMAKE_MSVC_RUNTIME_LIBRARY_<CONFIG>`,
`CSCMAKE_MSVC_RUNTIME_LIBRARY_GENERATOR_EXPRESSION`.

## Properties

Global and target properties set by csCMake are named `CSCMAKE_*`, with the build configuration in upper case where
it is part of the name (like CMake's own `<CONFIG>` properties). You only need this table if your CMake code reads them
directly (`get_property` / `get_target_property`); otherwise use the getter functions.

### Global properties

| Old | New |
|---|---|
| `csCMakeBasePath` | `CSCMAKE_ROOT_DIR` |
| `csCMakeConfigurationTypes` | `CSCMAKE_BUILD_CONFIGURATIONS` |
| `csCMakeConfigurationTypesDefault` | `CSCMAKE_DEFAULT_BUILD_CONFIGURATIONS` |
| `csCMakeConfigurationVariables` | `CSCMAKE_PER_CONFIG_VARIABLES` |
| `csCMakeConfigWithStrictFlags` | removed (compile profiles) |
| `csProjectTargets` | `CSCMAKE_<namespace>_PROJECT_TARGETS` |
| `csExportedList` | `CSCMAKE_<namespace>_COMPONENTS` |
| `csExportedListDefault` | `CSCMAKE_<namespace>_DEFAULT_COMPONENTS` |
| `csExported<component>Targets` | `CSCMAKE_<namespace>_COMPONENT_<component>_TARGETS` |
| `csExported<component>FindPackages` | `CSCMAKE_<namespace>_COMPONENT_<component>_FIND_PACKAGES` |
| `csExported<component>Depends` | `CSCMAKE_<namespace>_COMPONENT_<component>_DEPENDENCIES` |
| `csExported<component>DependsSorted` | `CSCMAKE_<namespace>_COMPONENT_<component>_DEPENDENCIES_SORTED` |

### Target properties

| Old | New |
|---|---|
| (none) | `CSCMAKE_NAMESPACE`: the namespace of the csCMake project of the target |
| `csFindPackage` | `CSCMAKE_FIND_PACKAGES` |
| `csSourcesToInstall` | `CSCMAKE_SOURCES_TO_INSTALL` |
| `csSourcesToInstallAbsolutePath` | `CSCMAKE_SOURCES_TO_INSTALL_ABSOLUTE` |
| `csTargetExportedTo` | `CSCMAKE_COMPONENT` |
| `csTargetDependencies<Config>` | `CSCMAKE_DIRECT_RUNTIME_LIBRARIES_<CONFIG>` |
| `csTargetDependencies<Config>Finalized` | `CSCMAKE_RUNTIME_LIBRARIES_<CONFIG>` |
| `csTargetDependenciesNotImportedTargets` | `CSCMAKE_LINKED_PROJECT_TARGETS` |
| `csTargetDependenciesNonTargets` | `CSCMAKE_LINKED_NON_TARGETS` |
| `csTargetDependencies` | `CSCMAKE_PROJECT_DEPENDENCIES` |
| `csTargetDependenciesToAnalyze` | `_CSCMAKE_PENDING_DEPENDENCIES` (internal) |

## Namespace and default targets

### Namespace

| Old | New |
|---|---|
| `cs_initialize_project(<project> CXX_STANDARD ...)` | `cs_initialize_project(NAMESPACE <namespace> CXX_STANDARD ...)` |
| `cs_finalize_project(<namespace>)` | `cs_finalize_project()` |

```cmake
cs_initialize_project(NAMESPACE myApp CXX_STANDARD 17 ...)
...
cs_finalize_project()
```

The namespace is the prefix of the installed targets (`<namespace>::<target>`) and the package name
(`find_package(<namespace>)`). `cs_get_namespace(<out-var>)` returns it; it is also the read-only variable
`CSCMAKE_NAMESPACE` of the directory of `cs_initialize_project` and its subdirectories. A call with the old arguments
fails at configure time with a message pointing here.

### Default targets

The default targets have the same name in the build tree and once installed:

| Old (build tree) | Old (installed) | New |
|---|---|---|
| `<project>::<project>_csCMakeBaseInclude` | `<namespace>::<project>_csCMakeBaseInclude` | `<namespace>::cscmake_base_include` |
| `<project>::<project>_csCMakeCompileOptionsDefault` | `<namespace>::<project>_csCMakeCompileOptionsDefault` | compile profile `cscmake_default` (every target by default) |
| `<project>::<project>_csCMakeCompileOptionsStrict` | `<namespace>::<project>_csCMakeCompileOptionsStrict` | compile profile `cscmake_strict_warnings` |
| `<project>::<project>MSVCParallelCompile` | `<namespace>::<project>MSVCParallelCompile` | compile profile `cscmake_default` |
| `<project>::<project>StrictCompilation` | `<namespace>::<project>StrictCompilation` | compile profile `cscmake_strict_warnings` |
| component `<project>_csCMakeCommon` | | component `cscmake_common` |

`<project>` is the name of the top `project()`.

## Behaviour

### Requirements

| Requirement | Action |
|---|---|
| CMake 3.31 or newer (checked by `csCMake.cmake`) | `cmake_minimum_required(VERSION 3.31)` in your top `CMakeLists.txt` (csCMake does not set it) |
| `project(<name> VERSION <x.y.z> ...)` (the version of the installed package) | add a `VERSION` if missing |

### Cache variables and project variables

Overridable with `-D<variable>=<value>` (cache variables):

| Variable | Default |
|---|---|
| `CSCMAKE_DEBUG_POSTFIX`, `CSCMAKE_RELEASE_POSTFIX`, `CSCMAKE_RELWITHDEBINFO_POSTFIX` | `d`, none, `rd` |
| `CSCMAKE_MSVC_RUNTIME_LIBRARY_<CONFIG>` | `MultiThreadedDebugDLL` (Debug), `MultiThreadedDLL` |
| per-configuration variables of a custom configuration (`CMAKE_CXX_FLAGS_<CUSTOM>`, ...) | copied from the configuration it is based on |
| `CMAKE_{RUNTIME,LIBRARY,ARCHIVE}_OUTPUT_DIRECTORY` (+ `_<CUSTOM>`) | `<build>/bin`, `<build>/lib` (`/<config>` with multi-config generators) |

Normal variables of the project scope, set by `cs_initialize_project` from its arguments: `CSCMAKE_<CUSTOM>_POSTFIX`
(`POSTFIX`), `CMAKE_MAP_IMPORTED_CONFIG_<CONFIG>`, `CSCMAKE_MSVC_RUNTIME_LIBRARY_GENERATOR_EXPRESSION`,
`CMAKE_MSVC_RUNTIME_LIBRARY`. `CMAKE_CONFIGURATION_TYPES` is set by csCMake.

Action: configure in a fresh build folder (the cache of an existing one keeps entries of the previous version), e.g.
`cmake --workflow --preset <preset> --fresh`, and install into an empty prefix (or delete the previous installation):
`cmake --install` does not remove the files of the previous layout (e.g. `targets/<project>_csCMakeCommonTargets.cmake`).

### Debug messages

| Old | New |
|---|---|
| `-D<top-level project>_CS_CMAKE_DEBUG=ON` | `-D<project>_CSCMAKE_DEBUG=ON`, `<project>` = the `project()` calling `cs_initialize_project` |
| `cs_debug_message("<text>" True)` | `message(STATUS "<text>")` for text that must always be printed |
| `cs_debug_message("<text>")` | unchanged; `cs_debug_message(<text>...)` concatenates its arguments like `message()` |

csCMake prints debug messages only with the option on. An imported library whose file does not exist is a warning.

### Installed headers

Headers keep their path relative to the folder of `cs_initialize_project`. Nothing to change for a project built on
its own; a csCMake project added with `add_subdirectory` installs its headers relative to its own folder.

### Installed package configuration (`<namespace>Config.cmake`)

| Old | New |
|---|---|
| unknown component: `FATAL_ERROR` | `<namespace>_<component>_FOUND` FALSE; if required, `<namespace>_FOUND` FALSE with `<namespace>_NOT_FOUND_MESSAGE` (`find_package(... REQUIRED)` fails, `OPTIONAL_COMPONENTS` and `QUIET` work) |
| no per-component result | `<namespace>_<component>_FOUND` for every requested component |
| `<component>_DEPENDENT_EXPORTS` | `<namespace>_<component>_DEPENDENCIES` |
| `<namespace>_BASE_DIR` | unchanged: the install prefix of the package |

Action: none for `find_package` users; code reading `<component>_DEPENDENT_EXPORTS` uses
`<namespace>_<component>_DEPENDENCIES`.

### Mandatory calls

| Call | Rule (checked at configure time) |
|---|---|
| `cs_finalize_target(<target>)` | for every target of `cs_add_library` / `cs_add_executable`, after its links; `cs_finalize_project` fails listing the targets not finalized and those with links added after `cs_finalize_target` |
| `cs_finalize_project()` | at the end of the `CMakeLists.txt` of `cs_initialize_project`; configure fails at the end of that file without it |

Action: add the missing calls, and move `cs_finalize_target` after the last `cs_target_link_libraries` of the target.

### Project setup presets (`csCMakeProjectSetup.json` of the project)

| Old include | New include |
|---|---|
| `${sourceParentDir}/csCMake/presets/csCMakeProjectSetup-default.json` | `${sourceParentDir}/csCMake/presets/layout/sibling.json` |
| `${sourceParentDir}/csCMake/presets/csCMakeProjectSetup-shortBuildPath.json` | `${sourceParentDir}/csCMake/presets/layout/sibling-short.json` |
| `${sourceDir}/workspace/csCMake/presets/csCMakeProjectSetup-default-standalone.json` | `${sourceDir}/workspace/csCMake/presets/layout/standalone.json` |
| (none) | `.../presets/layout/standalone-short.json`, `$penv{CSCMAKE_ROOT}/presets/layout/env.json`, `.../env-short.json` |

`csCMakeProjectSetup-base.json` / `-base-standalone.json` are replaced by `presets/csCMakeProjectSetup.json` (preset
`cscmake-common-project-setup`); a project defining its own setup inherits it and sets `CSCMAKE_WORKSPACE_ROOT`,
`CSCMAKE_ROOT` and `CSCMAKE_BUILD_SUB_DIR` (see [Presets](docs/user/presets.md#layouts)).

### Compile options: compile profiles

| Old | New |
|---|---|
| `cs_target_link_libraries(<t> ... <ns>::<project>_csCMakeCompileOptionsDefault)` | nothing: `cscmake_default` applies to every target |
| `cs_target_link_libraries(<t> ... <ns>::<project>_csCMakeCompileOptionsStrict)` | `cs_target_use_compile_profiles(<t> cscmake_strict_warnings)` |
| `cs_initialize_project(... STRICT_COMPILATION_ON_CONFIG Paranoid)` | `cs_add_compile_profile_rule(PROFILE <ns>_paranoid CONFIGS Paranoid PROFILES cscmake_sanitize_undefined)` and `DEFAULT_COMPILE_PROFILES cscmake_default <ns>_paranoid` (or `cs_target_use_compile_profiles`) |
| `cs_exec_clang_tidy(<t>)` | a rule with `PROFILES cscmake_clang_tidy` (or `CLANG_TIDY`) with the configurations / compilers / platforms where it runs, used by `<t>`; checks in `.clang-tidy` |
| `cs_compileEachInstalledInclude(<t> <ns>::<project>_csCMakeCompileOptionsStrict)` | `cs_target_check_installed_headers(<t> COMPILE_PROFILES cscmake_strict_warnings)` |

`csGetConfigurationWithStrictFlags` and the target property `CXX_CLANG_TIDY` set by `cs_exec_clang_tidy` are gone.
Differences: the warnings are private to each target (not propagated to consumers); clang-cl gets the MSVC-style
`/W4 /permissive-` instead of the GCC-style list; MSVC gets the off-by-default warnings listed in [Compile profiles](docs/user/compile-profiles.md).
