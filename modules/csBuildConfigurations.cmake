#.rst:
# csBuildConfigurations
# ---------------------
#
# The build configurations of the build tree (``DEFAULT_CONFIG``, ``DEFAULT_CONFIG_MAPPED``, ``CUSTOM_CONFIG`` of
# :command:`cs_initialize_project`): the first csCMake project defines them, a nested project uses some of them, defined
# the same way.
#
# Commands
# ^^^^^^^^
include_guard(GLOBAL)

# Defaults chosen by csCMake are cache variables: override them with -D<variable>=<value>. Values derived from the
# cs_initialize_project arguments are normal variables of the project scope (_cs_set_in_project_scope).

# output name postfix of the targets, per default configuration
set(CSCMAKE_DEBUG_POSTFIX "d" CACHE STRING "csCMake: output name postfix in the Debug configuration")
set(CSCMAKE_RELEASE_POSTFIX "" CACHE STRING "csCMake: output name postfix in the Release configuration")
set(CSCMAKE_RELWITHDEBINFO_POSTFIX "rd" CACHE STRING "csCMake: output name postfix in the RelWithDebInfo configuration")

# note, MSVC supports also MinSizeRel, but it is not supported here

# MSVC runtime library, per default configuration
set(
  CSCMAKE_MSVC_RUNTIME_LIBRARY_DEBUG
  "MultiThreadedDebugDLL"
  CACHE STRING
  "csCMake: MSVC runtime library in the Debug configuration"
)
set(
  CSCMAKE_MSVC_RUNTIME_LIBRARY_RELWITHDEBINFO
  "MultiThreadedDLL"
  CACHE STRING
  "csCMake: MSVC runtime library in the RelWithDebInfo configuration"
)
set(
  CSCMAKE_MSVC_RUNTIME_LIBRARY_RELEASE
  "MultiThreadedDLL"
  CACHE STRING
  "csCMake: MSVC runtime library in the Release configuration"
)

#.rst:
# .. command:: cs_get_build_configurations
#
#   Return the build configurations of the build (default, mapped and custom ones).
#
#   .. code-block:: cmake
#
#     cs_get_build_configurations(<out-var>)
#
#   ``<out-var>``
#     The variable to set, in the scope of the caller.
#
#   :Reads: :prop_gbl:`CSCMAKE_BUILD_CONFIGURATIONS`
function(cs_get_build_configurations configs_list)
  get_property(val GLOBAL PROPERTY CSCMAKE_BUILD_CONFIGURATIONS)
  set(${configs_list} ${val} PARENT_SCOPE)
endfunction()

# Return the default configurations of the build (DEFAULT_CONFIG and DEFAULT_CONFIG_MAPPED).
#
# Reads:
#
# * global property CSCMAKE_DEFAULT_BUILD_CONFIGURATIONS
function(_cs_get_default_build_configurations configs_list)
  get_property(val GLOBAL PROPERTY CSCMAKE_DEFAULT_BUILD_CONFIGURATIONS)
  set(${configs_list} ${val} PARENT_SCOPE)
endfunction()

# Return in configs_list the CMake variables with a <CONFIG> part (CMAKE_CXX_FLAGS_<CONFIG>, ...).
#
# Reads:
#
# * global property CSCMAKE_PER_CONFIG_VARIABLES
function(_cs_get_per_config_variables configs_list)
  get_property(val GLOBAL PROPERTY CSCMAKE_PER_CONFIG_VARIABLES)
  set(${configs_list} ${val} PARENT_SCOPE)
endfunction()

# Add the default configuration config (Debug, Release or RelWithDebInfo) to the build.
#
# Writes:
#
# * global property CSCMAKE_BUILD_CONFIGURATIONS, CSCMAKE_DEFAULT_BUILD_CONFIGURATIONS
function(_cs_add_default_build_configuration config)
  cs_get_build_configurations(configs_list)
  _cs_get_default_build_configurations(configs_list_default)

  set(valid_default_configs "Debug;Release;RelWithDebInfo")

  if(NOT "${config}" IN_LIST valid_default_configs)
    message(
      FATAL_ERROR
      "[cs_initialize_project] DEFAULT_CONFIG called with invalid default config ${config}, choose one of "
      "${valid_default_configs}"
    )
  endif()

  if(NOT "${config}" IN_LIST configs_list)
    list(APPEND configs_list ${config})
  else()
    message(FATAL_ERROR "[cs_initialize_project] DEFAULT_CONFIG called with duplicated element ${config}")
  endif()

  if(NOT "${config}" IN_LIST configs_list_default)
    list(APPEND configs_list_default ${config})
  else()
    message(
      FATAL_ERROR
      "[cs_initialize_project] DEFAULT_CONFIG called with duplicated element ${config} in default list"
    )
  endif()

  set_property(GLOBAL PROPERTY CSCMAKE_BUILD_CONFIGURATIONS ${configs_list})
  set_property(GLOBAL PROPERTY CSCMAKE_DEFAULT_BUILD_CONFIGURATIONS ${configs_list_default})
endfunction()

# Add the default configuration config with the configurations of imported targets to use (base_config_and_fallback).
#
# Writes:
#
# * variable CMAKE_MAP_IMPORTED_CONFIG_<CONFIG>: project scope
function(_cs_add_default_build_configuration_mapped config base_config_and_fallback)
  _cs_add_default_build_configuration(${config})

  string(TOUPPER "${config}" config_ucase)

  _cs_set_in_project_scope(CMAKE_MAP_IMPORTED_CONFIG_${config_ucase} "${base_config_and_fallback}")
  cs_debug_message("[_cs_add_default_build_configuration_mapped] set CMAKE_MAP_IMPORTED_CONFIG_${config_ucase} = "
                   "${base_config_and_fallback}"
  )
endfunction()

# Add the custom configuration config, a copy of base_config with its own postfix.
#
# Writes:
#
# * global property CSCMAKE_BUILD_CONFIGURATIONS
# * variable CSCMAKE_<CONFIG>_POSTFIX: project scope
function(_cs_add_custom_build_configuration config base_config postfix base_config_and_fallback)
  cs_get_build_configurations(configs_list)
  _cs_get_default_build_configurations(configs_list_default)

  if(NOT "${config}" IN_LIST configs_list)
    list(APPEND configs_list ${config})
  else()
    message(FATAL_ERROR "[_cs_add_custom_build_configuration] called with duplicated element ${config}")
  endif()

  if(NOT "${base_config}" IN_LIST configs_list_default)
    message(
      FATAL_ERROR
      "[_cs_add_custom_build_configuration] element ${config} base on ${base_config}, which is not in default "
      "configs ${configs_list_default}"
    )
  else()
    _cs_copy_build_configuration(${base_config} ${config} "${base_config_and_fallback}")
  endif()

  string(TOUPPER "${config}" config_upper)

  # the postfix is given by the project code (POSTFIX of cs_initialize_project)
  _cs_set_in_project_scope(CSCMAKE_${config_upper}_POSTFIX "${postfix}")

  set_property(GLOBAL PROPERTY CSCMAKE_BUILD_CONFIGURATIONS ${configs_list})
endfunction()

# Split the base configuration and its fallbacks of DEFAULT_CONFIG_MAPPED / CUSTOM_CONFIG ("Release,Debug" or "Release")
# into the base configuration (base_config_var) and the list of all of them (fallbacks_var).
function(_cs_split_base_config base_config_and_fallback base_config_var fallbacks_var)
  string(REPLACE "," ";" fallbacks "${base_config_and_fallback}")
  list(GET fallbacks 0 base_config)
  set(${base_config_var} "${base_config}" PARENT_SCOPE)
  set(${fallbacks_var} "${fallbacks}" PARENT_SCOPE)
endfunction()

# Add the DEFAULT_CONFIG_MAPPED configurations of cs_initialize_project, given as triples <config> MAPPED_TO
# <base,fallbacks>; in a nested project (nested TRUE), check them against the build instead.
#
# Writes:
#
# * global property CSCMAKE_BUILD_CONFIGURATION_<config>_DEFINITION: "mapped <fallbacks>"
function(_cs_add_mapped_configurations namespace nested)
  set(mapped_list ${ARGN})
  list(LENGTH mapped_list mapped_size)
  math(EXPR mod_size "${mapped_size} % 3")
  if(NOT "${mod_size}" EQUAL 0)
    message(
      FATAL_ERROR
      "[_cs_parse_additional_configurations] DEFAULT_CONFIG_MAPPED need to specify values as : "
      "DEFAULT_CONFIG_MAPPED RelWithDebInfo MAPPED_TO \"Release,\". Got ${mapped_list}"
    )
  endif()

  while(NOT "${mapped_list}" STREQUAL "")
    list(POP_FRONT mapped_list config mapped_to_keyword base_config_and_fallback)
    if(NOT "${mapped_to_keyword}" STREQUAL "MAPPED_TO")
      message(
        FATAL_ERROR
        "[_cs_parse_additional_configurations] DEFAULT_CONFIG_MAPPED need to specify values as : "
        "DEFAULT_CONFIG_MAPPED RelWithDebInfo MAPPED_TO \"Release,\". Got ${ARGN}"
      )
    endif()
    _cs_split_base_config("${base_config_and_fallback}" base_config fallbacks)

    set(definition "mapped ${fallbacks}")
    if(nested)
      _cs_check_build_configuration(${namespace} ${config} "${definition}")
      continue()
    endif()
    cs_debug_message("[_cs_parse_additional_configurations] adding mapped config ${config} ${fallbacks}")
    _cs_add_default_build_configuration_mapped(${config} "${fallbacks}")
    set_property(GLOBAL PROPERTY CSCMAKE_BUILD_CONFIGURATION_${config}_DEFINITION "${definition}")
  endwhile()
endfunction()

# Set the output folders of a custom configuration in the project scope, unless the user set them: the ones without
# configuration suffix do not apply to it (CMake uses the per-configuration ones copied from the base configuration).
#
# Writes:
#
# * variable CMAKE_<RUNTIME|LIBRARY|ARCHIVE>_OUTPUT_DIRECTORY_<CONFIG>: project scope
function(_cs_set_custom_config_output_directories config)
  get_property(generator_is_multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
  string(TOUPPER "${config}" config_ucase)
  if(generator_is_multi_config)
    set(config_subfolder "/${config}")
  else()
    set(config_subfolder "")
  endif()
  foreach(kind_folder RUNTIME/bin LIBRARY/lib ARCHIVE/lib)
    string(REPLACE "/" ";" kind_folder "${kind_folder}")
    list(GET kind_folder 0 kind)
    list(GET kind_folder 1 folder)
    if(NOT CMAKE_${kind}_OUTPUT_DIRECTORY_${config_ucase})
      _cs_set_in_project_scope(CMAKE_${kind}_OUTPUT_DIRECTORY_${config_ucase}
                               "${CMAKE_BINARY_DIR}/${folder}${config_subfolder}"
      )
    endif()
  endforeach()
endfunction()

# Add the CUSTOM_CONFIG configurations of cs_initialize_project, given as <config> BASED_ON <base,fallbacks> POSTFIX
# <postfix>; in a nested project (nested TRUE), check them against the build instead.
#
# Writes:
#
# * global property CSCMAKE_BUILD_CONFIGURATION_<config>_DEFINITION: "custom <base and fallbacks> postfix <postfix>"
# * the output folders of each configuration (_cs_set_custom_config_output_directories)
function(_cs_add_custom_configurations namespace nested)
  set(custom_list ${ARGN})
  list(LENGTH custom_list custom_size)
  math(EXPR mod_size "${custom_size} % 5")
  if(NOT "${mod_size}" EQUAL 0)
    message(
      FATAL_ERROR
      "[_cs_parse_additional_configurations] CUSTOM_CONFIG need to specify values as : CUSTOM_CONFIG "
      "MyCustomConfig1 BASED_ON Debug POSTFIX \"d\". Got ${custom_list}"
    )
  endif()

  while(NOT "${custom_list}" STREQUAL "")
    list(
      POP_FRONT custom_list
      config
      based_on_keyword
      base_config_and_fallback
      postfix_keyword
      postfix_value
    )
    if(NOT "${based_on_keyword}" STREQUAL "BASED_ON")
      message(
        FATAL_ERROR
        "[_cs_parse_additional_configurations] CUSTOM_CONFIG need to specify values as : CUSTOM_CONFIG "
        "MyCustomConfig1 BASED_ON Debug POSTFIX \"d\". Expected BASED_ON found ${based_on_keyword}"
      )
    endif()
    if(NOT "${postfix_keyword}" STREQUAL "POSTFIX")
      message(
        FATAL_ERROR
        "[_cs_parse_additional_configurations] CUSTOM_CONFIG need to specify values as : CUSTOM_CONFIG "
        "MyCustomConfig1 BASED_ON Debug POSTFIX \"d\". Expected POSTFIX found ${postfix_keyword}"
      )
    endif()
    _cs_split_base_config("${base_config_and_fallback}" base_config fallbacks)

    set(definition "custom ${fallbacks} postfix ${postfix_value}")
    if(nested)
      _cs_check_build_configuration(${namespace} ${config} "${definition}")
      continue()
    endif()
    cs_debug_message("[_cs_parse_additional_configurations] adding custom config ${config} ${base_config} ${fallbacks}")
    _cs_add_custom_build_configuration(${config} ${base_config} ${postfix_value} "${fallbacks}")
    set_property(GLOBAL PROPERTY CSCMAKE_BUILD_CONFIGURATION_${config}_DEFINITION "${definition}")
    _cs_set_custom_config_output_directories(${config})
  endwhile()
endfunction()

# Set the MSVC runtime library of every configuration in the project scope, from CSCMAKE_MSVC_RUNTIME_LIBRARY_<CONFIG>.
#
# Writes:
#
# * variable CSCMAKE_MSVC_RUNTIME_LIBRARY_GENERATOR_EXPRESSION: project scope, used by cs_add_library /
#   cs_add_executable
# * variable CMAKE_MSVC_RUNTIME_LIBRARY: project scope, for the targets not created by them
function(_cs_set_msvc_runtime_library_variables)
  set(runtime_expression "")
  cs_get_build_configurations(configs_list)
  foreach(config ${configs_list})
    string(TOUPPER "${config}" config_ucase)
    string(APPEND runtime_expression "$<$<CONFIG:${config}>:${CSCMAKE_MSVC_RUNTIME_LIBRARY_${config_ucase}}>")
  endforeach()
  _cs_set_in_project_scope(CSCMAKE_MSVC_RUNTIME_LIBRARY_GENERATOR_EXPRESSION "${runtime_expression}")
  _cs_set_in_project_scope(CMAKE_MSVC_RUNTIME_LIBRARY "${runtime_expression}")
endfunction()

# Set out to the VERSION_COMPATIBILITY given to cs_initialize_project (value), SameMajorVersion when empty; fail on a
# value write_basic_package_version_file does not take.
function(_cs_version_compatibility value out)
  if("${value}" STREQUAL "")
    set(value SameMajorVersion)
  endif()
  if(NOT value MATCHES "^(AnyNewerVersion|SameMajorVersion|SameMinorVersion|ExactVersion)$")
    message(
      FATAL_ERROR
      "[cs_initialize_project] VERSION_COMPATIBILITY is AnyNewerVersion, SameMajorVersion, SameMinorVersion or "
      "ExactVersion, got ${value}"
    )
  endif()
  set(${out} ${value} PARENT_SCOPE)
endfunction()

# Parse the arguments of cs_initialize_project: namespace, C++ standard (returned in required_cxx_standard), default
# compile profiles, build configurations. A nested csCMake project checks its configurations against the build instead
# of adding them.
#
# Writes:
#
# * variable CSCMAKE_NAMESPACE, CSCMAKE_DEFAULT_COMPILE_PROFILES, CSCMAKE_VERSION_COMPATIBILITY, CSCMAKE_INSTALL_RPATH
#   (if given): caller scope
# * global property CSCMAKE_BUILD_CONFIGURATION_<config>_DEFINITION: "default", "mapped <fallbacks>" or "custom <base
#   and fallbacks> postfix <postfix>"
# * variable CMAKE_<RUNTIME|LIBRARY|ARCHIVE>_OUTPUT_DIRECTORY_<CONFIG>: project scope, custom configurations, unless set
# * variable CSCMAKE_MSVC_RUNTIME_LIBRARY_GENERATOR_EXPRESSION, CMAKE_MSVC_RUNTIME_LIBRARY: project scope
function(_cs_parse_additional_configurations required_cxx_standard)
  cs_debug_message("[_cs_parse_additional_configurations] ${ARGN}")

  set(options "")
  set(onevalue NAMESPACE CXX_STANDARD INSTALL_RPATH VERSION_COMPATIBILITY)
  set(multivalue DEFAULT_CONFIG DEFAULT_CONFIG_MAPPED CUSTOM_CONFIG DEFAULT_COMPILE_PROFILES)
  cmake_parse_arguments(arg "${options}" "${onevalue}" "${multivalue}" ${ARGN})

  if(arg_UNPARSED_ARGUMENTS)
    message(
      FATAL_ERROR
      "[cs_initialize_project] unparsed arguments ${arg_UNPARSED_ARGUMENTS}: the arguments are "
      "NAMESPACE <namespace> CXX_STANDARD <standard> and the configurations (see MIGRATION.md)"
    )
  endif()

  # the namespace of the installed targets (<namespace>::<target>) and of the package (<namespace>Config.cmake)
  if(NOT arg_NAMESPACE)
    message(FATAL_ERROR "[cs_initialize_project] NAMESPACE <namespace> is required")
  endif()
  # a variable, not a global property: set in the directory of cs_initialize_project (this is called by the macro) and
  # inherited by its subdirectories, so a nested csCMake project has its own namespace
  set(CSCMAKE_NAMESPACE ${arg_NAMESPACE} PARENT_SCOPE)

  if(NOT arg_CXX_STANDARD)
    message(FATAL_ERROR "[cs_initialize_project] CXX_STANDARD <standard> is required (e.g. CXX_STANDARD 17)")
  endif()
  set(${required_cxx_standard} ${arg_CXX_STANDARD} PARENT_SCOPE)

  # compile profiles of every target of the project (cs_add_library / cs_add_executable): cscmake_default unless given,
  # NONE for none
  set(default_profiles cscmake_default)
  if(DEFINED arg_DEFAULT_COMPILE_PROFILES)
    set(default_profiles ${arg_DEFAULT_COMPILE_PROFILES})
  endif()
  if(default_profiles STREQUAL "NONE")
    set(default_profiles "")
  endif()
  set(CSCMAKE_DEFAULT_COMPILE_PROFILES "${default_profiles}" PARENT_SCOPE)

  # install RPATH of the targets (cs_add_library / cs_add_executable): on unless OFF
  # the compatibility of the installed package version (<namespace>ConfigVersion.cmake), set in every project
  _cs_version_compatibility("${arg_VERSION_COMPATIBILITY}" compatibility)
  set(CSCMAKE_VERSION_COMPATIBILITY ${compatibility} PARENT_SCOPE)

  if(DEFINED arg_INSTALL_RPATH)
    if(NOT arg_INSTALL_RPATH MATCHES "^(ON|OFF)$")
      message(FATAL_ERROR "[cs_initialize_project] INSTALL_RPATH is ON or OFF, got ${arg_INSTALL_RPATH}")
    endif()
    set(CSCMAKE_INSTALL_RPATH ${arg_INSTALL_RPATH} PARENT_SCOPE)
  endif()

  # the configurations belong to the build tree: the first csCMake project defines them; a nested project (added with
  # add_subdirectory) uses some of them, defined the same way, and registers nothing (_cs_check_build_configuration)
  get_property(nested GLOBAL PROPERTY CSCMAKE_BUILD_CONFIGURATIONS SET)

  foreach(default_config ${arg_DEFAULT_CONFIG})
    if(nested)
      _cs_check_build_configuration(${arg_NAMESPACE} ${default_config} "default")
      continue()
    endif()
    cs_debug_message("[_cs_parse_additional_configurations] adding default config ${default_config}")
    _cs_add_default_build_configuration(${default_config})
    set_property(GLOBAL PROPERTY CSCMAKE_BUILD_CONFIGURATION_${default_config}_DEFINITION "default")
  endforeach()
  _cs_add_mapped_configurations(${arg_NAMESPACE} "${nested}" ${arg_DEFAULT_CONFIG_MAPPED})
  _cs_add_custom_configurations(${arg_NAMESPACE} "${nested}" ${arg_CUSTOM_CONFIG})

  # a nested project: the derived variables come from the scope of the project that defined the configurations
  if(NOT nested)
    _cs_set_msvc_runtime_library_variables()
  endif()
endfunction()

# Fail if config, requested by the nested csCMake project namespace, is not a configuration of the build defined the
# same way (definition).
#
# Reads:
#
# * global property CSCMAKE_BUILD_CONFIGURATION_<config>_DEFINITION
function(_cs_check_build_configuration namespace config definition)
  get_property(defined GLOBAL PROPERTY CSCMAKE_BUILD_CONFIGURATION_${config}_DEFINITION)
  if(NOT defined)
    cs_get_build_configurations(configs_list)
    message(
      FATAL_ERROR
      "[cs_initialize_project] configuration ${config} of ${namespace} is not a configuration of "
      "the build (${configs_list}): the first csCMake project of the build defines them"
    )
  endif()
  if(NOT defined STREQUAL definition)
    message(
      FATAL_ERROR
      "[cs_initialize_project] configuration ${config} of ${namespace} is '${definition}', in "
      "the build it is '${defined}'"
    )
  endif()
endfunction()

# Apply the configurations of the build: with multi-config generators set CMAKE_CONFIGURATION_TYPES, with single-config
# ones fail if CMAKE_BUILD_TYPE is empty or not one of them.
#
# Writes:
#
# * cache variable CMAKE_CONFIGURATION_TYPES: the configurations of the build (owned by csCMake)
function(_cs_process_configurations)
  cs_get_build_configurations(configs_list)

  get_property(generator_is_multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
  if(generator_is_multi_config)
    set(
      CMAKE_CONFIGURATION_TYPES
      "${configs_list}"
      CACHE STRING
      "csCMake: the configurations of cs_initialize_project (owned by csCMake)"
      FORCE
    )
  else()
    list(JOIN configs_list ", " configs_text)
    if("${CMAKE_BUILD_TYPE}" STREQUAL "")
      message(
        FATAL_ERROR
        "[cs_initialize_project] CMAKE_BUILD_TYPE is empty: a single-config generator builds one configuration of "
        "the project (${configs_text}); use a preset, or -DCMAKE_BUILD_TYPE=<config>"
      )
    endif()
    if(NOT CMAKE_BUILD_TYPE IN_LIST configs_list)
      message(
        FATAL_ERROR
        "[cs_initialize_project] CMAKE_BUILD_TYPE ${CMAKE_BUILD_TYPE} is not a configuration of the project "
        "(${configs_text})"
      )
    endif()
  endif()
endfunction()

# Collect the CMake variables with a <CONFIG> part (cmake --help-variable-list), once per build tree; inspired by
# https://stackoverflow.com/q/75823363.
#
# Writes:
#
# * global property CSCMAKE_PER_CONFIG_VARIABLES
function(_cs_process_build_configurations_variables)
  # once per build tree (a nested csCMake project finds it done)
  get_property(done GLOBAL PROPERTY CSCMAKE_PER_CONFIG_VARIABLES SET)
  if(done)
    return()
  endif()
  execute_process(COMMAND ${CMAKE_COMMAND} --help-variable-list OUTPUT_VARIABLE var_full_list)
  # one variable per line (names have no ";")
  string(REPLACE "\n" ";" var_full_list "${var_full_list}")

  foreach(var ${var_full_list})
    if("${var}" MATCHES "<CONFIG>")
      if("${var}" MATCHES "<LANG>")
        foreach(
          lang
          C
          CXX
          CSharp
          CUDA
          OBJC
          OBJCXX
          Fortran
          HIP
          ISPC
          Swift
          ASM
          ASM_NASM
          ASM_MARMASM
          ASM_MASM
          ASM-ATT
        )
          # (supported languages list from https://cmake.org/cmake/help/latest/command/project.html)
          string(REPLACE "<LANG>" "${lang}" lang_var "${var}")
          list(APPEND config_var_list "${lang_var}")
        endforeach()
      else()
        list(APPEND config_var_list "${var}")
      endif()
    endif()
  endforeach()

  set_property(GLOBAL PROPERTY CSCMAKE_PER_CONFIG_VARIABLES ${config_var_list})
endfunction()

# Create the configuration config_to_in as a copy of config_from_in: every per-<CONFIG> CMake variable defined for the
# base configuration (e.g. the flags of the enabled languages; not the ones of other languages) and the MSVC runtime
# library, imported targets mapped onto base_config_and_fallback.
#
# Writes:
#
# * cache variable <every per-<CONFIG> variable defined for the base>_<CONFIG>: copy of the base configuration,
#   overridable
# * cache variable CSCMAKE_MSVC_RUNTIME_LIBRARY_<CONFIG>: copy of the base configuration, overridable
# * variable CMAKE_MAP_IMPORTED_CONFIG_<CONFIG>: project scope
function(_cs_copy_build_configuration config_from_in config_to_in base_config_and_fallback)
  _cs_get_per_config_variables(config_var_list)

  string(TOUPPER "${config_from_in}" config_from)
  string(TOUPPER "${config_to_in}" config_to)
  foreach(config_var ${config_var_list})
    string(REPLACE "<CONFIG>" "${config_from}" config_var_from "${config_var}")
    string(REPLACE "<CONFIG>" "${config_to}" config_var_to "${config_var}")
    if(NOT DEFINED "${config_var_from}")
      continue()
    endif()

    # cache variable, overridable (e.g. -DCMAKE_CXX_FLAGS_PARANOID=...); it keeps its value when the base configuration
    # changes: delete the cache entry to copy it again
    set(
      "${config_var_to}"
      "${${config_var_from}}"
      CACHE STRING
      "csCMake: copy of ${config_var_from} for the configuration ${config_to_in}"
    )
    mark_as_advanced("${config_var_to}")

    cs_debug_message("[_cs_copy_build_configuration] ${config_var_to} = ${${config_var_from}}")
  endforeach()

  # TODO(sc) consider also DEBUG_CONFIGURATIONS global property  ?

  _cs_set_in_project_scope(CMAKE_MAP_IMPORTED_CONFIG_${config_to} "${base_config_and_fallback}")
  cs_debug_message(
    "[_cs_copy_build_configuration] set CMAKE_MAP_IMPORTED_CONFIG_${config_to} = ${base_config_and_fallback}"
  )

  # the MSVC runtime library of the configuration it is based on (overridable, like the copies above)
  set(
    CSCMAKE_MSVC_RUNTIME_LIBRARY_${config_to}
    "${CSCMAKE_MSVC_RUNTIME_LIBRARY_${config_from}}"
    CACHE STRING
    "csCMake: MSVC runtime library in the ${config_to_in} configuration (copied from ${config_from_in})"
  )
endfunction()

#.rst:
# Variables
# ^^^^^^^^^
#
# .. variable:: CSCMAKE_DEBUG_POSTFIX
#
#   Cache variable: output name postfix of the targets in the Debug configuration (default ``d``).
#
# .. variable:: CSCMAKE_RELEASE_POSTFIX
#
#   Cache variable: output name postfix in the Release configuration (default none).
#
# .. variable:: CSCMAKE_RELWITHDEBINFO_POSTFIX
#
#   Cache variable: output name postfix in the RelWithDebInfo configuration (default ``rd``).
#
# .. variable:: CSCMAKE_<CONFIG>_POSTFIX
#
#   Output name postfix of a custom configuration (``POSTFIX`` of ``CUSTOM_CONFIG``), in the project scope.
#
# .. variable:: CSCMAKE_MSVC_RUNTIME_LIBRARY_<CONFIG>
#
#   Cache variable: MSVC runtime library of a configuration (``MultiThreadedDebugDLL`` in Debug, ``MultiThreadedDLL``
#   in Release and RelWithDebInfo; a custom configuration copies the one of its base configuration).
#
# .. variable:: CSCMAKE_MSVC_RUNTIME_LIBRARY_GENERATOR_EXPRESSION
#
#   The MSVC runtime library of every configuration as one generator expression (also
#   :variable:`CMAKE_MSVC_RUNTIME_LIBRARY`), in the project scope.
#
# Global properties
# ^^^^^^^^^^^^^^^^^
#
# .. prop_gbl:: CSCMAKE_BUILD_CONFIGURATIONS
#
#   The configurations of the build: default, mapped and custom ones.
#
# .. prop_gbl:: CSCMAKE_DEFAULT_BUILD_CONFIGURATIONS
#
#   The default configurations of the build (``DEFAULT_CONFIG`` and ``DEFAULT_CONFIG_MAPPED``).
#
# .. prop_gbl:: CSCMAKE_BUILD_CONFIGURATION_<config>_DEFINITION
#
#   How a configuration is defined: ``default``, ``mapped <fallbacks>`` or ``custom <base and fallbacks> postfix
#   <postfix>`` (a nested project must define it the same way).
#
# .. prop_gbl:: CSCMAKE_PER_CONFIG_VARIABLES
#
#   The CMake variables with a ``<CONFIG>`` part (``CMAKE_CXX_FLAGS_<CONFIG>``, ...), copied for custom configurations.
