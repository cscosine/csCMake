Commands by tier
================

The public commands of csCMake, grouped by what a project uses them for. Every other command (``_cs_*``) is internal
and may change in any release.

Core: what every project writes
-------------------------------

The lifecycle and the targets; a project needs these and nothing else.

* :command:`cs_initialize_project`, :command:`cs_finalize_project`
* :command:`cs_add_library`, :command:`cs_add_executable`, :command:`cs_finalize_target`
* :command:`cs_target_sources`, :command:`cs_target_link_libraries`, :command:`cs_find_package`
* :command:`cs_install_target`

Features: when the project needs them
-------------------------------------

* compile profiles (warnings, sanitizers, hardening, clang-tidy): :command:`cs_add_compile_profile_rule`,
  :command:`cs_target_use_compile_profiles`; the shipped profiles: :doc:`csCompileProfilesShipped`
* each installed header compiles on its own: :command:`cs_target_check_installed_headers`
* OpenMP: :command:`cs_target_use_openmp`
* what CMake cannot know about the run-time environment of a target (plugins, libraries loaded at run time):
  :command:`cs_target_runtime_environment`

Queries: values for the project's own CMake code
------------------------------------------------

* the configurations of the build: :command:`cs_get_build_configurations`
* the folders of generated headers: :command:`cs_get_generated_dir`, :command:`cs_get_generated_config_dir`
* the install folder of the headers: :command:`cs_get_install_include_dir`
* the targets of the project: :command:`cs_get_project_targets`

Troubleshooting: when something does not behave as expected
-----------------------------------------------------------

* a target (its component, headers, packages, profiles, run-time environment, dependencies, CMake properties):
  :command:`cs_print_target`
* the project (configurations, search paths, targets, components and their dependencies): :command:`cs_print_project`
* the debug messages of csCMake (``-D<project>_CSCMAKE_DEBUG=ON``): :command:`cs_debug_message`
