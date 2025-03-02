include_guard(GLOBAL)
include(utils/csDebugMessage)

function(_cs_add_default_targets)
  
  # TODO(sc) add options to select desired targets?
  _cs_target_base_project_include_dir() # BaseInclude
  _cs_target_msvc_parallel_compilation() # MSVCParallelCompile
  # TODO(sc) add a target that manages the version
  
  # create a final target that includes the default ones
  _cs_target_create_default(_csCMakeDefault INTERFACE TARGET_NAME)

  # add the selected targets
	cs_target_link_libraries(${TARGET_NAME}
    INTERFACE
    ${PROJECT_NAME}::${PROJECT_NAME}BaseInclude
    ${PROJECT_NAME}::${PROJECT_NAME}MSVCParallelCompile
  ) 

endfunction()

# add a target named <ProjectName>BaseInclude, alias <ProjectName>::<ProjectName>BaseInclude
# that allow to propagate include directories to the root of the project
function(_cs_target_base_project_include_dir)
  _cs_target_create_default(BaseInclude INTERFACE TARGET_NAME)

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
  
	# add to _csCMakeDefault own export
	cs_install_target(${TARGET_NAME} ${PROJECT_NAME}_csCMakeDefault DEFAULT)

	cs_finalize_target(${TARGET_NAME})
  
  # return the target name
  set(${TARGET_NAME_OUT} ${TARGET_NAME} PARENT_SCOPE)
endfunction()