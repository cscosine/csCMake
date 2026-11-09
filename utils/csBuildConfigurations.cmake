include_guard(GLOBAL)

# set cache variables with postfix for targets
set(CSCMAKE_DEBUG_POSTFIX
    "d"
    CACHE STRING "value for suffix in Debug config" FORCE)
set(CSCMAKE_RELEASE_POSTFIX
    ""
    CACHE STRING "value for suffix in Release config" FORCE)
set(CSCMAKE_RELWITHDEBINFO_POSTFIX
    "rd"
    CACHE STRING "value for suffix in RelWithDebInfo config" FORCE)

# note, MSVC supports also MinSizeRel, but it is not supported here

# set CACHE variables with the expected MSVC runtime library
set(CSCMAKE_MSVC_RUNTIME_LIBRARY_DEBUG
    "MultiThreadedDebugDLL"
    CACHE STRING "The MSVC runtime library to use in Debug" FORCE)
set(CSCMAKE_MSVC_RUNTIME_LIBRARY_RELWITHDEBINFO
    "MultiThreadedDLL"
    CACHE STRING "The MSVC runtime library to use in RelWithDebInfo" FORCE)
set(CSCMAKE_MSVC_RUNTIME_LIBRARY_RELEASE
    "MultiThreadedDLL"
    CACHE STRING "The MSVC runtime library to use in Release" FORCE)

# get the stored list of available build config (including default ones)
function(cs_get_build_configurations configs_list)
  get_property(val GLOBAL PROPERTY CSCMAKE_BUILD_CONFIGURATIONS)
  set(${configs_list}
      ${val}
      PARENT_SCOPE)
endfunction()

# get the stored list of available default build config
function(cs_get_default_build_configurations configs_list)
  get_property(val GLOBAL PROPERTY CSCMAKE_DEFAULT_BUILD_CONFIGURATIONS)
  set(${configs_list}
      ${val}
      PARENT_SCOPE)
endfunction()

# get all the CMAKE variables that belongs to a configuration
function(_cs_get_per_config_variables configs_list)
  get_property(val GLOBAL PROPERTY CSCMAKE_PER_CONFIG_VARIABLES)
  set(${configs_list}
      ${val}
      PARENT_SCOPE)
endfunction()

# add a default configuration
function(_cs_add_default_build_configuration config)
  cs_get_build_configurations(configs_list)
  cs_get_default_build_configurations(configs_list_default)

  set(valid_default_configs "Debug;Release;RelWithDebInfo")

  if(NOT ${config} IN_LIST valid_default_configs)
    message(
      FATAL_ERROR
        "[cs_initialize_project] DEFAULT_CONFIG called with invalid default config ${config}, choose one of ${valid_default_configs}"
    )
  endif()

  if(NOT ${config} IN_LIST configs_list)
    list(APPEND configs_list ${config})
  else()
    message(FATAL_ERROR "[cs_initialize_project] DEFAULT_CONFIG called with duplicated element ${config}")
  endif()

  if(NOT ${config} IN_LIST configs_list_default)
    list(APPEND configs_list_default ${config})
  else()
    message(
      FATAL_ERROR "[cs_initialize_project] DEFAULT_CONFIG called with duplicated element ${config} in default list")
  endif()

  set_property(GLOBAL PROPERTY CSCMAKE_BUILD_CONFIGURATIONS ${configs_list})
  set_property(GLOBAL PROPERTY CSCMAKE_DEFAULT_BUILD_CONFIGURATIONS ${configs_list_default})

endfunction()

# add a default configuration that need a fallback mapping
function(_cs_add_default_build_configuration_mapped config base_config_and_fallback)
  _cs_add_default_build_configuration(${config})

  string(TOUPPER "${config}" config_ucase)

  set("CMAKE_MAP_IMPORTED_CONFIG_${config_ucase}"
      "${base_config_and_fallback}"
      CACHE STRING "value for custom build CMAKE_MAP_IMPORTED_CONFIG_${config_ucase}" FORCE)
  cs_debug_message(
    "[_cs_add_default_build_configuration_mapped] set CMAKE_MAP_IMPORTED_CONFIG_${config_ucase} = ${base_config_and_fallback}"
    True)

endfunction()

# add a custom configuration, based on a default one
function(_cs_add_custom_build_configuration config base_config postfix base_config_and_fallback)
  cs_get_build_configurations(configs_list)
  cs_get_default_build_configurations(configs_list_default)

  if(NOT ${config} IN_LIST configs_list)
    list(APPEND configs_list ${config})
  else()
    message(FATAL_ERROR "[_cs_add_custom_build_configuration] called with duplicated element ${config}")
  endif()

  if(NOT ${base_config} IN_LIST configs_list_default)
    message(
      FATAL_ERROR
        "[_cs_add_custom_build_configuration] element ${config} base on ${base_config}, which is not in default configs ${configs_list_default}"
    )
  else()
    _cs_copy_build_configuration(${base_config} ${config} "${base_config_and_fallback}")
  endif()

  string(TOUPPER "${config}" config_upper)
  string(TOUPPER "${base_config}" BASE_CONFIG_UPPER)

  # set the postfix
  set(CSCMAKE_${config_upper}_POSTFIX
      "${postfix}"
      CACHE STRING "value for suffix in ${config} config" FORCE)

  set_property(GLOBAL PROPERTY CSCMAKE_BUILD_CONFIGURATIONS ${configs_list})
endfunction()

# helper function to parse the cs_initialize_project arguments and add build types accepts extra arguments to specify
# the available build configurations: _cs_process_configurations( CXX_STANDARD 14/17/... DEFAULT_CONFIG Debug
# DEFAULT_CONFIG Release DEFAULT_CONFIG_MAPPED RelWithDebInfo MAPPED_TO "RelWithDebInfo,Release," CUSTOM_CONFIG
# MyCustomConfig1 BASED_ON Debug POSTFIX "d" CUSTOM_CONFIG MyCustomConfig2 BASED_ON Release POSTFIX ""
# [STRICT_COMPILATION_ON_CONFIG ConfigName] note, make sure to use POSTFIX "" if no postfix has to be used )
function(_cs_parse_additional_configurations required_cxx_standard)
  # cmake-lint: disable=R0912,R0915
  cs_debug_message("[_cs_parse_additional_configurations] ${ARGN}")

  set(options "")
  set(onevalue NAMESPACE CXX_STANDARD STRICT_COMPILATION_ON_CONFIG)
  set(multivalue DEFAULT_CONFIG DEFAULT_CONFIG_MAPPED CUSTOM_CONFIG)
  cmake_parse_arguments(arg "${options}" "${onevalue}" "${multivalue}" ${ARGN})

  if(arg_UNPARSED_ARGUMENTS)
    message(
      FATAL_ERROR
        "[cs_initialize_project] unparsed arguments ${arg_UNPARSED_ARGUMENTS} (the project name argument was replaced by NAMESPACE <namespace>, see MIGRATION.md)"
    )
  endif()

  # the namespace of the installed targets (<namespace>::<target>) and of the package (<namespace>Config.cmake)
  if(NOT arg_NAMESPACE)
    message(FATAL_ERROR "[cs_initialize_project] NAMESPACE <namespace> is required")
  endif()
  # a variable, not a global property: set in the directory of cs_initialize_project (this is called by the macro) and
  # inherited by its subdirectories, so a nested csCMake project has its own namespace
  set(CSCMAKE_NAMESPACE
      ${arg_NAMESPACE}
      PARENT_SCOPE)

  # If not set by caller, error
  if(NOT arg_CXX_STANDARD)
    message(FATAL_ERROR "[cs_initialize_project] CXX_STANDARD <standard> is required (e.g. CXX_STANDARD 17)")
  endif()

  # return cxx standard
  set(${required_cxx_standard}
      ${arg_CXX_STANDARD}
      PARENT_SCOPE)

  # add default configurations
  foreach(default_config ${arg_DEFAULT_CONFIG})
    cs_debug_message("[_cs_parse_additional_configurations] adding default config ${default_config}")
    _cs_add_default_build_configuration(${default_config})
  endforeach()

  # add default configurations mapped
  list(LENGTH arg_DEFAULT_CONFIG_MAPPED arg_default_config_mapped_size)
  math(EXPR mod_size "${arg_default_config_mapped_size} % 3")
  if(NOT ${mod_size} EQUAL 0)
    message(
      FATAL_ERROR
        "[_cs_parse_additional_configurations] DEFAULT_CONFIG_MAPPED need to specify values as : DEFAULT_CONFIG_MAPPED RelWithDebInfo MAPPED_TO \"Release,\". Got ${arg_DEFAULT_CONFIG_MAPPED}"
    )
  endif()

  set(idx 0)
  while(arg_default_config_mapped_size GREATER idx)
    list(GET arg_DEFAULT_CONFIG_MAPPED ${idx} default_config_mapped)
    math(EXPR idx "${idx} + 1")

    list(GET arg_DEFAULT_CONFIG_MAPPED ${idx} mapped_to_keyword)
    math(EXPR idx "${idx} + 1")

    list(GET arg_DEFAULT_CONFIG_MAPPED ${idx} base_config_and_fallback)
    math(EXPR idx "${idx} + 1")

    # parse the ; separated BASE_CONFIG_AND_FALLBACK variable
    string(FIND "${base_config_and_fallback}" "," pos)
    if(${pos} EQUAL -1)
      set(base_config "${base_config_and_fallback}")
    else()
      string(SUBSTRING "${base_config_and_fallback}" 0 ${pos} base_config)
      string(REPLACE "," ";" base_config_and_fallback ${base_config_and_fallback})
    endif()

    if(NOT ${mapped_to_keyword} STREQUAL "MAPPED_TO")
      message(
        FATAL_ERROR
          "[_cs_parse_additional_configurations] DEFAULT_CONFIG_MAPPED need to specify values as : DEFAULT_CONFIG_MAPPED RelWithDebInfo MAPPED_TO \"Release,\". Got ${arg_DEFAULT_CONFIG_MAPPED}"
      )
    endif()

    cs_debug_message(
      "[_cs_parse_additional_configurations] adding mapped config ${default_config_mapped} ${base_config_and_fallback}")
    _cs_add_default_build_configuration_mapped(${default_config_mapped} "${base_config_and_fallback}")

  endwhile()

  # add custom configs, based on default ones
  list(LENGTH arg_CUSTOM_CONFIG arg_custom_config_size)
  math(EXPR mod_size "${arg_custom_config_size} % 5")
  if(NOT ${mod_size} EQUAL 0)
    message(
      FATAL_ERROR
        "[_cs_parse_additional_configurations] CUSTOM_CONFIG need to specify values as : CUSTOM_CONFIG MyCustomConfig1 BASED_ON Debug POSTFIX \"d\". Got ${arg_CUSTOM_CONFIG}"
    )
  endif()

  set(idx 0)
  while(arg_custom_config_size GREATER idx)
    list(GET arg_CUSTOM_CONFIG ${idx} custom_config)
    math(EXPR idx "${idx} + 1")

    list(GET arg_CUSTOM_CONFIG ${idx} based_on_keyword)
    math(EXPR idx "${idx} + 1")

    list(GET arg_CUSTOM_CONFIG ${idx} base_config_and_fallback)
    math(EXPR idx "${idx} + 1")

    list(GET arg_CUSTOM_CONFIG ${idx} postfix_keyword)
    math(EXPR idx "${idx} + 1")

    list(GET arg_CUSTOM_CONFIG ${idx} postfix_value)
    math(EXPR idx "${idx} + 1")

    # parse the ; separated BASE_CONFIG_AND_FALLBACK variable
    string(FIND "${base_config_and_fallback}" "," pos)
    if(${pos} EQUAL -1)
      set(base_config "${base_config_and_fallback}")
    else()
      string(SUBSTRING "${base_config_and_fallback}" 0 ${pos} base_config)
      string(REPLACE "," ";" base_config_and_fallback ${base_config_and_fallback})
    endif()

    if(NOT ${based_on_keyword} STREQUAL "BASED_ON")
      message(
        FATAL_ERROR
          "[_cs_parse_additional_configurations] CUSTOM_CONFIG need to specify values as : CUSTOM_CONFIG MyCustomConfig1 BASED_ON Debug POSTFIX \"d\". Expected BASED_ON found ${based_on_keyword}"
      )
    endif()
    if(NOT ${postfix_keyword} STREQUAL "POSTFIX")
      message(
        FATAL_ERROR
          "[_cs_parse_additional_configurations] CUSTOM_CONFIG need to specify values as : CUSTOM_CONFIG MyCustomConfig1 BASED_ON Debug POSTFIX \"d\". Expected POSTFIX found ${postfix_keyword}"
      )
    endif()

    cs_debug_message(
      "[_cs_parse_additional_configurations] adding custom config ${custom_config} ${base_config} ${base_config_and_fallback}"
    )
    _cs_add_custom_build_configuration(${custom_config} ${base_config} ${postfix_value} "${base_config_and_fallback}")

    # for some reason, the output directory of custom configuration does not get set properly, therefore we need to set
    # it explicitely TODO(sc) try to understand better this behavior, at the moment this is a workaround
    get_property(generator_is_multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
    if(generator_is_multi_config)
      string(TOUPPER "${custom_config}" custom_config_ucase)
      set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_${custom_config_ucase}
          "${CMAKE_BINARY_DIR}/bin/${custom_config}"
          CACHE STRING "RUNTIME OUTPUT DIRECTORY for ${custom_config}" FORCE)
      set(CMAKE_LIBRARY_OUTPUT_DIRECTORY_${custom_config_ucase}
          "${CMAKE_BINARY_DIR}/lib/${custom_config}"
          CACHE STRING "LIBRARY OUTPUT DIRECTORY for ${custom_config}" FORCE)
      set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY_${custom_config_ucase}
          "${CMAKE_BINARY_DIR}/lib/${custom_config}"
          CACHE STRING "ARCHIVE OUTPUT DIRECTORY for ${custom_config}" FORCE)
    else()
      set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_${custom_config_ucase}
          "${CMAKE_BINARY_DIR}/bin"
          CACHE STRING "RUNTIME OUTPUT DIRECTORY for ${custom_config}" FORCE)
      set(CMAKE_LIBRARY_OUTPUT_DIRECTORY_${custom_config_ucase}
          "${CMAKE_BINARY_DIR}/lib"
          CACHE STRING "LIBRARY OUTPUT DIRECTORY for ${custom_config}" FORCE)
      set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY_${custom_config_ucase}
          "${CMAKE_BINARY_DIR}/lib"
          CACHE STRING "ARCHIVE OUTPUT DIRECTORY for ${custom_config}" FORCE)
    endif()
  endwhile()

  # check if the user want strict compilation flags for a specific configutation
  if(arg_STRICT_COMPILATION_ON_CONFIG)
    # check such configuration exists
    cs_get_build_configurations(configs_list)
    if(arg_STRICT_COMPILATION_ON_CONFIG IN_LIST configs_list)
      _cs_set_strict_build_configuration(${arg_STRICT_COMPILATION_ON_CONFIG})
    else()
      message(
        FATAL_ERROR
          "[cs_initialize_project] STRICT_COMPILATION_ON_CONFIG ${arg_STRICT_COMPILATION_ON_CONFIG} is not one of the configurations of the project: ${configs_list}"
      )
    endif()
  endif()

  # finally, prepare the variable CSCMAKE_MSVC_RUNTIME_LIBRARY_GENERATOR_EXPRESSION (will be used by targets added with
  # cs_add_library / cs_add_executable)
  set(temp_string "")
  cs_get_build_configurations(configs_list)
  foreach(config ${configs_list})
    string(TOUPPER "${config}" config_ucase)
    set(value "${CSCMAKE_MSVC_RUNTIME_LIBRARY_${config_ucase}}")
    set(temp_string "${temp_string}$<$<CONFIG:${config}>:${value}>")
  endforeach()
  set(CSCMAKE_MSVC_RUNTIME_LIBRARY_GENERATOR_EXPRESSION
      "${temp_string}"
      CACHE STRING "final value for MSVC_RUNTIME_LIBRARY for targets, with generator expressions" FORCE)

  # and set CMAKE_MSVC_RUNTIME_LIBRARY = CSCMAKE_MSVC_RUNTIME_LIBRARY_GENERATOR_EXPRESSION for generic targes (fallback)
  set(CMAKE_MSVC_RUNTIME_LIBRARY
      "${temp_string}"
      CACHE STRING "default value for MSVC_RUNTIME_LIBRARY for targets, with generator expressions" FORCE)
endfunction()

# Apply the configurations requested in cs_initialize_project: on multi-config generators reset
# CMAKE_CONFIGURATION_TYPES to them, on single-config generators fail if CMAKE_BUILD_TYPE is not one of them.
function(_cs_process_configurations)
  cs_get_build_configurations(configs_list)

  get_property(generator_is_multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
  if(generator_is_multi_config)
    set(CMAKE_CONFIGURATION_TYPES
        "${configs_list}"
        CACHE STRING "Reset the configurations to what we need" FORCE)
  else()
    if(NOT ${CMAKE_BUILD_TYPE} IN_LIST configs_list)
      message(
        FATAL_ERROR
          "[_cs_process_configurations] request to build with config ${CMAKE_BUILD_TYPE} which is not supported by this project"
      )
    endif()
  endif()
endfunction()

# Store configname as the configuration built with strict compilation flags (global property
# CSCMAKE_STRICT_BUILD_CONFIGURATION).
function(_cs_set_strict_build_configuration configname)
  set_property(GLOBAL PROPERTY CSCMAKE_STRICT_BUILD_CONFIGURATION ${configname})
endfunction()

# Return in configname the configuration built with strict compilation flags (STRICT_COMPILATION_ON_CONFIG of
# cs_initialize_project), empty if none.
function(cs_get_strict_build_configuration configname)
  get_property(val GLOBAL PROPERTY CSCMAKE_STRICT_BUILD_CONFIGURATION)
  set(${configname}
      ${val}
      PARENT_SCOPE)
endfunction()

# set a global property CSCMAKE_PER_CONFIG_VARIABLES highly inspired from
# https://stackoverflow.com/questions/75823363/how-can-i-copy-all-build-type-parameters-from-an-existing-build-configuration-ty/75828118#75828118
function(_cs_process_build_configurations_variables)
  execute_process(COMMAND ${CMAKE_COMMAND} --help-variable-list
                  OUTPUT_FILE "${CMAKE_CURRENT_BINARY_DIR}/cmake_var_full_list.txt")
  file(STRINGS "${CMAKE_CURRENT_BINARY_DIR}/cmake_var_full_list.txt" var_full_list)

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
          ASM-ATT)
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

# Create the configuration config_to_in as a copy of config_from_in: copy every per-<CONFIG> CMake variable and the MSVC
# runtime library, and map imported targets of the new configuration onto base_config_and_fallback
# (CMAKE_MAP_IMPORTED_CONFIG_<CONFIG>).
function(_cs_copy_build_configuration config_from_in config_to_in base_config_and_fallback)
  _cs_get_per_config_variables(config_var_list)

  string(TOUPPER "${config_from_in}" config_from)
  string(TOUPPER "${config_to_in}" config_to)
  foreach(config_var ${config_var_list})
    string(REPLACE "<CONFIG>" "${config_from}" config_var_from "${config_var}")
    string(REPLACE "<CONFIG>" "${config_to}" config_var_to "${config_var}")

    set("${config_var_to}"
        "${${config_var_from}}"
        CACHE STRING "value for custom build ${config_to}" FORCE)
    mark_as_advanced("${config_var_to}")

    cs_debug_message("[_cs_copy_build_configuration] ${config_var_to} = ${${config_var_from}}")
  endforeach()

  # TODO(sc) consider also DEBUG_CONFIGURATIONS global property  ?

  set("CMAKE_MAP_IMPORTED_CONFIG_${config_to}"
      "${base_config_and_fallback}"
      CACHE STRING "value for custom build CMAKE_MAP_IMPORTED_CONFIG_${config_to}" FORCE)
  cs_debug_message(
    "[_cs_copy_build_configuration] set CMAKE_MAP_IMPORTED_CONFIG_${config_to} = ${base_config_and_fallback}" True)

  # set the MSVC Runtime Library based on the config to copy
  set(CSCMAKE_MSVC_RUNTIME_LIBRARY_${config_to}
      "${CSCMAKE_MSVC_RUNTIME_LIBRARY_${config_from}}"
      CACHE STRING "The MSVC runtime library to use in ${config_to_in}, copied from ${config_from_in}" FORCE)

endfunction()

# Print (debug) the per-configuration variables of every configuration of the project, tagging each block with
# add_message.
function(cs_print_all_configurations_variables add_message)
  cs_get_build_configurations(config_var_list)
  cs_debug_message("[cs_print_all_configurations_variables] configs are ${config_var_list}")
  foreach(config ${config_var_list})
    cs_debug_message("[cs_print_all_configurations_variables] CONFIG ${config} ${add_message}")
    cs_print_configuration_variables(${config} "  ")
    cs_debug_message("[cs_print_all_configurations_variables] -------")
  endforeach()
  cs_debug_message(
    "[cs_print_all_configurations_variables] CSCMAKE_MSVC_RUNTIME_LIBRARY_GENERATOR_EXPRESSION ${CSCMAKE_MSVC_RUNTIME_LIBRARY_GENERATOR_EXPRESSION}"
  )
  cs_debug_message("[cs_print_all_configurations_variables] end --------")

endfunction()

# Print (debug) the per-configuration CMake and csCMake variables of config_in, each line prefixed with print_prefix.
function(cs_print_configuration_variables config_in print_prefix)

  _cs_get_per_config_variables(config_var_list)
  string(TOUPPER "${config_in}" config)

  foreach(var ${config_var_list})
    string(REPLACE "<CONFIG>" "${config}" var_out "${var}")
    cs_debug_message("${print_prefix} ${var_out} = ${${var_out}}")
  endforeach()

  # extra, CS variables
  cs_debug_message("${print_prefix} CSCMAKE_MSVC_RUNTIME_LIBRARY_${config} = ${CSCMAKE_MSVC_RUNTIME_LIBRARY_${config}}")
  cs_debug_message("${print_prefix} CSCMAKE_${config}_POSTFIX = ${CSCMAKE_${config}_POSTFIX}")

endfunction()
