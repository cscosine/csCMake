# Migrating to the next csCMake release

The next release renames the csCMake API to consistent names and fixes behaviours that cannot be fixed compatibly.
There are **no deprecated aliases**: the old names are removed, a project using them fails at configure time with
`Unknown CMake command "<old name>"`. Apply the tables below (plain search and replace: CMake command names are
case-insensitive, look for every spelling).

This file grows with every change of the release; the sections not yet filled are still to come.

## Functions

Functions acting on a target are named `cs_target_*` (like CMake's `target_*`); every other public function is
`cs_snake_case`, the internal ones `_cs_snake_case`.

### Public functions renamed

| Old | New |
|---|---|
| `csUseOpenMPOnTarget` | `cs_target_use_openmp` |
| `cs_compileEachInstalledInclude` | `cs_target_check_installed_headers` |
| `cs_exec_clang_tidy` | `cs_target_enable_clang_tidy` |
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
| `csGetConfigurationWithStrictFlags` | `cs_get_strict_build_configuration` |
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

| Old | Internal name now |
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
| `WORKSPACE_ROOT` | `CSCMAKE_WORKSPACE_ROOT` | preset environment (`csCMakeProjectSetup-base*.json`) |
| `CS_CMAKE_ROOT` | `CSCMAKE_ROOT` | preset environment |
| `CS_CMAKE_PREFIX_PATH_PREFIX` / `CS_CMAKE_PREFIX_PATH_SUFFIX` | `CSCMAKE_PREFIX_PATH_PREFIX` / `CSCMAKE_PREFIX_PATH_SUFFIX` | environment, read by the presets |
| `CS_CMAKE_CSV1_SUB_DIR`, `CS_CMAKE_CSV1_SUB_DIR_SHORT`, `CS_CMAKE_CSV1_SINGLE_CONFIG_SUB_DIR` | `CSCMAKE_CSV1_SUB_DIR`, `CSCMAKE_CSV1_SUB_DIR_SHORT`, `CSCMAKE_CSV1_SINGLE_CONFIG_SUB_DIR` | preset environment |
| `CS_CMAKE_PREFIX_PATH_HEAD` / `CS_CMAKE_PREFIX_PATH_TAIL` | `CSCMAKE_PREFIX_PATH_HEAD` / `CSCMAKE_PREFIX_PATH_TAIL` | CMake variable (`-D`) |
| `CS_CMAKE_MODULE_PATH_HEAD` / `CS_CMAKE_MODULE_PATH_TAIL` | `CSCMAKE_MODULE_PATH_HEAD` / `CSCMAKE_MODULE_PATH_TAIL` | CMake variable (`-D`) |
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
| `csCMakeConfigWithStrictFlags` | `CSCMAKE_STRICT_BUILD_CONFIGURATION` |
| `csProjectTargets` | `CSCMAKE_PROJECT_TARGETS` |
| `csExportedList` | `CSCMAKE_COMPONENTS` |
| `csExportedListDefault` | `CSCMAKE_DEFAULT_COMPONENTS` |
| `csExported<component>Targets` | `CSCMAKE_COMPONENT_<component>_TARGETS` |
| `csExported<component>FindPackages` | `CSCMAKE_COMPONENT_<component>_FIND_PACKAGES` |
| `csExported<component>Depends` | `CSCMAKE_COMPONENT_<component>_DEPENDENCIES` |
| `csExported<component>DependsSorted` | `CSCMAKE_COMPONENT_<component>_DEPENDENCIES_SORTED` |

### Target properties

| Old | New |
|---|---|
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

### The namespace is given to `cs_initialize_project`

The namespace (prefix of the installed targets `<namespace>::<target>`, name of the package `find_package(<namespace>)`)
was the argument of `cs_finalize_project`; it is now the `NAMESPACE` argument of `cs_initialize_project`, which no
longer takes the project name (it was only used in a debug message). `cs_finalize_project` takes no argument.

```cmake
# before
cs_initialize_project(myAppSol CXX_STANDARD 17 ...)
cs_finalize_project(myApp)

# after
cs_initialize_project(NAMESPACE myApp CXX_STANDARD 17 ...)
cs_finalize_project()
```

An old call fails at configure time with a message pointing here. `cs_get_namespace(<out-var>)` returns the namespace (also in the read-only variable `CSCMAKE_NAMESPACE`, set in the
directory of `cs_initialize_project` and its subdirectories).

### Default targets

The targets created by `cs_initialize_project` now have the **same name in the build tree and once installed**,
`<namespace>::cscmake_*` (before: `<project>::<project>_csCMake*` in the build tree, `<namespace>::<project>_csCMake*`
installed):

| Old (build tree) | Old (installed) | New (both) |
|---|---|---|
| `<project>::<project>_csCMakeBaseInclude` | `<namespace>::<project>_csCMakeBaseInclude` | `<namespace>::cscmake_base_include` |
| `<project>::<project>_csCMakeCompileOptionsDefault` | `<namespace>::<project>_csCMakeCompileOptionsDefault` | `<namespace>::cscmake_compile_options` |
| `<project>::<project>_csCMakeCompileOptionsStrict` | `<namespace>::<project>_csCMakeCompileOptionsStrict` | `<namespace>::cscmake_compile_options_strict` |
| `<project>::<project>MSVCParallelCompile` | `<namespace>::<project>MSVCParallelCompile` | `<namespace>::cscmake_msvc_parallel_compile` |
| `<project>::<project>StrictCompilation` | `<namespace>::<project>StrictCompilation` | `<namespace>::cscmake_strict_warnings` |

`<project>` is the name of the top `project()`. Their component is renamed from `<project>_csCMakeCommon` to
`<namespace>_cscmake_common`.
