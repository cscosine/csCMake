cmake_minimum_required(VERSION 3.31.5)
include_guard(GLOBAL)

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

# store in a global variable the directory of csCMake, need to be invoked right after
function(cs_set_base_path PATH)
	get_property(VAL GLOBAL PROPERTY csCMakeBasePath)
	if(VAL)
		if(NOT VAL STREQUAL ${PATH})
			message(FATAL_ERROR "[cs_set_base_path] csCMake has been included multiple times with different base paths. Check your configuration.")
		endif()
	endif()
	set_property(GLOBAL PROPERTY csCMakeBasePath ${PATH})
endfunction()
cs_set_base_path(${CMAKE_CURRENT_LIST_DIR})

# get the stored base path
function(cs_get_base_path PATH)
	get_property(VAL GLOBAL PROPERTY csCMakeBasePath)
	set(${PATH} ${VAL} PARENT_SCOPE)
endfunction()

# accepts extra arguments to specify the available build configurations:
# cs_initialize_project(MyProject
#   DEFAULT_CONFIG Debug
#   DEFAULT_CONFIG Release
#   DEFAULT_CONFIG_MAPPED RelWithDebInfo MAPPED_TO "RelWithDebInfo,Release,"
#   CUSTOM_CONFIG MyCustomConfig1 BASED_ON Debug POSTFIX "d"
#   CUSTOM_CONFIG MyCustomConfig2 BASED_ON Release POSTFIX ""
# )
#  note, make sure to use POSTFIX "" if no postfix
macro(cs_initialize_project PROJECT_NAME)
	cs_debug_message("cs_initialize_project ${PROJECT_NAME}")
	# normalize paths
	_cs_path_list_normalize(CS_CMAKE_PREFIX_PATH_HEAD)
	_cs_path_list_normalize(CMAKE_PREFIX_PATH)
	_cs_path_list_normalize(CS_CMAKE_PREFIX_PATH_TAIL)

	_cs_path_list_normalize(CS_CMAKE_MODULE_PATH_HEAD)
	_cs_path_list_normalize(CMAKE_MODULE_PATH)
	_cs_path_list_normalize(CS_CMAKE_MODULE_PATH_TAIL)

	_cs_path_list_normalize(CMAKE_INSTALL_PREFIX)

	# define a single output folder for binaries (dll and exe in win, .so and executables in linux)
	# note: for some reason, this does not work / does not get propagated to custom config,
	# therefore, _cs_parse_additional_configurations will set CMAKE_RUNTIME_OUTPUT_DIRECTORY_${CONFIG_UCASE} for each custom config
	# TODO(sc) try to understand better this behavior, at the moment this is a workaround
	get_property(GENERATOR_IS_MULTI_CONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
	if(GENERATOR_IS_MULTI_CONFIG)
		set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin/$<CONFIG>" CACHE STRING "RUNTIME OUTPUT DIRECTORY for targets, with generator expressions" FORCE)
		set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib/$<CONFIG>" CACHE STRING "LIBRARY OUTPUT DIRECTORY for targets, with generator expressions" FORCE)
		set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib/$<CONFIG>" CACHE STRING "ARCHIVE OUTPUT DIRECTORY for targets, with generator expressions" FORCE)
	else()
		set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin" CACHE STRING "RUNTIME OUTPUT DIRECTORY for targets, with generator expressions" FORCE)
		set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib" CACHE STRING "LIBRARY OUTPUT DIRECTORY for targets, with generator expressions" FORCE)
		set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib" CACHE STRING "ARCHIVE OUTPUT DIRECTORY for targets, with generator expressions" FORCE)
	endif()

	# initialize the default configuration list variables
	_cs_process_build_configurations_variables()
	cs_get_build_configurations_variables(TEMP_VAR_LIST)
	cs_debug_message("[cs_initialize_project] _cs_process_build_configurations_variables ${TEMP_VAR_LIST}")

	# parse the additional configurations
	_cs_parse_additional_configurations(${ARGN})

	# check validity of requested config (if single generator, or set the build types to the requested configs)
	_cs_process_configurations()

	# print information on the csCMake configuration
	cs_print_state_info("initial state")

	# join CMAKE_PREFIX_PATH
	set(CMAKE_PREFIX_PATH "${CS_CMAKE_PREFIX_PATH_HEAD};${CMAKE_PREFIX_PATH};${CS_CMAKE_PREFIX_PATH_TAIL}")
	set(CMAKE_MODULE_PATH "${CS_CMAKE_MODULE_PATH_HEAD};${CMAKE_MODULE_PATH};${CS_CMAKE_MODULE_PATH_TAIL}")

	# enable cmake testing
	enable_testing()

	# enable generation of compile commands on ninja generators
	if(CMAKE_GENERATOR STREQUAL "Ninja" OR CMAKE_GENERATOR STREQUAL "Ninja Multi-Config")
		message(STATUS "[csCMake] set CMAKE_EXPORT_COMPILE_COMMANDS ON")
		set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
	endif()

	_cs_add_default_targets()
endmacro()

# EXPORT_NAMESPACE is the namespace added to exported targets, e.g. Eigen::Eigen3 Eigen is the namespace
function (cs_finalize_project EXPORT_NAMESPACE)

	# print target and export info
	cs_print_all_target()
	cs_print_exported_list_details()

	cs_print_state_info("final state")


	set(TARGETS "")
	cs_get_all_targets(TARGETS)

	# finalize path recursion for dll dependencies
	_cs_recursive_analyze_targets_finalize("${TARGETS}")

	# set on visual studio env variable the path required
	_cs_set_vs_debugger_env_variable("${TARGETS}")

	# finalize the installation: add the cmake/ dir with all cmake files required to find the exported targets
	_cs_finalize_install(${EXPORT_NAMESPACE})

endfunction()
