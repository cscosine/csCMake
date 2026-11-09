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

To come.

## Properties

To come.

## Default targets and namespace

To come.
