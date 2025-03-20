include_guard(GLOBAL)
include(utils/csFindPackage)
include(utils/csListUtils)
include(utils/csPathUtils)
include(utils/csTargetDependencies)

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

function(cs_get_install_folder_suffix INSTALL_FOLDER_EXPRESSION)
  get_property(GENERATOR_IS_MULTI_CONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
  if(GENERATOR_IS_MULTI_CONFIG)
    set(FOLDER "${CMAKE_INSTALL_INCLUDEDIR}/$<CONFIG>")
    set(${INSTALL_FOLDER_EXPRESSION} "${FOLDER}" PARENT_SCOPE)
  else()
    set(FOLDER "${CMAKE_INSTALL_INCLUDEDIR}")
    set(${INSTALL_FOLDER_EXPRESSION} "${FOLDER}" PARENT_SCOPE)
  endif()
endfunction()

# create a global variable csExportedList collecting all the different EXPORT_NAME used
# create a global variable csExported<EXPORT_NAME>FindPackages containing the list of find_package(ARGS...) that will be added to the installed configuration file
# if DEFAULT is passed as additional arguments, the EXPORT_NAME will be added to the list csExportedListDefault global variable
# add a target property csTargetExportedTo with the name of the export
function(cs_install_target TARGET_NAME EXPORT_NAME)
  cs_debug_message("[cs_install_target] target ${TARGET_NAME} export to ${EXPORT_NAME}")
  
  # set the csTargetExportedTo property
  set_target_properties(${TARGET_NAME} PROPERTIES csTargetExportedTo ${EXPORT_NAME})


  # get the relative folder from the target folder to the base of the project  
  file(RELATIVE_PATH DESTINATION_FOLDER ${CMAKE_SOURCE_DIR} ${CMAKE_CURRENT_SOURCE_DIR})

  # add the EXPORT_NAME to the list of exports
  _cs_add_to_global_property_unique_value(csExportedList ${EXPORT_NAME})

  # add the target to default list
  if(${ARGC} EQUAL 2)
    #nothing to do, do not
  elseif(${ARGC} EQUAL 3)
    if(${ARGV2} STREQUAL "DEFAULT")
      _cs_add_to_global_property_unique_value(csExportedListDefault ${EXPORT_NAME})
    else()
      message(FATAL_ERROR "cs_install_target argument 3 should be DEFAULT or should be empty")
    endif()
  else()
    message(FATAL_ERROR "cs_install_target expects 2 or 3 arguments")
  endif()

  # retrieve the source files that have to be installed
  cs_get_target_sources_to_install(${TARGET_NAME} FILES_TO_INSTALL)
  cs_get_install_folder_suffix(INSTALL_FOLDER_EXPRESSION)
	foreach(FILE ${FILES_TO_INSTALL})
    set(SOURCE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/${FILE})
    set(DEST_PATH ${INSTALL_FOLDER_EXPRESSION}/${DESTINATION_FOLDER}/)
		install(FILES ${SOURCE_PATH} DESTINATION ${DEST_PATH})
    cs_debug_message("-- [cs_install_target] install ${SOURCE_PATH} to ${DEST_PATH}" true)
	endforeach()

  # retrieve the source files that have to be installed from a absolute path
  cs_get_target_sources_to_install_absolute_path(${TARGET_NAME} FILES_TO_INSTALL)
  cs_get_install_folder_suffix(INSTALL_FOLDER_EXPRESSION)
	foreach(FILE ${FILES_TO_INSTALL})
    set(SOURCE_PATH ${FILE})
    set(DEST_PATH ${INSTALL_FOLDER_EXPRESSION}/${DESTINATION_FOLDER}/)
		install(FILES ${SOURCE_PATH} DESTINATION ${DEST_PATH})
    cs_debug_message("-- [cs_install_target] install ${SOURCE_PATH} to ${DEST_PATH}" true)
	endforeach()

	# install effectively the target
	install(TARGETS ${TARGET_NAME}
		EXPORT ${EXPORT_NAME}-targets
		RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
		LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
		ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
	)

	# and install the pdb file for debugging if exists
  if(WIN32)
    get_target_property(TARGET_TYPE ${TARGET_NAME} TYPE)
    if((${TARGET_TYPE} STREQUAL "SHARED_LIBRARY" OR ${TARGET_TYPE} STREQUAL "EXECUTABLE"))
      install(FILES $<TARGET_PDB_FILE:${TARGET_NAME}> DESTINATION bin OPTIONAL)	
    endif()
  endif()

  # add the target to the list of target of this export
  _cs_add_to_global_property_unique_value(csExported${EXPORT_NAME}Targets ${TARGET_NAME})
  
	# get all the find_packages propagated for this target
	cs_get_target_find_packages(${TARGET_NAME} FIND_PACKAGES_LIST)
	foreach(FIND_PACKAGE ${FIND_PACKAGES_LIST})
		_cs_add_to_global_property_unique_value(csExported${EXPORT_NAME}FindPackages ${FIND_PACKAGE})
	endforeach()
	
endfunction()

# return the csExportedList global property 
function(cs_get_exported_list OUTPUT_VARIABLE_NAME)
  get_property(LIST_VALUES GLOBAL PROPERTY csExportedList)
  if(LIST_VALUES)
    # if exists
    set(${OUTPUT_VARIABLE_NAME} ${LIST_VALUES} PARENT_SCOPE)
  else()
    # otherwise set to empty list
    set(${OUTPUT_VARIABLE_NAME} "" PARENT_SCOPE)
  endif()
endfunction()

# return the csExportedListDefault global property 
function(cs_get_exported_list_default OUTPUT_VARIABLE_NAME)
  get_property(LIST_VALUES GLOBAL PROPERTY csExportedListDefault)
  if(LIST_VALUES)
    # if exists
    set(${OUTPUT_VARIABLE_NAME} ${LIST_VALUES} PARENT_SCOPE)
  else()
    # otherwise set to empty list
    set(${OUTPUT_VARIABLE_NAME} "" PARENT_SCOPE)
  endif()
endfunction()

# return the csTargetExportedTo target property
function(cs_get_target_exported_to TARGET_NAME OUTPUT_VARIABLE_NAME)
  get_target_property(VALUE ${TARGET_NAME} csTargetExportedTo)
  set(${OUTPUT_VARIABLE_NAME} ${VALUE} PARENT_SCOPE)
endfunction()

function(_cs_populate_export_dependent_exports EXPORT_NAME DEPENDENT_EXPORTS_OUT)
  cs_get_exported_targets(${EXPORT_NAME} TARGETS_LIST)
  cs_debug_message("[_cs_populate_export_dependent_exports] EXPORT ${EXPORT_NAME} has the following targets: ${TARGETS_LIST}")
  
  set(DEPENDENT_EXPORTS "") # reset to be sure
  foreach(TARGET_NAME ${TARGETS_LIST})
    cs_get_target_dependencies(${TARGET_NAME} TARGET_DEPS)
    cs_debug_message("[_cs_populate_export_dependent_exports] -- target ${TARGET_NAME} depends on internal targets ${TARGET_DEPS}")
    
    foreach(TARGET_DEP_NAME ${TARGET_DEPS})
      cs_get_target_exported_to(${TARGET_DEP_NAME} EXPORT_DEP_NAME)
      cs_debug_message("[_cs_populate_export_dependent_exports] ---- subtarget ${TARGET_DEP_NAME} is exported to ${EXPORT_DEP_NAME}")
      if(NOT ${EXPORT_DEP_NAME} STREQUAL ${EXPORT_NAME})
        _cs_list_add_unique_value(DEPENDENT_EXPORTS ${EXPORT_DEP_NAME})
        cs_debug_message("[_cs_populate_export_dependent_exports] ---- cumulated ${DEPENDENT_EXPORTS}")
      else()
        cs_debug_message("[_cs_populate_export_dependent_exports] ---- subtarget is in my same export set")
      endif()
      
    endforeach()
    
  endforeach()

  cs_debug_message("[_cs_populate_export_dependent_exports] final result, EXPORT ${EXPORT_NAME} depends on EXPORTS ${DEPENDENT_EXPORTS}")
  set(${DEPENDENT_EXPORTS_OUT} "${DEPENDENT_EXPORTS}" PARENT_SCOPE)
endfunction()


function(_cs_finalize_install EXPORT_NAMESPACE)
  # directory to install cmake files
  set(INSTALL_CONFIGDIR ${CMAKE_INSTALL_LIBDIR}/cmake/${EXPORT_NAMESPACE})

  # get export list
  cs_get_exported_list(EXPORTS)
  # and install cmake files of them
	foreach(NAME ${EXPORTS})
		install(EXPORT ${NAME}-targets
		FILE
			${NAME}Targets.cmake
		NAMESPACE
			${EXPORT_NAMESPACE}::
		DESTINATION
			${INSTALL_CONFIGDIR}/targets
		)
	endforeach()

  # per each export, prepare a list of the export it depends 
	foreach(EXPORT_NAME ${EXPORTS})
    _cs_populate_export_dependent_exports(${EXPORT_NAME} ${EXPORT_NAME}_DEPENDENT_EXPORTS)
    cs_debug_message("[_cs_finalize_install] -- EXPORT ${EXPORT_NAME} depends on other exports ${${EXPORT_NAME}_DEPENDENT_EXPORTS}")
  endforeach()
  
  # write all ${${EXPORT_NAME}_DEPENDENT_EXPORTS} in the cmake config
  set(INJECTED_EXPORT_DEPENDENCIES "")
  foreach(EXPORT_NAME ${EXPORTS})
    set(INJECTED_EXPORT_DEPENDENCIES "${INJECTED_EXPORT_DEPENDENCIES}set(${EXPORT_NAME}_DEPENDENT_EXPORTS \"${${EXPORT_NAME}_DEPENDENT_EXPORTS}\")\n")
  endforeach()
  
  # TODO(sc): implement a mechanism to auto import dependencies (unique)
  
  
  # generate the main cmake for finding this package
  set(INJECTED_FIND_PACKAGES_CODE "")
	foreach(EXPORT_NAME ${EXPORTS})
    cs_get_exported_find_packages(${EXPORT_NAME} FIND_PACKAGES_LIST)

    if(FIND_PACKAGES_LIST)
      set(INJECTED_FIND_PACKAGES_CODE  "${INJECTED_FIND_PACKAGES_CODE}  if(NOT ${EXPORT_NAME}_FIND_DONE)\n" )
      set(INJECTED_FIND_PACKAGES_CODE  "${INJECTED_FIND_PACKAGES_CODE}    if(\"${EXPORT_NAME}\" STREQUAL \"\${COMPONENT_NAME}\")\n")

      foreach(FIND_ARGS ${FIND_PACKAGES_LIST})
      set(INJECTED_FIND_PACKAGES_CODE "${INJECTED_FIND_PACKAGES_CODE}      find_dependency(${FIND_ARGS})\n")
      set(INJECTED_FIND_PACKAGES_CODE "${INJECTED_FIND_PACKAGES_CODE}      SET(${EXPORT_NAME}_FIND_DONE True)\n")
      endforeach()

      set(INJECTED_FIND_PACKAGES_CODE  "${INJECTED_FIND_PACKAGES_CODE}    endif()\n")
      set(INJECTED_FIND_PACKAGES_CODE  "${INJECTED_FIND_PACKAGES_CODE}  else()\n")
        set(INJECTED_FIND_PACKAGES_CODE "${INJECTED_FIND_PACKAGES_CODE}   MESSAGE(STATUS \"[${EXPORT_NAMESPACE}Config] find_dependency for ${EXPORT_NAME} already satisfied\")\n")
      set(INJECTED_FIND_PACKAGES_CODE  "${INJECTED_FIND_PACKAGES_CODE}  endif()\n")
    endif()
	endforeach()
  
  if(INJECTED_FIND_PACKAGES_CODE)
    set(INJECTED_FIND_PACKAGES_CODE "  # -- find packages section --\n${INJECTED_FIND_PACKAGES_CODE}  # -- end find packages section --")
  endif()

  # get list of components when find_package without arguments is used
  cs_get_exported_list(COMPONENTS_LIST)
  # get list of default components when find_package without arguments is used
  cs_get_exported_list_default(DEFAULT_COMPONENTS_LIST)

  # retrieve output folder for generated files
  cs_get_generate_folder_common(OUTPUT_FOLDER)

	# Write the Config.cmake file
  _cs_configure_config_cmake(${OUTPUT_FOLDER} ${EXPORT_NAMESPACE} "${COMPONENTS_LIST}" "${DEFAULT_COMPONENTS_LIST}" "${INJECTED_FIND_PACKAGES_CODE}" "${INJECTED_EXPORT_DEPENDENCIES}")


	#Write a ConfigVersion.cmake file
	write_basic_package_version_file(
		${OUTPUT_FOLDER}/${EXPORT_NAMESPACE}ConfigVersion.cmake
		VERSION ${PROJECT_VERSION}
		COMPATIBILITY AnyNewerVersion
	)

	#Install the Config and configVersion files
	install(FILES
		${OUTPUT_FOLDER}/${EXPORT_NAMESPACE}Config.cmake
		${OUTPUT_FOLDER}/${EXPORT_NAMESPACE}ConfigVersion.cmake
		DESTINATION ${INSTALL_CONFIGDIR}
	)

endfunction()

function(_cs_configure_config_cmake OUTPUT_FOLDER EXPORT_NAMESPACE COMPONENTS_LIST DEFAULT_COMPONENTS_LIST INJECTED_FIND_PACKAGES_CODE INJECTED_EXPORT_DEPENDENCIES)
  # note, the file csTemplateConfig.cmake.in uses the @variable@ substituion with the values prepared in this function of
  # - EXPORT_NAMESPACE
  # - COMPONENTS_LIST
  # - DEFAULT_COMPONENTS_LIST
  # - INJECTED_FIND_PACKAGES_CODE
  # - INJECTED_EXPORT_DEPENDENCIES
  # do not refactor / change name of those variables

  cs_get_base_path(_BASE_PATH)
	configure_package_config_file(
    "${_BASE_PATH}/templates/csTemplateConfig.cmake.in"
	  "${OUTPUT_FOLDER}/${EXPORT_NAMESPACE}Config.cmake"
	  INSTALL_DESTINATION ${INSTALL_CONFIGDIR}
	)

endfunction()

# return the csExported${EXPORT_NAME}Targets global property 
function(cs_get_exported_targets EXPORT_NAME OUTPUT_VARIABLE_NAME)
  get_property(LIST_VALUES GLOBAL PROPERTY csExported${EXPORT_NAME}Targets)
  if(LIST_VALUES)
    # if exists
    set(${OUTPUT_VARIABLE_NAME} ${LIST_VALUES} PARENT_SCOPE)
  else()
    # otherwise set to empty list
    set(${OUTPUT_VARIABLE_NAME} "" PARENT_SCOPE)
  endif()
endfunction()

# return the csExported${EXPORT_NAME}FindPackages global property 
function(cs_get_exported_find_packages EXPORT_NAME OUTPUT_VARIABLE_NAME)
  get_property(LIST_VALUES GLOBAL PROPERTY csExported${EXPORT_NAME}FindPackages)
  if(LIST_VALUES)
    # if exists
    set(${OUTPUT_VARIABLE_NAME} ${LIST_VALUES} PARENT_SCOPE)
  else()
    # otherwise set to empty list
    set(${OUTPUT_VARIABLE_NAME} "" PARENT_SCOPE)
  endif()
endfunction()

# debug, print exported list and information cumulated per each export item
function(cs_print_exported_list_details)
  cs_get_exported_list(EXPORTS)
  foreach(EXPORT ${EXPORTS})
    cs_get_exported_targets(${EXPORT} TARGETS_VALUES)
    cs_get_exported_find_packages(${EXPORT} FIND_PACKAGES_VALUES)
    cs_debug_message("[cs_print_exported_list_details] export ${EXPORT} contains the following targets: ${TARGETS_VALUES} and has the following find_packages: ${FIND_PACKAGES_VALUES}")
  endforeach()

  cs_get_exported_list(EXPORTS_DEFAULT)
  cs_debug_message("[cs_print_exported_list_details] default exported targets  ${EXPORTS_DEFAULT}")
endfunction()