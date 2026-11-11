#.rst:
# csProject
# ---------
#
# The project: :command:`cs_initialize_project` after :command:`project`; the namespace; the variables set in the scope
# of the project. The project is finalized at the end of the same ``CMakeLists.txt``.
#
# Commands
# ^^^^^^^^

include_guard(GLOBAL)
include(modules/csDebug)
include(modules/csInternal)

#.rst:
# .. command:: cs_initialize_project
#
#   Initialize the project: namespace, C++ standard, build configurations, compile profiles, default target.
#
#   .. code-block:: cmake
#
#     cs_initialize_project(NAMESPACE <namespace> CXX_STANDARD <standard>
#       [DEFAULT_CONFIG <config>...]
#       [DEFAULT_CONFIG_MAPPED <config> MAPPED_TO "<config>,<fallback>,"]...
#       [CUSTOM_CONFIG <config> BASED_ON "<config>,<fallback>," POSTFIX "<postfix>"]...
#       [DEFAULT_COMPILE_PROFILES <profile>...|NONE]
#       [INSTALL_RPATH ON|OFF]
#       [VERSION_COMPATIBILITY AnyNewerVersion|SameMajorVersion|SameMinorVersion|ExactVersion])
#
#   Mandatory, after project(<name> VERSION <x.y.z> ...), in the folder of the project. A macro: the variables it sets
#   belong to the project scope (inherited by the subfolders).
#
#   At the end of the same ``CMakeLists.txt`` (:command:`cmake_language(DEFER) <cmake_language>`), csCMake finalizes the
#   project: the compile profiles of its targets, the targets each one depends on, the Visual Studio debugger
#   environment, the install rules of its components and ``<namespace>Config.cmake``. Links added afterwards with
#   :command:`cs_target_link_libraries`, and :command:`cs_target_runtime_environment` calls, fail. At the end of the top
#   folder of the build, the run-time environment scripts of the build (:variable:`CSCMAKE_RUNTIME_SCRIPTS`).
#
#   ``NAMESPACE``
#     Prefix of the installed targets (<namespace>::<target>) and package name (``find_package(<namespace>)``).
#
#   ``CXX_STANDARD``
#     CMAKE_CXX_STANDARD of the project.
#
#   ``DEFAULT_CONFIG``
#     Configurations among Debug, Release, RelWithDebInfo.
#
#   ``DEFAULT_CONFIG_MAPPED``
#     One of them, with the configurations of imported targets to use (CMAKE_MAP_IMPORTED_CONFIG_<CONFIG>).
#
#   ``CUSTOM_CONFIG``
#     A copy of a default configuration (BASED_ON, then fallbacks) with its own output name postfix (POSTFIX "" for
#     none).
#
#   ``DEFAULT_COMPILE_PROFILES``
#     Compile profiles of every target (default cscmake_default, NONE for none).
#
#   ``INSTALL_RPATH``
#     ``OFF``: no install RPATH set by :command:`cs_add_library` / :command:`cs_add_executable`
#     (:variable:`CSCMAKE_INSTALL_RPATH`). Default ``ON``.
#
#   ``VERSION_COMPATIBILITY``
#     Which versions of the installed package a consumer's ``find_package(<namespace> <version>)`` accepts (the
#     ``COMPATIBILITY`` of :command:`write_basic_package_version_file`): ``SameMajorVersion`` (default: 1.4 for a
#     request of 1.2, not 2.0), ``AnyNewerVersion``, ``SameMinorVersion``, ``ExactVersion``
#     (:variable:`CSCMAKE_VERSION_COMPATIBILITY`).
#
#   :Reads: :variable:`CSCMAKE_PREFIX_PATH_HEAD`, :variable:`CSCMAKE_PREFIX_PATH_TAIL`,
#     :variable:`CSCMAKE_MODULE_PATH_HEAD`, :variable:`CSCMAKE_MODULE_PATH_TAIL`
#   :Writes: :variable:`CSCMAKE_NAMESPACE`, :variable:`CSCMAKE_SOURCE_DIR`,
#     :variable:`CSCMAKE_DEFAULT_COMPILE_PROFILES`, :variable:`CSCMAKE_INSTALL_RPATH`,
#     :variable:`CSCMAKE_VERSION_COMPATIBILITY`, :variable:`CMAKE_CXX_STANDARD`,
#     :variable:`CMAKE_CXX_STANDARD_REQUIRED`, :variable:`CMAKE_CXX_EXTENSIONS`, :variable:`CMAKE_PREFIX_PATH`,
#     :variable:`CMAKE_MODULE_PATH`, :variable:`CMAKE_RUNTIME_OUTPUT_DIRECTORY`,
#     :variable:`CMAKE_LIBRARY_OUTPUT_DIRECTORY`, :variable:`CMAKE_ARCHIVE_OUTPUT_DIRECTORY`,
#     :variable:`CMAKE_EXPORT_COMPILE_COMMANDS`,
#     :prop_gbl:`_CSCMAKE_PROJECT_FINALIZED_<namespace>`, :prop_tgt:`CSCMAKE_PROJECT_DEPENDENCIES`,
#     :prop_tgt:`VS_DEBUGGER_ENVIRONMENT`
macro(cs_initialize_project)
  # a macro: the variables it sets (CMAKE_CXX_STANDARD, CSCMAKE_NAMESPACE, ...) belong to the project scope. Its own
  # temporaries are _cs_init_* and are unset at the end.

  if(NOT PROJECT_VERSION)
    message(
      FATAL_ERROR
      "[cs_initialize_project] project(${PROJECT_NAME} VERSION <x.y.z> ...) is required: the version of the "
      "installed package (<namespace>ConfigVersion.cmake)"
    )
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

  _cs_set_cxx_standard(${_cs_init_cxx_standard})

  # check validity of requested config (if single generator, or set the build types to the requested configs)
  _cs_process_configurations()

  # join CMAKE_PREFIX_PATH CSCMAKE_<PREFIX|MODULE>_PATH_<HEAD|TAIL>: -D, or the environment variables of the same name
  # through the presets (unquoted: empty parts are dropped)
  set(CMAKE_PREFIX_PATH ${CSCMAKE_PREFIX_PATH_HEAD} ${CMAKE_PREFIX_PATH} ${CSCMAKE_PREFIX_PATH_TAIL})
  set(CMAKE_MODULE_PATH ${CSCMAKE_MODULE_PATH_HEAD} ${CMAKE_MODULE_PATH} ${CSCMAKE_MODULE_PATH_TAIL})

  # enable cmake testing
  enable_testing()

  _cs_set_generator_variables()

  _cs_report_initialized()

  _cs_add_default_targets()

  # finalize the project at the end of this CMakeLists.txt (the namespace is fixed now: deferred call arguments are
  # evaluated when the call runs)
  cmake_language(EVAL CODE "cmake_language(DEFER CALL _cs_finalize_project [[${CSCMAKE_NAMESPACE}]])")
  # the run-time environment scripts of the build, at the end of its top folder
  _cs_defer_runtime_scripts(${CSCMAKE_NAMESPACE})

  unset(_cs_init_multi_config)
  unset(_cs_init_config_subfolder)
  unset(_cs_init_cxx_standard)
endmacro()

# Report the initialized project: VERBOSE one line, DEBUG its configurations.
function(_cs_report_initialized)
  _cs_message_context(cs_initialize_project)
  cs_get_build_configurations(configs)
  list(JOIN configs ", " configs)
  message(
    VERBOSE
    "${CSCMAKE_NAMESPACE}: project ${PROJECT_NAME} ${PROJECT_VERSION}, C++ ${CMAKE_CXX_STANDARD}, configurations "
    "${configs}"
  )
  # the presets give CMAKE_C_COMPILER for the projects with C sources: read here, so that a C++-only project does not
  # get the "Manually-specified variables were not used by the project" warning
  message(DEBUG "C compiler (presets): ${CMAKE_C_COMPILER}")
  _cs_log_level_at_least(DEBUG debug)
  if(debug)
    _cs_print_project_configurations(DEBUG)
  endif()
endfunction()

# Set the C++ standard of the project (in the scope of the caller, cs_initialize_project: a macro): required and without
# extensions, unless the project chose otherwise.
#
# Writes:
#
# * variable CMAKE_CXX_STANDARD
# * variable CMAKE_CXX_STANDARD_REQUIRED (ON), CMAKE_CXX_EXTENSIONS (OFF): unless defined
macro(_cs_set_cxx_standard standard)
  set(CMAKE_CXX_STANDARD ${standard})
  if(NOT DEFINED CMAKE_CXX_STANDARD_REQUIRED)
    set(CMAKE_CXX_STANDARD_REQUIRED ON)
  endif()
  if(NOT DEFINED CMAKE_CXX_EXTENSIONS)
    set(CMAKE_CXX_EXTENSIONS OFF)
  endif()
endmacro()

# Set the variables that depend on the generator (in the scope of the caller, cs_initialize_project: a macro).
#
# Writes:
#
# * variable CMAKE_EXPORT_COMPILE_COMMANDS: ON with the Ninja generators, unless set by the user (e.g. -D...=OFF)
macro(_cs_set_generator_variables)
  # Ninja and Ninja Multi-Config; CMake creates the cache entry empty, a value (-D, or the environment variable of the
  # same name) is the choice of the user
  if("${CMAKE_EXPORT_COMPILE_COMMANDS}" STREQUAL "" AND CMAKE_GENERATOR MATCHES "^Ninja")
    message(DEBUG "${CSCMAKE_NAMESPACE}: CMAKE_EXPORT_COMPILE_COMMANDS ON (Ninja)")
    set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
  endif()
endmacro()

# Return the namespace of the project (NAMESPACE of :command:`cs_initialize_project`).
#
# Reads:
#
# * variable CSCMAKE_NAMESPACE
function(_cs_get_namespace output_variable_name)
  if(NOT CSCMAKE_NAMESPACE)
    message(FATAL_ERROR "[csCMake] no project: call cs_initialize_project(NAMESPACE ...) before the csCMake commands")
  endif()
  set(${output_variable_name} ${CSCMAKE_NAMESPACE} PARENT_SCOPE)
endfunction()

# Finalize the project of namespace (deferred by cs_initialize_project to the end of its CMakeLists.txt, in the scope of
# that folder): finalize its targets, resolve their dependencies (the targets each one depends on, the Visual Studio
# debugger environment), install its components and generate <namespace>Config.cmake.
#
# Writes:
#
# * global property _CSCMAKE_PROJECT_FINALIZED_<namespace>
function(_cs_finalize_project namespace)
  _cs_message_context(finalize)
  set_property(GLOBAL PROPERTY _CSCMAKE_PROJECT_FINALIZED_${namespace} TRUE)
  message(VERBOSE "${namespace}: finalizing the project (end of ${CMAKE_CURRENT_SOURCE_DIR}/CMakeLists.txt)")
  list(APPEND CMAKE_MESSAGE_INDENT "  ")

  cs_get_project_targets(targets)
  foreach(target_name IN LISTS targets)
    _cs_finalize_target(${target_name})
  endforeach()
  _cs_finalize_runtime_dependencies()
  _cs_finalize_install(${namespace})

  # the project as finalized (targets, components and their dependencies)
  list(POP_BACK CMAKE_MESSAGE_INDENT)
  _cs_log_level_at_least(DEBUG debug)
  if(debug)
    _cs_print_project(DEBUG "finalized")
  endif()
endfunction()

# Record the normal variable var_name = value, set in the project scope by _cs_apply_project_scope_variables (lets
# functions called at any depth by cs_initialize_project set project variables).
#
# Writes:
#
# * global property _CSCMAKE_PROJECT_SCOPE_VARIABLES, _CSCMAKE_PROJECT_SCOPE_VARIABLE_<name>
function(_cs_set_in_project_scope var_name value)
  set_property(GLOBAL APPEND PROPERTY _CSCMAKE_PROJECT_SCOPE_VARIABLES ${var_name})
  set_property(GLOBAL PROPERTY _CSCMAKE_PROJECT_SCOPE_VARIABLE_${var_name} "${value}")
endfunction()

# Set in the caller's scope (cs_initialize_project: the project scope) the variables recorded by
# _cs_set_in_project_scope, then forget them.
#
# Reads:
#
# * global property _CSCMAKE_PROJECT_SCOPE_VARIABLES, _CSCMAKE_PROJECT_SCOPE_VARIABLE_<name>
function(_cs_apply_project_scope_variables)
  get_property(var_names GLOBAL PROPERTY _CSCMAKE_PROJECT_SCOPE_VARIABLES)
  foreach(var_name ${var_names})
    get_property(value GLOBAL PROPERTY _CSCMAKE_PROJECT_SCOPE_VARIABLE_${var_name})
    set(${var_name} "${value}" PARENT_SCOPE)
    set_property(GLOBAL PROPERTY _CSCMAKE_PROJECT_SCOPE_VARIABLE_${var_name})
  endforeach()
  set_property(GLOBAL PROPERTY _CSCMAKE_PROJECT_SCOPE_VARIABLES)
endfunction()

#.rst:
# Variables
# ^^^^^^^^^
#
# .. variable:: CSCMAKE_NAMESPACE
#
#   The namespace of the project (``NAMESPACE`` of :command:`cs_initialize_project`): the prefix of the installed
#   targets (``<namespace>::<target>``) and the package name (``find_package(<namespace>)``). Set in the folder of
#   :command:`cs_initialize_project`, inherited by its subfolders; read-only.
#
# .. variable:: CSCMAKE_SOURCE_DIR
#
#   The folder of :command:`cs_initialize_project`: the installed headers keep their path relative to it.
#
# .. variable:: CSCMAKE_DEFAULT_COMPILE_PROFILES
#
#   The compile profiles of every target of the folder (``DEFAULT_COMPILE_PROFILES`` of
#   :command:`cs_initialize_project`): the first values of :prop_tgt:`CSCMAKE_COMPILE_PROFILES` of each target, taken
#   when :command:`cs_add_library` / :command:`cs_add_executable` creates it. A directory variable: a subfolder can set
#   its own, before its targets.
#
# .. variable:: CSCMAKE_INSTALL_RPATH
#
#   ``OFF``: :command:`cs_add_library` / :command:`cs_add_executable` set no install RPATH on the targets of the folder.
#   Unset or ``ON``: the executables and shared libraries find, once installed, the shared libraries of their package
#   (Linux, macOS). ``INSTALL_RPATH`` of :command:`cs_initialize_project`, or a directory variable: a subfolder can set
#   its own, before its targets.
#
# .. variable:: CSCMAKE_VERSION_COMPATIBILITY
#
#   The compatibility of the installed package version (``VERSION_COMPATIBILITY`` of :command:`cs_initialize_project`,
#   ``SameMajorVersion`` by default), read when the project is finalized, for ``<namespace>ConfigVersion.cmake``.
#
# .. variable:: CSCMAKE_PREFIX_PATH_HEAD
#
#   Paths added before :variable:`CMAKE_PREFIX_PATH` by :command:`cs_initialize_project` (``-D``, or the environment
#   variable of the same name through the presets).
#
# .. variable:: CSCMAKE_PREFIX_PATH_TAIL
#
#   Paths added after :variable:`CMAKE_PREFIX_PATH`.
#
# .. variable:: CSCMAKE_MODULE_PATH_HEAD
#
#   Paths added before :variable:`CMAKE_MODULE_PATH`.
#
# .. variable:: CSCMAKE_MODULE_PATH_TAIL
#
#   Paths added after :variable:`CMAKE_MODULE_PATH`.
#
# Global properties
# ^^^^^^^^^^^^^^^^^
#
# .. prop_gbl:: _CSCMAKE_PROJECT_FINALIZED_<namespace>
#
#   Internal: ``TRUE`` once the project of the namespace is finalized (end of the ``CMakeLists.txt`` of
#   :command:`cs_initialize_project`).
#
# .. prop_gbl:: _CSCMAKE_PROJECT_SCOPE_VARIABLES
#
#   Internal: the variables to set in the project scope at the end of :command:`cs_initialize_project`.
#
# .. prop_gbl:: _CSCMAKE_PROJECT_SCOPE_VARIABLE_<name>
#
#   Internal: the value of such a variable.
