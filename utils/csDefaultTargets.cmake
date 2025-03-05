include_guard(GLOBAL)
include(utils/csDebugMessage)

# creates two targets that the user can use in target_link_libraries
# ${PROJECT_NAME}_csCMakeBaseInclude 
# - contains include directory of the main folder
# ${PROJECT_NAME}_csCMakeCompileOptionsDefault
# - contain common compilation flags, e.g. multithread compilation in windows
# - in particular, it contains the following specific targets
# -- {PROJECT_NAME}MSVCParallelCompile with parallel compilation options for MSCV
# best practice is to use ${PROJECT_NAME}_csCMakeCompileOptionsDefault as PRIVATE to avoid propagating compile options
# all targets are installed to 
function(_cs_add_default_targets)
  
  # create the base include
  _cs_target_base_project_include_dir() # _csCMakeBaseInclude

  # create MSVC parallel compilation flags
  _cs_target_msvc_parallel_compilation() # MSVCParallelCompile
  # TODO(sc) add a target that manages the version and others...
  
  # create a final target with name ${PROJECT_NAME}_csCMakeCompileOptionsDefault that includes the default ones. TARGET_NAME will contains the name
  _cs_target_create_default(_csCMakeCompileOptionsDefault INTERFACE TARGET_NAME)

  # add the selected targets
	cs_target_link_libraries(${TARGET_NAME}
    INTERFACE
    ${PROJECT_NAME}::${PROJECT_NAME}MSVCParallelCompile
  ) 


endfunction()

# add a target named <ProjectName>_csCMakeBaseInclude, alias <ProjectName>::<ProjectName>_csCMakeBaseInclude
# that allow to propagate include directories to the root of the project
function(_cs_target_base_project_include_dir)
  _cs_target_create_default(_csCMakeBaseInclude INTERFACE TARGET_NAME)

  # add include to root dir
	target_include_directories(${TARGET_NAME}
		INTERFACE
			$<INSTALL_INTERFACE:>
			$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
		INTERFACE
			$<INSTALL_INTERFACE:>
			$<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}>
	)
endfunction()

function(_cs_target_msvc_parallel_compilation)
  _cs_target_create_default(MSVCParallelCompile INTERFACE TARGET_NAME)

  # add /MP
  target_compile_options(${TARGET_NAME} INTERFACE "$<$<CXX_COMPILER_ID:MSVC>:/MP>")  
endfunction()

# create a empty target with coherent name, alias, export, etc...
function(_cs_target_create_default TARGET_SUB_NAME TARGET_TYPE TARGET_NAME_OUT)
	set(TARGET_NAME ${PROJECT_NAME}${TARGET_SUB_NAME})
	cs_add_library(${TARGET_NAME} ${TARGET_TYPE})
	cs_add_library(${PROJECT_NAME}::${TARGET_NAME} ALIAS ${TARGET_NAME})
  
	# add to its own export
	cs_install_target(${TARGET_NAME} ${PROJECT_NAME}_csCMakeCommon DEFAULT)

	cs_finalize_target(${TARGET_NAME})
  
  # return the target name
  set(${TARGET_NAME_OUT} ${TARGET_NAME} PARENT_SCOPE)
endfunction()