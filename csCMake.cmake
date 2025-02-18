cmake_minimum_required(VERSION 3.31.4)
include_guard(GLOBAL)

include(utils/csPrintInitialState)
include(utils/csPathUtils)

include(utils/csAddLibraryExecutable)
include(utils/csFindPackage)
include(utils/csTargetSources)
include(utils/csTargetLinkLibraries)
include(utils/csTargetDependencies)
include(utils/csMSVCUtils)

# normalize paths
csPathListNormalize(CMAKE_PREFIX_PATH)
csPathListNormalize(CMAKE_MODULE_PATH)
csPathListNormalize(CMAKE_INSTALL_PREFIX)

# print information on the csCMake configuration
csPrintInitialState()

# enable cmake testing
enable_testing()

# add_library(cs::MSVCCommon INTERFACE)

## TODO: if exe or shared, 
# set target property RUNTIME_OUTPUT_DIRECTORY to ${CMAKE_BINARY_DIR}/bin)

#	# silent generally an annoying warning from visual studio about dll export/import
	#add_compile_options(/wd4251)
	
	# add multicore compilation in visual studio
	#SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /MP")
	#SET(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /MP")
  

function (cs_finalize_project)
	cs_print_all_target() 
	
	set(TARGETS "")
	cs_get_all_targets(TARGETS)
  
	# finalize path recursion for dll dependencies
	_cs_recursive_analyze_targets_finalize("${TARGETS}")

	# set on visual studio env variable the path required
	_cs_set_vs_debugger_env_variable("${TARGETS}")

endfunction()