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
function(cs_get_build_configurations CONFIGS_LIST)
  get_property(VAL GLOBAL PROPERTY csCMakeConfigurationTypes)
  set(${CONFIGS_LIST}
      ${VAL}
      PARENT_SCOPE)
endfunction()

# get the stored list of available default build config
function(cs_get_default_build_configurations CONFIGS_LIST)
  get_property(VAL GLOBAL PROPERTY csCMakeConfigurationTypesDefault)
  set(${CONFIGS_LIST}
      ${VAL}
      PARENT_SCOPE)
endfunction()

# get all the CMAKE variables that belongs to a configuration
function(_cs_get_per_config_variables CONFIGS_LIST)
  get_property(VAL GLOBAL PROPERTY csCMakeConfigurationVariables)
  set(${CONFIGS_LIST}
      ${VAL}
      PARENT_SCOPE)
endfunction()

# add a default configuration
function(_cs_add_default_build_configuration CONFIG)
  cs_get_build_configurations(CONFIGS_LIST)
  cs_get_default_build_configurations(CONFIGS_LIST_DEFAULT)

  set(VALID_DEFAULT_CONFIGS "Debug;Release;RelWithDebInfo")

  if(NOT ${CONFIG} IN_LIST VALID_DEFAULT_CONFIGS)
    message(
      FATAL_ERROR
        "[cs_set_default_build_config] called with invalid default config ${CONFIG}, choose one of ${VALID_DEFAULT_CONFIGS}"
    )
  endif()

  if(NOT ${CONFIG} IN_LIST CONFIGS_LIST)
    list(APPEND CONFIGS_LIST ${CONFIG})
  else()
    message(FATAL_ERROR "[cs_set_default_build_config] called with duplicated element ${CONFIG}")
  endif()

  if(NOT ${CONFIG} IN_LIST CONFIGS_LIST_DEFAULT)
    list(APPEND CONFIGS_LIST_DEFAULT ${CONFIG})
  else()
    message(FATAL_ERROR "[cs_set_default_build_config] called with duplicated element ${CONFIG} in default list")
  endif()

  set_property(GLOBAL PROPERTY csCMakeConfigurationTypes ${CONFIGS_LIST})
  set_property(GLOBAL PROPERTY csCMakeConfigurationTypesDefault ${CONFIGS_LIST_DEFAULT})

endfunction()

# add a default configuration that need a fallback mapping
function(_cs_add_default_build_configuration_mapped CONFIG BASE_CONFIG_AND_FALLBACK)
  _cs_add_default_build_configuration(${CONFIG})

  string(TOUPPER "${CONFIG}" CONFIG_UCASE)

  set("CMAKE_MAP_IMPORTED_CONFIG_${CONFIG_UCASE}"
      "${BASE_CONFIG_AND_FALLBACK}"
      CACHE STRING "value for custom build CMAKE_MAP_IMPORTED_CONFIG_${CONFIG_UCASE}" FORCE)
  cs_debug_message(
    "[_cs_copy_build_configuration] set CMAKE_MAP_IMPORTED_CONFIG_${CONFIG_UCASE} = ${BASE_CONFIG_AND_FALLBACK}" True)

endfunction()

# add a custom configuration, based on a default one
function(_cs_add_custom_build_configuration CONFIG BASE_CONFIG POSTFIX BASE_CONFIG_AND_FALLBACK)
  cs_get_build_configurations(CONFIGS_LIST)
  cs_get_default_build_configurations(CONFIGS_LIST_DEFAULT)

  if(NOT ${CONFIG} IN_LIST CONFIGS_LIST)
    list(APPEND CONFIGS_LIST ${CONFIG})
  else()
    message(FATAL_ERROR "[_cs_add_custom_build_configuration] called with duplicated element ${CONFIG}")
  endif()

  if(NOT ${BASE_CONFIG} IN_LIST CONFIGS_LIST_DEFAULT)
    message(
      FATAL_ERROR
        "[_cs_add_custom_build_configuration] element ${CONFIG} base on ${BASE_CONFIG}, which is not in default configs ${CONFIGS_LIST_DEFAULT}"
    )
  else()
    _cs_copy_build_configuration(${BASE_CONFIG} ${CONFIG} "${BASE_CONFIG_AND_FALLBACK}")
  endif()

  string(TOUPPER "${CONFIG}" CONFIG_UPPER)
  string(TOUPPER "${BASE_CONFIG}" BASE_CONFIG_UPPER)

  # set the postfix
  set(CSCMAKE_${CONFIG_UPPER}_POSTFIX
      "${POSTFIX}"
      CACHE STRING "value for suffix in ${CONFIG} config" FORCE)

  set_property(GLOBAL PROPERTY csCMakeConfigurationTypes ${CONFIGS_LIST})
endfunction()

# helper function to parse the cs_initialize_project arguments and add build types accepts extra arguments to specify
# the available build configurations: _cs_process_configurations( CXX_STANDARD 14/17/... DEFAULT_CONFIG Debug
# DEFAULT_CONFIG Release DEFAULT_CONFIG_MAPPED RelWithDebInfo MAPPED_TO "RelWithDebInfo,Release," CUSTOM_CONFIG
# MyCustomConfig1 BASED_ON Debug POSTFIX "d" CUSTOM_CONFIG MyCustomConfig2 BASED_ON Release POSTFIX ""
# [STRICT_COMPILATION_ON_CONFIG ConfigName] note, make sure to use POSTFIX "" if no postfix has to be used )
function(_cs_parse_additional_configurations REQUIRED_CXX_STANDARD)
  # cmake-lint: disable=R0912,R0915
  cs_debug_message("[_cs_parse_additional_configurations] ${ARGN}")

  set(OPTIONS "")
  set(ONEVALUE CXX_STANDARD STRICT_COMPILATION_ON_CONFIG)
  set(MULTIVALUE DEFAULT_CONFIG DEFAULT_CONFIG_MAPPED CUSTOM_CONFIG)
  cmake_parse_arguments(ARG "${OPTIONS}" "${ONEVALUE}" "${MULTIVALUE}" ${ARGN})

  if(ARG_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR "[_cs_parse_additional_configurations] has unparsed arguments ${ARG_UNPARSED_ARGUMENTS}")
  endif()

  # If not set by caller, error
  if(NOT ARG_CXX_STANDARD)
    message(FATAL_ERROR "USE cs_initialize_project(CXX_STANDARD XX)")
  endif()

  # return cxx standard
  set(${REQUIRED_CXX_STANDARD}
      ${ARG_CXX_STANDARD}
      PARENT_SCOPE)

  # add default configurations
  foreach(DEFAULT_CONFIG ${ARG_DEFAULT_CONFIG})
    cs_debug_message("adding default config ${DEFAULT_CONFIG}")
    _cs_add_default_build_configuration(${DEFAULT_CONFIG})
  endforeach()

  # add default configurations mapped
  list(LENGTH ARG_DEFAULT_CONFIG_MAPPED ARG_DEFAULT_CONFIG_MAPPED_SIZE)
  math(EXPR MOD_SIZE "${ARG_DEFAULT_CONFIG_MAPPED_SIZE} % 3")
  if(NOT ${MOD_SIZE} EQUAL 0)
    message(
      FATAL_ERROR
        "[_cs_parse_additional_configurations] DEFAULT_CONFIG_MAPPED need to specify values as : DEFAULT_CONFIG_MAPPED RelWithDebInfo MAPPED_TO \"Release,\". Got ${ARG_DEFAULT_CONFIG_MAPPED}"
    )
  endif()

  set(I 0)
  while(ARG_DEFAULT_CONFIG_MAPPED_SIZE GREATER I)
    list(GET ARG_DEFAULT_CONFIG_MAPPED ${I} DEFAULT_CONFIG_MAPPED)
    math(EXPR I "${I} + 1")

    list(GET ARG_DEFAULT_CONFIG_MAPPED ${I} MAPPED_TO_KEYWORD)
    math(EXPR I "${I} + 1")

    list(GET ARG_DEFAULT_CONFIG_MAPPED ${I} BASE_CONFIG_AND_FALLBACK)
    math(EXPR I "${I} + 1")

    # parse the ; separated BASE_CONFIG_AND_FALLBACK variable
    string(FIND "${BASE_CONFIG_AND_FALLBACK}" "," POS)
    if(${POS} EQUAL -1)
      set(BASE_CONFIG "${BASE_CONFIG_AND_FALLBACK}")
    else()
      string(SUBSTRING "${BASE_CONFIG_AND_FALLBACK}" 0 ${POS} BASE_CONFIG)
      string(REPLACE "," ";" BASE_CONFIG_AND_FALLBACK ${BASE_CONFIG_AND_FALLBACK})
    endif()

    if(NOT ${MAPPED_TO_KEYWORD} STREQUAL "MAPPED_TO")
      message(
        FATAL_ERROR
          "[_cs_parse_additional_configurations] DEFAULT_CONFIG_MAPPED need to specify values as : DEFAULT_CONFIG_MAPPED RelWithDebInfo MAPPED_TO \"Release,\". Got ${ARG_DEFAULT_CONFIG_MAPPED}"
      )
    endif()

    cs_debug_message(
      "[_cs_parse_additional_configurations] adding custom config ${CUSTOM_CONFIG} ${BASE_CONFIG} ${BASE_CONFIG_AND_FALLBACK}"
    )
    _cs_add_default_build_configuration_mapped(${DEFAULT_CONFIG_MAPPED} "${BASE_CONFIG_AND_FALLBACK}")

  endwhile()

  # add custom configs, based on default ones
  list(LENGTH ARG_CUSTOM_CONFIG ARG_CUSTOM_CONFIG_SIZE)
  math(EXPR MOD_SIZE "${ARG_CUSTOM_CONFIG_SIZE} % 5")
  if(NOT ${MOD_SIZE} EQUAL 0)
    message(
      FATAL_ERROR
        "[_cs_parse_additional_configurations] CUSTOM_CONFIG need to specify values as : CUSTOM_CONFIG MyCustomConfig1 BASED_ON Debug POSTFIX \"d\". Got ${ARG_CUSTOM_CONFIG}"
    )
  endif()

  set(I 0)
  while(ARG_CUSTOM_CONFIG_SIZE GREATER I)
    list(GET ARG_CUSTOM_CONFIG ${I} CUSTOM_CONFIG)
    math(EXPR I "${I} + 1")

    list(GET ARG_CUSTOM_CONFIG ${I} BASED_ON_KEYWORD)
    math(EXPR I "${I} + 1")

    list(GET ARG_CUSTOM_CONFIG ${I} BASE_CONFIG_AND_FALLBACK)
    math(EXPR I "${I} + 1")

    list(GET ARG_CUSTOM_CONFIG ${I} POSTFIX_KEYWORD)
    math(EXPR I "${I} + 1")

    list(GET ARG_CUSTOM_CONFIG ${I} POSTFIX_VALUE)
    math(EXPR I "${I} + 1")

    # parse the ; separated BASE_CONFIG_AND_FALLBACK variable
    string(FIND "${BASE_CONFIG_AND_FALLBACK}" "," POS)
    if(${POS} EQUAL -1)
      set(BASE_CONFIG "${BASE_CONFIG_AND_FALLBACK}")
    else()
      string(SUBSTRING "${BASE_CONFIG_AND_FALLBACK}" 0 ${POS} BASE_CONFIG)
      string(REPLACE "," ";" BASE_CONFIG_AND_FALLBACK ${BASE_CONFIG_AND_FALLBACK})
    endif()

    if(NOT ${BASED_ON_KEYWORD} STREQUAL "BASED_ON")
      message(
        FATAL_ERROR
          "[_cs_parse_additional_configurations] CUSTOM_CONFIG need to specify values as : CUSTOM_CONFIG MyCustomConfig1 BASED_ON Debug POSTFIX \"d\". Expected BASED_ON found ${BASED_ON_KEYWORD}"
      )
    endif()
    if(NOT ${POSTFIX_KEYWORD} STREQUAL "POSTFIX")
      message(
        FATAL_ERROR
          "[_cs_parse_additional_configurations] CUSTOM_CONFIG need to specify values as : CUSTOM_CONFIG MyCustomConfig1 BASED_ON Debug POSTFIX \"d\". Expected POSTFIX found ${POSTFIX_KEYWORD}"
      )
    endif()

    cs_debug_message(
      "[_cs_parse_additional_configurations] adding custom config ${CUSTOM_CONFIG} ${BASE_CONFIG} ${BASE_CONFIG_AND_FALLBACK}"
    )
    _cs_add_custom_build_configuration(${CUSTOM_CONFIG} ${BASE_CONFIG} ${POSTFIX_VALUE} "${BASE_CONFIG_AND_FALLBACK}")

    # for some reason, the output directory of custom configuration does not get set properly, therefore we need to set
    # it explicitely TODO(sc) try to understand better this behavior, at the moment this is a workaround
    get_property(GENERATOR_IS_MULTI_CONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
    if(GENERATOR_IS_MULTI_CONFIG)
      string(TOUPPER "${CUSTOM_CONFIG}" CUSTOM_CONFIG_UCASE)
      set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_${CUSTOM_CONFIG_UCASE}
          "${CMAKE_BINARY_DIR}/bin/${CUSTOM_CONFIG}"
          CACHE STRING "RUNTIME OUTPUT DIRECTORY for ${CUSTOM_CONFIG}" FORCE)
      set(CMAKE_LIBRARY_OUTPUT_DIRECTORY_${CUSTOM_CONFIG_UCASE}
          "${CMAKE_BINARY_DIR}/lib/${CUSTOM_CONFIG}"
          CACHE STRING "LIBRARY OUTPUT DIRECTORY for ${CUSTOM_CONFIG}" FORCE)
      set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY_${CUSTOM_CONFIG_UCASE}
          "${CMAKE_BINARY_DIR}/lib/${CUSTOM_CONFIG}"
          CACHE STRING "ARCHIVE OUTPUT DIRECTORY for ${CUSTOM_CONFIG}" FORCE)
    else()
      set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_${CUSTOM_CONFIG_UCASE}
          "${CMAKE_BINARY_DIR}/bin"
          CACHE STRING "RUNTIME OUTPUT DIRECTORY for ${CUSTOM_CONFIG}" FORCE)
      set(CMAKE_LIBRARY_OUTPUT_DIRECTORY_${CUSTOM_CONFIG_UCASE}
          "${CMAKE_BINARY_DIR}/lib"
          CACHE STRING "LIBRARY OUTPUT DIRECTORY for ${CUSTOM_CONFIG}" FORCE)
      set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY_${CUSTOM_CONFIG_UCASE}
          "${CMAKE_BINARY_DIR}/lib"
          CACHE STRING "ARCHIVE OUTPUT DIRECTORY for ${CUSTOM_CONFIG}" FORCE)
    endif()
  endwhile()

  # check if the user want strict compilation flags for a specific configutation
  if(ARG_STRICT_COMPILATION_ON_CONFIG)
    # check such configuration exists
    cs_get_build_configurations(CONFIGS_LIST)
    if(ARG_STRICT_COMPILATION_ON_CONFIG IN_LIST CONFIGS_LIST)
      _cs_set_strict_build_configuration(${ARG_STRICT_COMPILATION_ON_CONFIG})
    else()
      message(
        FATAL_ERROR
          "The value ${ARG_STRICT_COMPILATION_ON_CONFIG} of ${STRICT_COMPILATION_ON_CONFIG} is not a valid configuration in list ${CONFIGS_LIST}"
      )
    endif()
  endif()

  # finally, prepare the variable CSCMAKE_MSVC_RUNTIME_LIBRARY_GENERATOR_EXPRESSION (will be used by targets added with
  # cs_add_library / cs_add_executable)
  set(TEMP_STRING "")
  cs_get_build_configurations(CONFIGS_LIST)
  foreach(CONFIG ${CONFIGS_LIST})
    string(TOUPPER "${CONFIG}" CONFIG_UCASE)
    set(VALUE "${CSCMAKE_MSVC_RUNTIME_LIBRARY_${CONFIG_UCASE}}")
    set(TEMP_STRING "${TEMP_STRING}$<$<CONFIG:${CONFIG}>:${VALUE}>")
  endforeach()
  set(CSCMAKE_MSVC_RUNTIME_LIBRARY_GENERATOR_EXPRESSION
      "${TEMP_STRING}"
      CACHE STRING "final value for MSVC_RUNTIME_LIBRARY for targets, with generator expressions" FORCE)

  # and set CMAKE_MSVC_RUNTIME_LIBRARY = CSCMAKE_MSVC_RUNTIME_LIBRARY_GENERATOR_EXPRESSION for generic targes (fallback)
  set(CMAKE_MSVC_RUNTIME_LIBRARY
      "${TEMP_STRING}"
      CACHE STRING "default value for MSVC_RUNTIME_LIBRARY for targets, with generator expressions" FORCE)
endfunction()

# Apply the configurations requested in cs_initialize_project: on multi-config generators reset
# CMAKE_CONFIGURATION_TYPES to them, on single-config generators fail if CMAKE_BUILD_TYPE is not one of them.
function(_cs_process_configurations)
  cs_get_build_configurations(CONFIGS_LIST)

  get_property(GENERATOR_IS_MULTI_CONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
  if(GENERATOR_IS_MULTI_CONFIG)
    set(CMAKE_CONFIGURATION_TYPES
        "${CONFIGS_LIST}"
        CACHE STRING "Reset the configurations to what we need" FORCE)
  else()
    if(NOT ${CMAKE_BUILD_TYPE} IN_LIST CONFIGS_LIST)
      message(
        FATAL_ERROR
          "[_cs_process_configurations] request to build with config ${CMAKE_BUILD_TYPE} which is not supported by this project"
      )
    endif()
  endif()
endfunction()

# Store CONFIGNAME as the configuration built with strict compilation flags (global property
# csCMakeConfigWithStrictFlags).
function(_cs_set_strict_build_configuration CONFIGNAME)
  set_property(GLOBAL PROPERTY csCMakeConfigWithStrictFlags ${CONFIGNAME})
endfunction()

# Return in CONFIGNAME the configuration built with strict compilation flags (STRICT_COMPILATION_ON_CONFIG of
# cs_initialize_project), empty if none.
function(cs_get_strict_build_configuration CONFIGNAME)
  get_property(VAL GLOBAL PROPERTY csCMakeConfigWithStrictFlags)
  set(${CONFIGNAME}
      ${VAL}
      PARENT_SCOPE)
endfunction()

# set a global property csCMakeConfigurationVariables highly inspired from
# https://stackoverflow.com/questions/75823363/how-can-i-copy-all-build-type-parameters-from-an-existing-build-configuration-ty/75828118#75828118
function(_cs_process_build_configurations_variables)
  execute_process(COMMAND ${CMAKE_COMMAND} --help-variable-list
                  OUTPUT_FILE "${CMAKE_CURRENT_BINARY_DIR}/cmake_var_full_list.txt")
  file(STRINGS "${CMAKE_CURRENT_BINARY_DIR}/cmake_var_full_list.txt" VAR_FULL_LIST)

  foreach(var ${VAR_FULL_LIST})
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
          list(APPEND CONFIG_VAR_LIST "${lang_var}")
        endforeach()
      else()
        list(APPEND CONFIG_VAR_LIST "${var}")
      endif()
    endif()
  endforeach()

  set_property(GLOBAL PROPERTY csCMakeConfigurationVariables ${CONFIG_VAR_LIST})
endfunction()

# Create the configuration config_to_in as a copy of config_from_in: copy every per-<CONFIG> CMake variable and the MSVC
# runtime library, and map imported targets of the new configuration onto BASE_CONFIG_AND_FALLBACK
# (CMAKE_MAP_IMPORTED_CONFIG_<CONFIG>).
function(_cs_copy_build_configuration config_from_in config_to_in BASE_CONFIG_AND_FALLBACK)
  _cs_get_per_config_variables(CONFIG_VAR_LIST)

  string(TOUPPER "${config_from_in}" config_from)
  string(TOUPPER "${config_to_in}" config_to)
  foreach(config_var ${CONFIG_VAR_LIST})
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
      "${BASE_CONFIG_AND_FALLBACK}"
      CACHE STRING "value for custom build CMAKE_MAP_IMPORTED_CONFIG_${config_to}" FORCE)
  cs_debug_message(
    "[_cs_copy_build_configuration] set CMAKE_MAP_IMPORTED_CONFIG_${config_to} = ${BASE_CONFIG_AND_FALLBACK}" True)

  # set the MSVC Runtime Library based on the config to copy
  set(CSCMAKE_MSVC_RUNTIME_LIBRARY_${config_to}
      "${CSCMAKE_MSVC_RUNTIME_LIBRARY_${config_from}}"
      CACHE STRING "The MSVC runtime library to use in ${config_to_in}, copied from ${config_from_in}" FORCE)

endfunction()

# Print (debug) the per-configuration variables of every configuration of the project, tagging each block with
# ADD_MESSAGE.
function(cs_print_all_configurations_variables ADD_MESSAGE)
  cs_get_build_configurations(CONFIG_VAR_LIST)
  cs_debug_message("[cs_print_all_configurations_variables] configs are ${CONFIG_VAR_LIST}")
  foreach(CONFIG ${CONFIG_VAR_LIST})
    cs_debug_message("[cs_print_all_configurations_variables] CONFIG ${CONFIG} ${ADD_MESSAGE}")
    cs_print_configuration_variables(${CONFIG} "  ")
    cs_debug_message("[cs_print_all_configurations_variables] -------")
  endforeach()
  cs_debug_message(
    "[cs_print_all_configurations_variables] CSCMAKE_MSVC_RUNTIME_LIBRARY_GENERATOR_EXPRESSION ${CSCMAKE_MSVC_RUNTIME_LIBRARY_GENERATOR_EXPRESSION}"
  )
  cs_debug_message("[cs_print_all_configurations_variables] end --------")

endfunction()

# Print (debug) the per-configuration CMake and csCMake variables of CONFIG_IN, each line prefixed with PRINT_PREFIX.
function(cs_print_configuration_variables CONFIG_IN PRINT_PREFIX)

  _cs_get_per_config_variables(CONFIG_VAR_LIST)
  string(TOUPPER "${CONFIG_IN}" CONFIG)

  foreach(VAR ${CONFIG_VAR_LIST})
    string(REPLACE "<CONFIG>" "${CONFIG}" VAR_OUT "${VAR}")
    cs_debug_message("${PRINT_PREFIX} ${VAR_OUT} = ${${VAR_OUT}}")
  endforeach()

  # extra, CS variables
  cs_debug_message("${PRINT_PREFIX} CSCMAKE_MSVC_RUNTIME_LIBRARY_${CONFIG} = ${CSCMAKE_MSVC_RUNTIME_LIBRARY_${CONFIG}}")
  cs_debug_message("${PRINT_PREFIX} CSCMAKE_${CONFIG}_POSTFIX = ${CSCMAKE_${CONFIG}_POSTFIX}")

endfunction()
