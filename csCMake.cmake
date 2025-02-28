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

	
	# print information on the csCMake configuration
	cs_print_initial_state()

	# join CMAKE_PREFIX_PATH
	set(CMAKE_PREFIX_PATH "${CS_CMAKE_PREFIX_PATH_HEAD};${CMAKE_PREFIX_PATH};${CS_CMAKE_PREFIX_PATH_TAIL}")
	set(CMAKE_MODULE_PATH "${CS_CMAKE_MODULE_PATH_HEAD};${CMAKE_MODULE_PATH};${CS_CMAKE_MODULE_PATH_TAIL}")

	# enable cmake testing
	enable_testing()

	if(MSVC)
		# define a single output folder for binaries (dll and exe)
		set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
	endif()

	# add_library(cs::MSVCCommon INTERFACE) to add common compilation flags etc
	# add multicore compilation in visual studio
	#SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /MP")
	#SET(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /MP")

	cs_add_target_base_project_include_dir()
endmacro()

# add a target named <ProjectName>BaseInclude, alias <ProjectName>::<ProjectName>BaseInclude
# that allow to propagate include directories to the root of the project
function(cs_add_target_base_project_include_dir)
	set(TARGET_NAME ${PROJECT_NAME}BaseInclude)
	cs_add_library(${TARGET_NAME} INTERFACE)
	cs_add_library(${PROJECT_NAME}::${TARGET_NAME} ALIAS ${TARGET_NAME})

	target_include_directories(${TARGET_NAME}
		INTERFACE
			$<INSTALL_INTERFACE:>
			$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
		INTERFACE
			$<INSTALL_INTERFACE:>
			$<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}>
	)

	cs_target_link_libraries(${TARGET_NAME}) # no target libraries

	# add to its own export
	cs_install_target(${TARGET_NAME} ${PROJECT_NAME}BaseInclude DEFAULT)

	cs_finalize_target(${TARGET_NAME})
endfunction()

# TODO(sc) add a target that manages the version

# EXPORT_NAMESPACE is the namespace added to exported targets, e.g. Eigen::Eigen3 Eigen is the namespace
function (cs_finalize_project EXPORT_NAMESPACE)
	# print info
	cs_print_all_target() 
	cs_print_exported_list_details()
	
	set(TARGETS "")
	cs_get_all_targets(TARGETS)
  
	# finalize path recursion for dll dependencies
	_cs_recursive_analyze_targets_finalize("${TARGETS}")

	# set on visual studio env variable the path required
	_cs_set_vs_debugger_env_variable("${TARGETS}")

	# finalize the installation: add the cmake/ dir with all cmake files required to find the exported targets
	_cs_finalize_install(${EXPORT_NAMESPACE})

endfunction()