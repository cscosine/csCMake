# csCMake: include(csCMake) from a project, then cs_initialize_project ... cs_finalize_project.
include_guard(GLOBAL)

# csCMake needs CMake 3.31 (the csv1 presets use schema version 10); the including project declares its own
# cmake_minimum_required. csCMake's functions and macros run with the 3.31 policies: they record the policy settings in
# effect where they are defined (cmake_policy PUSH / VERSION / POP around the whole file).
if(CMAKE_VERSION VERSION_LESS 3.31)
  message(FATAL_ERROR "csCMake requires CMake 3.31 or newer (found ${CMAKE_VERSION})")
endif()
cmake_policy(PUSH)
cmake_policy(VERSION 3.31)

include(utils/csPrintInitialState)
include(utils/csPathUtils)

include(utils/csAddLibraryExecutable)
include(utils/csFindPackage)
include(utils/csTargetSources)
include(utils/csTargetLinkLibraries)
include(utils/csTargetDependencies)
include(utils/csMSVCUtils)
include(utils/csInstall)
include(utils/csDefaultTargets)
include(utils/csBuildConfigurations)
include(utils/csCompileEachInstalledInclude)
include(utils/csCompileProfiles)
include(utils/csOpenMP)

# Store the csCMake folder; fail if csCMake is included from two different folders.
#
# Writes:
#
# * global property CSCMAKE_ROOT_DIR: the csCMake folder
function(_cs_set_root_dir path)
  get_property(val GLOBAL PROPERTY CSCMAKE_ROOT_DIR)
  if(val)
    if(NOT val STREQUAL ${path})
      message(
        FATAL_ERROR "[_cs_set_root_dir] csCMake has been included multiple times with different base paths. Check your "
                    "configuration.")
    endif()
  endif()
  set_property(GLOBAL PROPERTY CSCMAKE_ROOT_DIR ${path})
endfunction()
_cs_set_root_dir(${CMAKE_CURRENT_LIST_DIR})

# Return in path the csCMake folder.
#
# Reads:
#
# * global property CSCMAKE_ROOT_DIR
function(_cs_get_root_dir path)
  get_property(val GLOBAL PROPERTY CSCMAKE_ROOT_DIR)
  set(${path}
      ${val}
      PARENT_SCOPE)
endfunction()

# Initialize the project: namespace, C++ standard, build configurations, compile profiles, default target.
#
# cs_initialize_project(NAMESPACE <namespace> CXX_STANDARD <standard> [DEFAULT_CONFIG <config>...]
# [DEFAULT_CONFIG_MAPPED <config> MAPPED_TO "<config>,<fallback>,"]... [CUSTOM_CONFIG <config> BASED_ON
# "<config>,<fallback>," POSTFIX "<postfix>"]... [DEFAULT_COMPILE_PROFILES <profile>...|NONE])
#
# Mandatory, after project(<name> VERSION <x.y.z> ...), in the folder of the project; cs_finalize_project() is then
# required at the end of the same CMakeLists.txt (checked). A macro: the variables it sets belong to the project scope
# (inherited by the subfolders).
#
# Arguments:
#
# * NAMESPACE: prefix of the installed targets (<namespace>::<target>) and package name (find_package(<namespace>))
# * CXX_STANDARD: CMAKE_CXX_STANDARD of the project
# * DEFAULT_CONFIG: configurations among Debug, Release, RelWithDebInfo
# * DEFAULT_CONFIG_MAPPED: one of them, with the configurations of imported targets to use
#   (CMAKE_MAP_IMPORTED_CONFIG_<CONFIG>)
# * CUSTOM_CONFIG: a copy of a default configuration (BASED_ON, then fallbacks) with its own output name postfix
#   (POSTFIX "" for none)
# * DEFAULT_COMPILE_PROFILES: compile profiles of every target (default cscmake_default, NONE for none)
#
# Reads:
#
# * cache variable CSCMAKE_PREFIX_PATH_HEAD, CSCMAKE_PREFIX_PATH_TAIL: paths added before / after CMAKE_PREFIX_PATH
# * cache variable CSCMAKE_MODULE_PATH_HEAD, CSCMAKE_MODULE_PATH_TAIL: paths added before / after CMAKE_MODULE_PATH
#
# Writes:
#
# * cache variable <project>_CSCMAKE_DEBUG: option, csCMake debug messages of the project
# * variable CSCMAKE_NAMESPACE: the namespace (read-only)
# * variable CSCMAKE_SOURCE_DIR: the folder of cs_initialize_project, base of the install paths of the headers
# * variable CSCMAKE_DEFAULT_COMPILE_PROFILES: the default compile profiles
# * variable CMAKE_CXX_STANDARD, CMAKE_CXX_STANDARD_REQUIRED, CMAKE_CXX_EXTENSIONS
# * variable CMAKE_PREFIX_PATH, CMAKE_MODULE_PATH: with the HEAD and TAIL paths
# * variable CMAKE_RUNTIME_OUTPUT_DIRECTORY, CMAKE_LIBRARY_OUTPUT_DIRECTORY, CMAKE_ARCHIVE_OUTPUT_DIRECTORY:
#   <build>/bin, <build>/lib (/<config> with multi-config generators), unless set
# * variable CMAKE_EXPORT_COMPILE_COMMANDS: ON with the Ninja generators
# * variable CMAKE_XCODE_ATTRIBUTE_CLANG_CXX_STANDARD_LIBRARY_HARDENING: none with Xcode, unless set
# * variable _cscmake_debug_option: name of the debug option of the project
macro(cs_initialize_project)
  # a macro: the variables it sets (CMAKE_CXX_STANDARD, CSCMAKE_NAMESPACE, ...) belong to the project scope. Its own
  # temporaries are _cs_init_* and are unset at the end.

  # debug messages of csCMake for this project: -D<project>_CSCMAKE_DEBUG=ON
  option(${PROJECT_NAME}_CSCMAKE_DEBUG "csCMake: print the csCMake debug messages of ${PROJECT_NAME}" OFF)
  set(_cscmake_debug_option ${PROJECT_NAME}_CSCMAKE_DEBUG)
  cs_debug_message("cs_initialize_project ${ARGN}")

  if(NOT PROJECT_VERSION)
    message(
      FATAL_ERROR
        "[cs_initialize_project] project(${PROJECT_NAME} VERSION <x.y.z> ...) is required: the version of the "
        "installed package (<namespace>ConfigVersion.cmake)")
  endif()

  # the folder of the project: base of the relative install paths of the headers
  set(CSCMAKE_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")

  # normalize paths
  _cs_path_list_normalize(CSCMAKE_PREFIX_PATH_HEAD)
  _cs_path_list_normalize(CMAKE_PREFIX_PATH)
  _cs_path_list_normalize(CSCMAKE_PREFIX_PATH_TAIL)

  _cs_path_list_normalize(CSCMAKE_MODULE_PATH_HEAD)
  _cs_path_list_normalize(CMAKE_MODULE_PATH)
  _cs_path_list_normalize(CSCMAKE_MODULE_PATH_TAIL)

  _cs_path_list_normalize(CMAKE_INSTALL_PREFIX)

  # a single output folder for binaries (dll and exe in win, .so and executables in linux), kept if set by the user; the
  # custom configurations get their own per-configuration folders in _cs_parse_additional_configurations
  get_property(_cs_init_multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
  if(_cs_init_multi_config)
    set(_cs_init_config_subfolder "/$<CONFIG>")
  else()
    set(_cs_init_config_subfolder "")
  endif()
  if(NOT CMAKE_RUNTIME_OUTPUT_DIRECTORY)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin${_cs_init_config_subfolder}")
  endif()
  if(NOT CMAKE_LIBRARY_OUTPUT_DIRECTORY)
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib${_cs_init_config_subfolder}")
  endif()
  if(NOT CMAKE_ARCHIVE_OUTPUT_DIRECTORY)
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib${_cs_init_config_subfolder}")
  endif()

  # initialize the default configuration list variables
  _cs_process_build_configurations_variables()

  # parse the arguments: namespace (CSCMAKE_NAMESPACE), C++ standard, configurations
  _cs_parse_additional_configurations(_cs_init_cxx_standard ${ARGN})

  # the variables derived from the configurations (postfixes, imported config mapping, output folders, MSVC runtime)
  _cs_apply_project_scope_variables()

  # set cmake standard
  set(CMAKE_CXX_STANDARD ${_cs_init_cxx_standard})
  set(CMAKE_CXX_STANDARD_REQUIRED ON)
  set(CMAKE_CXX_EXTENSIONS OFF)

  # check validity of requested config (if single generator, or set the build types to the requested configs)
  _cs_process_configurations()

  # print information on the csCMake configuration
  cs_print_state("initial state")

  # join CMAKE_PREFIX_PATH CSCMAKE_<PREFIX|MODULE>_PATH_<HEAD|TAIL>: -D, or the environment variables of the same name
  # through the presets (unquoted: empty parts are dropped)
  set(CMAKE_PREFIX_PATH ${CSCMAKE_PREFIX_PATH_HEAD} ${CMAKE_PREFIX_PATH} ${CSCMAKE_PREFIX_PATH_TAIL})
  set(CMAKE_MODULE_PATH ${CSCMAKE_MODULE_PATH_HEAD} ${CMAKE_MODULE_PATH} ${CSCMAKE_MODULE_PATH_TAIL})

  # enable cmake testing
  enable_testing()

  _cs_set_generator_variables()

  _cs_add_default_targets()

  # check at the end of this CMakeLists.txt that cs_finalize_project was called (the values are fixed now: deferred call
  # arguments are evaluated when the call runs)
  cmake_language(EVAL CODE "cmake_language(DEFER CALL _cs_check_project_finalized [[${CSCMAKE_NAMESPACE}]] "
                 "[[${CMAKE_CURRENT_SOURCE_DIR}]])")

  unset(_cs_init_multi_config)
  unset(_cs_init_config_subfolder)
  unset(_cs_init_cxx_standard)
endmacro()

# Set the variables that depend on the generator (in the scope of the caller, cs_initialize_project: a macro).
#
# Writes:
#
# * variable CMAKE_EXPORT_COMPILE_COMMANDS: ON with the Ninja generators
# * variable CMAKE_XCODE_ATTRIBUTE_CLANG_CXX_STANDARD_LIBRARY_HARDENING: none with Xcode, unless set; the standard
#   library checks of libc++ come from the compile profiles (cscmake_hardening_fast, cscmake_hardening_debug), as with
#   the other generators, and Xcode would define _LIBCPP_HARDENING_MODE too (macro redefined)
macro(_cs_set_generator_variables)
  if(CMAKE_GENERATOR STREQUAL "Ninja" OR CMAKE_GENERATOR STREQUAL "Ninja Multi-Config")
    cs_debug_message("[csCMake] set CMAKE_EXPORT_COMPILE_COMMANDS ON")
    set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
  endif()
  if(CMAKE_GENERATOR STREQUAL "Xcode" AND NOT DEFINED CMAKE_XCODE_ATTRIBUTE_CLANG_CXX_STANDARD_LIBRARY_HARDENING)
    set(CMAKE_XCODE_ATTRIBUTE_CLANG_CXX_STANDARD_LIBRARY_HARDENING "none")
  endif()
endmacro()

# Return the namespace of the project (NAMESPACE of cs_initialize_project).
#
# cs_get_namespace(<out-var>)
#
# Reads:
#
# * variable CSCMAKE_NAMESPACE
function(cs_get_namespace output_variable_name)
  if(NOT CSCMAKE_NAMESPACE)
    message(FATAL_ERROR "[cs_get_namespace] no namespace: call cs_initialize_project(NAMESPACE ...) first")
  endif()
  set(${output_variable_name}
      ${CSCMAKE_NAMESPACE}
      PARENT_SCOPE)
endfunction()

# Finalize the project: check its targets, resolve their runtime dependencies, install its components and generate
# <namespace>Config.cmake.
#
# cs_finalize_project()
#
# Mandatory, at the end of the CMakeLists.txt of cs_initialize_project (checked). Fails for the targets not finalized
# with cs_finalize_target and for the ones whose links changed after it.
#
# Writes:
#
# * global property _CSCMAKE_PROJECT_FINALIZED_<namespace>: TRUE
function(cs_finalize_project)
  if(ARGN)
    message(FATAL_ERROR "[cs_finalize_project] takes no arguments (got ${ARGN}): the namespace is given to "
                        "cs_initialize_project(NAMESPACE ...), see MIGRATION.md")
  endif()
  cs_get_namespace(export_namespace)
  set_property(GLOBAL PROPERTY _CSCMAKE_PROJECT_FINALIZED_${export_namespace} TRUE)

  # debug: targets, components, state
  cs_print_project_targets()
  cs_print_components()
  cs_print_state("final state")

  _cs_check_targets_finalized()
  _cs_finalize_runtime_dependencies()
  _cs_finalize_install(${export_namespace})
endfunction()

# Resolve the runtime dependencies of every target of the project (CSCMAKE_RUNTIME_LIBRARIES_<CONFIG>) and, from them,
# the Visual Studio debugger environment.
function(_cs_finalize_runtime_dependencies)
  cs_get_project_targets(targets)
  _cs_recursive_analyze_targets_finalize("${targets}")
  _cs_set_vs_debugger_env_variable("${targets}")
endfunction()

# Fail if cs_finalize_project was not called for namespace (deferred to the end of the CMakeLists.txt of
# cs_initialize_project).
#
# Reads:
#
# * global property _CSCMAKE_PROJECT_FINALIZED_<namespace>
function(_cs_check_project_finalized namespace source_dir)
  get_property(finalized GLOBAL PROPERTY _CSCMAKE_PROJECT_FINALIZED_${namespace})
  if(NOT finalized)
    message(FATAL_ERROR "[cs_initialize_project] cs_finalize_project() is required at the end of "
                        "${source_dir}/CMakeLists.txt (namespace ${namespace})")
  endif()
endfunction()

cmake_policy(POP)
