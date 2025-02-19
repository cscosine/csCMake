include_guard(GLOBAL)
include(utils/csFindPackage)
include(utils/csListUtils)

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

# create a global variable csExportedList collecting all the different EXPORT_NAME used
# create a global variable csExported<EXPORT_NAME>FindPackages containing the list of find_package(ARGS...) that will be added to the installed configuration file
# if DEFAULT is passed as additional arguments, the EXPORT_NAME will be added to the list csExportedListDefault global variable
function(cs_install_target TARGET_NAME EXPORT_NAME)
  cs_debug_message("[cs_install_target] target ${TARGET_NAME} export to ${EXPORT_NAME}")

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
	foreach(FILE ${FILES_TO_INSTALL})
    set(SOURCE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/${FILE})
    set(DEST_PATH ${CMAKE_INSTALL_INCLUDEDIR}/${DESTINATION_FOLDER}/)
		install(FILES ${SOURCE_PATH} DESTINATION ${DEST_PATH})
    cs_debug_message("-- [cs_install_target] install ${SOURCE_PATH} to ${DEST_PATH}")
	endforeach()

	# install effectively the target
	install(TARGETS ${TARGET_NAME}
		EXPORT ${EXPORT_NAME}-targets
		RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
		LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
		ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
		INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
	)

	# and install the pdb file for debugging if exists
  get_target_property(TARGET_TYPE ${TARGET_NAME} TYPE)
  if(${TARGET_TYPE} STREQUAL "SHARED_LIBRARY" OR ${TARGET_TYPE} STREQUAL "EXECUTABLE")
    install(FILES $<TARGET_PDB_FILE:${TARGET_NAME}> DESTINATION bin OPTIONAL)	
  endif()

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



function(_cs_finalize_install EXPORT_NAMESPACE)
  # directory to install cmake files
  set(INSTALL_CONFIGDIR ${CMAKE_INSTALL_LIBDIR}/cmake/${EXPORT_NAMESPACE})

  # get export list
  cs_get_exported_list(EXPORTS)
  # and install cmake files of it
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
    cs_get_exported_find_packages(${EXPORT} VALUES)
    cs_debug_message("[cs_print_exported_list_details] export ${EXPORT} has the following find_packages: ${VALUES}")
  endforeach()

  cs_get_exported_list(EXPORTS_DEFAULT)
  cs_debug_message("[cs_print_exported_list_details] default exported targets  ${EXPORTS_DEFAULT}")
endfunction()