include_guard(GLOBAL)

# get the stored list of available default build config
function(cs_get_specified_build_configurations CONFIGS_LIST)
	get_property(VAL GLOBAL PROPERTY csCMakeConfigurationTypes)
	set(${CONFIGS_LIST} ${VAL} PARENT_SCOPE)
endfunction()

function(cs_get_specified_build_configurations_default CONFIGS_LIST)
	get_property(VAL GLOBAL PROPERTY csCMakeConfigurationTypesDefault)
	set(${CONFIGS_LIST} ${VAL} PARENT_SCOPE)
endfunction()

function(cs_get_build_configurations_variables CONFIGS_LIST)
	get_property(VAL GLOBAL PROPERTY csCMakeConfigurationVariables)
	set(${CONFIGS_LIST} ${VAL} PARENT_SCOPE)
endfunction()

# add a default configuration
function(_cs_add_default_build_configurations CONFIG)
	cs_get_specified_build_configurations(CONFIGS_LIST)
    cs_get_specified_build_configurations_default(CONFIGS_LIST_DEFAULT)
	
	if(CMAKE_GENERATOR STREQUAL "Ninja" OR CMAKE_GENERATOR STREQUAL "Ninja Multi-Config")
		set(VALID_DEFAULT_CONFIGS "Debug;Release;RelWithDebInfo")
        # set cache variables with postfix for targets
        set(CSCMAKE_DEBUG_POSTFIX "d" CACHE STRING "value for suffix in Debug config" FORCE)
        set(CSCMAKE_RELEASE_POSTFIX "" CACHE STRING "value for suffix in Release config" FORCE)
        set(CSCMAKE_RELWITHDEBINFO_POSTFIX "rd" CACHE STRING "value for suffix in RelWithDebInfo config" FORCE)

    elseif(CMAKE_GENERATOR STREQUAL "Visual Studio 17 2022")
		set(VALID_DEFAULT_CONFIGS "Debug;Release;RelWithDebInfo;MinSizeRel")
        # set cache variables with postfix for targets
        set(CSCMAKE_DEBUG_POSTFIX "d" CACHE STRING "value for suffix in Debug config" FORCE)
        set(CSCMAKE_RELEASE_POSTFIX "" CACHE STRING "value for suffix in Release config" FORCE)
        set(CSCMAKE_RELWITHDEBINFO_POSTFIX "rd" CACHE STRING "value for suffix in RelWithDebInfo config" FORCE)
        set(CSCMAKE_MINSIZEREL_POSTFIX "mr" CACHE STRING "value for suffix in MinSizeRel config" FORCE)

    else()
		message(FATAL_ERROR "[cs_set_default_build_config] generator ${CMAKE_GENERATOR} not supported")
	endif()

	if(NOT ${CONFIG} IN_LIST VALID_DEFAULT_CONFIGS)
		message(FATAL_ERROR "[cs_set_default_build_config] called with invalid default config ${CONFIG}, choose one of ${VALID_DEFAULT_CONFIGS}")
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

# add a custom configuration, based on a default one
function(_cs_add_custom_build_configuration CONFIG BASE_CONFIG POSTFIX)
	cs_get_specified_build_configurations(CONFIGS_LIST)
    cs_get_specified_build_configurations_default(CONFIGS_LIST_DEFAULT)

	if(NOT ${CONFIG} IN_LIST CONFIGS_LIST)
		list(APPEND CONFIGS_LIST ${CONFIG})
	else()
		message(FATAL_ERROR "[_cs_add_custom_build_configuration] called with duplicated element ${CONFIG}")
	endif()

    if(NOT ${BASE_CONFIG} IN_LIST CONFIGS_LIST_DEFAULT)
        message(FATAL_ERROR "[_cs_add_custom_build_configuration] element ${CONFIG} base on ${BASE_CONFIG}, which is not in default configs ${CONFIGS_LIST_DEFAULT}")
    else()
        cs_copy_configuration_type(${BASE_CONFIG} ${CONFIG})
	endif()

    # set the postfix
    string(TOUPPER "${CONFIG}" CONFIG_UPPER)
    set(CSCMAKE_${CONFIG_UPPER}_POSTFIX "${POSTFIX}" CACHE STRING "value for suffix in ${CONFIG} config" FORCE)


	set_property(GLOBAL PROPERTY csCMakeConfigurationTypes ${CONFIGS_LIST})
endfunction()

# helper function to parse the cs_initialize_project arguments and add build types
# accepts extra arguments to specify the available build configurations:
# _cs_process_configurations( 
#   DEFAULT_CONFIG Debug 
#   DEFAULT_CONFIG Release
#   CUSTOM_CONFIG MyCustomConfig1 BASED_ON Debug POSTFIX "d"
#   CUSTOM_CONFIG MyCustomConfig2 BASED_ON Release POSTFIX ""
#  note, make sure to use POSTFIX "" if no postfix has to be used
# )
function(_cs_parse_additional_configurations)
	cs_debug_message("[_cs_parse_additional_configurations] ${ARGN}")

	set(OPTIONS "")
	set(ONEVALUE "")
	set(MULTIVALUE DEFAULT_CONFIG CUSTOM_CONFIG)
	cmake_parse_arguments(ARG "${OPTIONS}" "${ONEVALUE}" "${MULTIVALUE}" ${ARGN})

	if(ARG_UNPARSED_ARGUMENTS)
		message(FATAL_ERROR "[_cs_parse_additional_configurations] has unparsed arguments ${ARG_UNPARSED_ARGUMENTS}")
	endif()

    # add default configurations
	foreach(DEFAULT_CONFIG ${ARG_DEFAULT_CONFIG})
		cs_debug_message("adding default config ${DEFAULT_CONFIG}")
		_cs_add_default_build_configurations(${DEFAULT_CONFIG})
	endforeach()

    # add custom configs, based on default ones
    list(LENGTH ARG_CUSTOM_CONFIG ARG_CUSTOM_CONFIG_SIZE)
    math(EXPR MOD_SIZE "${ARG_CUSTOM_CONFIG_SIZE} % 5")
    if(NOT ${MOD_SIZE} EQUAL 0)
        message(FATAL_ERROR "[_cs_parse_additional_configurations] CUSTOM_CONFIG need to specify pairs of values as : CUSTOM_CONFIG MyCustomConfig1 BASED_ON Debug POSTFIX \"d\"")
    endif()
	
    set(I 0)
    while(ARG_CUSTOM_CONFIG_SIZE GREATER I)
        list(GET ARG_CUSTOM_CONFIG ${I} CUSTOM_CONFIG)
        math(EXPR I "${I} + 1")

        list(GET ARG_CUSTOM_CONFIG ${I} BASED_ON_KEYWORD)
        math(EXPR I "${I} + 1")
        
        list(GET ARG_CUSTOM_CONFIG ${I} BASE_CONFIG)
        math(EXPR I "${I} + 1")
        
        list(GET ARG_CUSTOM_CONFIG ${I} POSTFIX_KEYWORD)
        math(EXPR I "${I} + 1")

        list(GET ARG_CUSTOM_CONFIG ${I} POSTFIX_VALUE)
        math(EXPR I "${I} + 1")

        if(NOT ${BASED_ON_KEYWORD} STREQUAL "BASED_ON")
            message(FATAL_ERROR "[_cs_parse_additional_configurations] CUSTOM_CONFIG need to specify pairs of values as : CUSTOM_CONFIG MyCustomConfig1 BASED_ON Debug POSTFIX \"d\". Expected BASED_ON found ${BASED_ON_KEYWORD}")
        endif()
        if(NOT ${POSTFIX_KEYWORD} STREQUAL "POSTFIX")
            message(FATAL_ERROR "[_cs_parse_additional_configurations] CUSTOM_CONFIG need to specify pairs of values as : CUSTOM_CONFIG MyCustomConfig1 BASED_ON Debug POSTFIX \"d\". Expected POSTFIX found ${POSTFIX_KEYWORD}")
        endif()

		cs_debug_message("[_cs_parse_additional_configurations] adding custom config ${CUSTOM_CONFIG} ${BASE_CONFIG}")
		_cs_add_custom_build_configuration(${CUSTOM_CONFIG} ${BASE_CONFIG} ${POSTFIX_VALUE})
	endwhile()
endfunction()

function(_cs_process_configurations)
	cs_get_specified_build_configurations(CONFIGS_LIST)

	get_property(GENERATOR_IS_MULTI_CONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
	if(GENERATOR_IS_MULTI_CONFIG)
		set(CMAKE_CONFIGURATION_TYPES "${CONFIGS_LIST}" CACHE STRING "Reset the configurations to what we need" FORCE)
	else()
		if(NOT ${CMAKE_BUILD_TYPE} IN_LIST CONFIGS_LIST)
			message(FATAL_ERROR "[_cs_process_configurations] request to build with config ${CMAKE_BUILD_TYPE} which is not supported by this project")
		endif()
	endif()
endfunction(_cs)

# set a global property csCMakeConfigurationVariables
# highly inspired from https://stackoverflow.com/questions/75823363/how-can-i-copy-all-build-type-parameters-from-an-existing-build-configuration-ty/75828118#75828118
function(_cs_process_build_configurations_variables)
    execute_process(
        COMMAND ${CMAKE_COMMAND} --help-variable-list
        OUTPUT_FILE "${CMAKE_CURRENT_BINARY_DIR}/cmake_var_full_list.txt"
    )
    file(STRINGS "${CMAKE_CURRENT_BINARY_DIR}/cmake_var_full_list.txt" VAR_FULL_LIST)
    
    foreach(var ${VAR_FULL_LIST})
        if("${var}" MATCHES "<CONFIG>")
            if("${var}" MATCHES "<LANG>")
                foreach(lang C CXX CSharp CUDA OBJC OBJCXX Fortran HIP ISPC Swift ASM ASM_NASM ASM_MARMASM ASM_MASM ASM-ATT)
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

function(cs_copy_configuration_type config_from_in config_to_in)
  cs_get_build_configurations_variables(CONFIG_VAR_LIST)

  string(TOUPPER "${config_from_in}" config_from)
  string(TOUPPER "${config_to_in}" config_to)
  foreach(config_var ${CONFIG_VAR_LIST})
    string(REPLACE "<CONFIG>" "${config_from}" config_var_from "${config_var}")
    string(REPLACE "<CONFIG>" "${config_to}"   config_var_to   "${config_var}")

    set("${config_var_to}" "${${config_var_from}}" CACHE STRING "value for custom build ${config_to}" FORCE)
    mark_as_advanced("${config_var_to}")

    cs_debug_message("[cs_copy_configuration_type] ${config_var_to} = ${${config_var_from}}")
  endforeach()

  #TODO(sc) consider also DEBUG_CONFIGURATIONS global property 
  set(CMAKE_MAP_IMPORTED_CONFIG_${config_to} "${config_from_in}")
  cs_debug_message("[cs_copy_configuration_type] set CMAKE_MAP_IMPORTED_CONFIG_${config_to} = ${config_from_in}")
  endfunction()