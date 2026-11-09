include_guard(GLOBAL)
# cmake-lint: disable=R0913
# (only _cs_configure_config_cmake has more than 5 arguments: one per @VAR@ placeholder of the template)
include(utils/csFindPackage)
include(utils/csListUtils)
include(utils/csPathUtils)
include(utils/csTargetDependencies)

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

# Return in INSTALL_FOLDER_EXPRESSION the install folder for headers: CMAKE_INSTALL_INCLUDEDIR, plus a $<CONFIG> sub-
# folder when the project has more than one configuration.
function(cs_get_install_folder_suffix INSTALL_FOLDER_EXPRESSION)
  cs_get_specified_build_configurations(CONFIGS_LIST)
  list(LENGTH CONFIGS_LIST N)
  if(N GREATER 1)
    # includes are installed per configuration, independently if we are with a multi generator or a single one
    set(FOLDER "${CMAKE_INSTALL_INCLUDEDIR}/$<CONFIG>")
    set(${INSTALL_FOLDER_EXPRESSION}
        "${FOLDER}"
        PARENT_SCOPE)
  else()
    set(FOLDER "${CMAKE_INSTALL_INCLUDEDIR}")
    set(${INSTALL_FOLDER_EXPRESSION}
        "${FOLDER}"
        PARENT_SCOPE)
  endif()
endfunction()

# create a global variable csExportedList collecting all the different EXPORT_NAME used create a global variable
# csExported<EXPORT_NAME>FindPackages containing the list of find_package(ARGS...) that will be added to the installed
# configuration file if DEFAULT is passed as additional arguments, the EXPORT_NAME will be added to the list
# csExportedListDefault global variable add a target property csTargetExportedTo with the name of the export
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
    # nothing to do, do not
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

    # preserve subfolders structure
    get_filename_component(FILE_DIR "${FILE}" DIRECTORY)
    if(FILE_DIR)
      set(FILE_DIR "${FILE_DIR}/")
    endif()
    set(DEST_PATH ${INSTALL_FOLDER_EXPRESSION}/${DESTINATION_FOLDER}/${FILE_DIR})

    install(FILES ${SOURCE_PATH} DESTINATION ${DEST_PATH})
    cs_debug_message("-- [cs_install_target] install ${SOURCE_PATH} to ${DEST_PATH}" true)
  endforeach()

  # retrieve the source files that have to be installed from a absolute path
  cs_get_target_sources_to_install_absolute_path(${TARGET_NAME} FILES_TO_INSTALL)
  foreach(FILE ${FILES_TO_INSTALL})
    set(SOURCE_PATH ${FILE})
    set(DEST_PATH ${INSTALL_FOLDER_EXPRESSION}/${DESTINATION_FOLDER}/)
    install(FILES ${SOURCE_PATH} DESTINATION ${DEST_PATH})
    cs_debug_message("-- [cs_install_target] install ${SOURCE_PATH} to ${DEST_PATH}" true)
  endforeach()

  # install effectively the target
  install(
    TARGETS ${TARGET_NAME}
    EXPORT ${EXPORT_NAME}-targets
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})

  # and install the pdb file for debugging if exists
  if(WIN32)
    get_target_property(TARGET_TYPE ${TARGET_NAME} TYPE)
    if((${TARGET_TYPE} STREQUAL "SHARED_LIBRARY" OR ${TARGET_TYPE} STREQUAL "EXECUTABLE"))
      install(
        FILES $<TARGET_PDB_FILE:${TARGET_NAME}>
        DESTINATION bin
        OPTIONAL)
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
    set(${OUTPUT_VARIABLE_NAME}
        ${LIST_VALUES}
        PARENT_SCOPE)
  else()
    # otherwise set to empty list
    set(${OUTPUT_VARIABLE_NAME}
        ""
        PARENT_SCOPE)
  endif()
endfunction()

# return the csExportedListDefault global property
function(cs_get_exported_list_default OUTPUT_VARIABLE_NAME)
  get_property(LIST_VALUES GLOBAL PROPERTY csExportedListDefault)
  if(LIST_VALUES)
    # if exists
    set(${OUTPUT_VARIABLE_NAME}
        ${LIST_VALUES}
        PARENT_SCOPE)
  else()
    # otherwise set to empty list
    set(${OUTPUT_VARIABLE_NAME}
        ""
        PARENT_SCOPE)
  endif()
endfunction()

# return the csTargetExportedTo target property
function(cs_get_target_exported_to TARGET_NAME OUTPUT_VARIABLE_NAME)
  get_target_property(VALUE ${TARGET_NAME} csTargetExportedTo)
  set(${OUTPUT_VARIABLE_NAME}
      ${VALUE}
      PARENT_SCOPE)
endfunction()

# Compute the exports EXPORT_NAME depends on (the exports of the project targets its targets link to) and store them in
# the csExported<EXPORT_NAME>Depends global property.
function(_cs_populate_export_dependent_exports EXPORT_NAME)
  cs_get_exported_targets(${EXPORT_NAME} TARGETS_LIST)
  cs_debug_message(
    "[_cs_populate_export_dependent_exports] EXPORT ${EXPORT_NAME} has the following targets: ${TARGETS_LIST}")

  foreach(TARGET_NAME ${TARGETS_LIST})
    cs_get_target_dependencies(${TARGET_NAME} TARGET_DEPS)
    cs_debug_message(
      "[_cs_populate_export_dependent_exports] -- target ${TARGET_NAME} depends on internal targets ${TARGET_DEPS}")

    foreach(TARGET_DEP_NAME ${TARGET_DEPS})
      cs_get_target_exported_to(${TARGET_DEP_NAME} EXPORT_DEP_NAME)
      cs_debug_message(
        "[_cs_populate_export_dependent_exports] ---- subtarget ${TARGET_DEP_NAME} is exported to ${EXPORT_DEP_NAME}")
      if(NOT ${EXPORT_DEP_NAME} STREQUAL ${EXPORT_NAME})
        cs_debug_message("[_cs_populate_export_dependent_exports] ---- add ${EXPORT_DEP_NAME}")
        _cs_add_to_global_property_unique_value(csExported${EXPORT_NAME}Depends ${EXPORT_DEP_NAME})
      else()
        cs_debug_message("[_cs_populate_export_dependent_exports] ---- subtarget is in my same export set")
      endif()

    endforeach()

  endforeach()

  cs_get_exported_depends(${EXPORT_NAME} DEPENDENT_EXPORTS)
  cs_debug_message(
    "[_cs_populate_export_dependent_exports] final result, EXPORT ${EXPORT_NAME} depends on EXPORTS ${DEPENDENT_EXPORTS}"
  )
endfunction()

# Depth-first visit of the dependent exports of EXPORT_NAME; VISITED_LIST is the current path. Fails with FATAL_ERROR on
# a cycle.
function(_cs_check_export_cyclic_dependencies_recursive EXPORT_NAME VISITED_LIST)
  cs_debug_message(
    "[_cs_check_export_cyclic_dependencies_recursive] -- for export ${EXPORT_NAME} with visited list = ${VISITED_LIST}")

  if(${EXPORT_NAME} IN_LIST VISITED_LIST)
    message(
      FATAL_ERROR
        "[_cs_check_export_cyclic_dependencies_recursive] detected cyclic dependency: ${VISITED_LIST} -> ${EXPORT_NAME}"
    )
  endif()

  list(APPEND VISITED_LIST ${EXPORT_NAME})

  cs_get_exported_depends(${EXPORT_NAME} NEXT_ELEMENTS_LIST)
  foreach(NEXT_ELEMENT ${NEXT_ELEMENTS_LIST})
    cs_debug_message(
      "[_cs_check_export_cyclic_dependencies_recursive] -- for export ${EXPORT_NAME} call recursive on ${NEXT_ELEMENT} with visited list = ${VISITED_LIST}"
    )
    _cs_check_export_cyclic_dependencies_recursive(${NEXT_ELEMENT} "${VISITED_LIST}")
  endforeach()

endfunction()

# Fail with FATAL_ERROR if the export dependencies reachable from EXPORT_NAME contain a cycle.
function(_cs_check_export_cyclic_dependencies EXPORT_NAME)
  cs_debug_message("[_cs_check_export_cyclic_dependencies] -- for export ${EXPORT_NAME}")

  set(VISITED_LIST "")
  _cs_check_export_cyclic_dependencies_recursive(${EXPORT_NAME} "${VISITED_LIST}")

endfunction()

# Sort the dependent exports of EXPORT_NAME so that each export comes after the exports it depends on, and store the
# result in the csExported<EXPORT_NAME>DependsSorted global property.
function(_cs_sort_export_dependent_exports EXPORT_NAME)
  cs_get_exported_depends(${EXPORT_NAME} DEPENDENT_EXPORTS_UNSORTED)
  cs_debug_message(
    "[_cs_sort_export_dependent_exports] -- for export ${EXPORT_NAME} sort ${DEPENDENT_EXPORTS_UNSORTED}")

  # initialize the iterative list of target to analyze
  set(DEPENDENT_EXPORTS_LIST ${DEPENDENT_EXPORTS_UNSORTED})
  list(LENGTH DEPENDENT_EXPORTS_LIST DEPENDENT_EXPORTS_LIST_SIZE)

  cs_debug_message(
    "[_cs_sort_export_dependent_exports] -- initial list has ${DEPENDENT_EXPORTS_LIST_SIZE} elements: ${DEPENDENT_EXPORTS_LIST}"
  )

  set(DEPENDENT_EXPORTS_SORTED "")
  # loop
  while(DEPENDENT_EXPORTS_LIST_SIZE GREATER 0)
    # get the first target in the list
    list(GET DEPENDENT_EXPORTS_LIST 0 CURRENT_ELEMENT)
    # and remove it
    list(REMOVE_AT DEPENDENT_EXPORTS_LIST 0)

    # get the dependencies of the current element
    cs_get_exported_depends(${CURRENT_ELEMENT} CURRENT_ELEMENT_DEPENDENT_EXPORTS)
    cs_debug_message(
      "[_cs_sort_export_dependent_exports] ---- analyze ${CURRENT_ELEMENT}, it depends on: ${CURRENT_ELEMENT_DEPENDENT_EXPORTS}"
    )

    # clean up and keep only the one not yet satisfied
    set(CURRENT_ELEMENT_DEPENDENT_EXPORTS_CLEAN "")
    foreach(TEMP_ELEMENT ${CURRENT_ELEMENT_DEPENDENT_EXPORTS})
      if(NOT ${TEMP_ELEMENT} IN_LIST DEPENDENT_EXPORTS_SORTED)
        _cs_list_add_unique_value(CURRENT_ELEMENT_DEPENDENT_EXPORTS_CLEAN ${TEMP_ELEMENT})
      endif()
    endforeach()

    list(LENGTH CURRENT_ELEMENT_DEPENDENT_EXPORTS_CLEAN CURRENT_ELEMENT_DEPENDENT_EXPORTS_CLEAN_SIZE)
    cs_debug_message(
      "[_cs_sort_export_dependent_exports] ---- analyze ${CURRENT_ELEMENT}, cleaned up list of unsatisfied dependency has ${CURRENT_ELEMENT_DEPENDENT_EXPORTS_CLEAN_SIZE} elements: ${CURRENT_ELEMENT_DEPENDENT_EXPORTS_CLEAN}"
    )

    # finally add the element itself if is a leaf, or recursive add its dependencies and itself later
    if(CURRENT_ELEMENT_DEPENDENT_EXPORTS_CLEAN_SIZE EQUAL 0)
      cs_debug_message(
        "[_cs_sort_export_dependent_exports] ------ add ${CURRENT_ELEMENT} to sorted list, is a leaf (no other dependencies)"
      )
      _cs_list_add_unique_value(DEPENDENT_EXPORTS_SORTED ${CURRENT_ELEMENT})
    else()
      foreach(TEMP_ELEMENT ${CURRENT_ELEMENT_DEPENDENT_EXPORTS_CLEAN})
        cs_debug_message(
          "[_cs_sort_export_dependent_exports] ------ add ${TEMP_ELEMENT} to the elements to be re-evaluated")
        _cs_list_add_unique_value(DEPENDENT_EXPORTS_LIST ${TEMP_ELEMENT})
      endforeach()
      cs_debug_message(
        "[_cs_sort_export_dependent_exports] ------ add the original ${CURRENT_ELEMENT} to the elements to be re-evaluated"
      )
      _cs_list_add_unique_value(DEPENDENT_EXPORTS_LIST ${CURRENT_ELEMENT})
    endif()

    # finally refresh while condition variable
    list(LENGTH DEPENDENT_EXPORTS_LIST DEPENDENT_EXPORTS_LIST_SIZE)
  endwhile()

  cs_debug_message("[_cs_sort_export_dependent_exports] -- sort result: ${DEPENDENT_EXPORTS_SORTED}")
  set_property(GLOBAL PROPERTY csExported${EXPORT_NAME}DependsSorted "${DEPENDENT_EXPORTS_SORTED}")
endfunction()

# Install the export sets of the project in the EXPORT_NAMESPACE namespace: install the <export>Targets.cmake files,
# resolve and sort the dependencies between exports (failing on cycles), then generate and install
# <EXPORT_NAMESPACE>Config.cmake and <EXPORT_NAMESPACE>ConfigVersion.cmake.
function(_cs_finalize_install EXPORT_NAMESPACE)
  # directory to install cmake files
  set(INSTALL_CONFIGDIR ${CMAKE_INSTALL_LIBDIR}/cmake/${EXPORT_NAMESPACE})

  # get export list
  cs_get_exported_list(EXPORTS)
  # and install cmake files of them
  foreach(NAME ${EXPORTS})
    install(
      EXPORT ${NAME}-targets
      FILE ${NAME}Targets.cmake
      NAMESPACE ${EXPORT_NAMESPACE}::
      DESTINATION ${INSTALL_CONFIGDIR}/targets)
  endforeach()

  # per each export, prepare a list of the export it depends
  foreach(EXPORT_NAME ${EXPORTS})
    _cs_populate_export_dependent_exports(${EXPORT_NAME})

    # retrieve for debug purposes
    cs_get_exported_depends(${EXPORT_NAME} DEPENDENT_EXPORTS)
    cs_debug_message(
      "[_cs_finalize_install] -- EXPORT ${EXPORT_NAME} depends on other exports (unsorted) ${DEPENDENT_EXPORTS}")
  endforeach()

  # fail if cyclic loops in exports are detected
  foreach(EXPORT_NAME ${EXPORTS})
    _cs_check_export_cyclic_dependencies(${EXPORT_NAME})
  endforeach()

  # then sort the dependencies in order to have independent exports before
  foreach(EXPORT_NAME ${EXPORTS})
    _cs_sort_export_dependent_exports(${EXPORT_NAME} DEPENDENT_EXPORTS_SORTED)
    cs_get_exported_depends_sorted(${EXPORT_NAME} ${EXPORT_NAME}_DEPENDENT_EXPORTS_SORTED)
    cs_debug_message(
      "[_cs_finalize_install] -- EXPORT ${EXPORT_NAME} depends on other exports (sorted) ${${EXPORT_NAME}_DEPENDENT_EXPORTS_SORTED}"
    )
  endforeach()

  # write all ${${EXPORT_NAME}_DEPENDENT_EXPORTS} in the cmake config
  set(INJECTED_EXPORT_DEPENDENCIES "")
  foreach(EXPORT_NAME ${EXPORTS})
    set(INJECTED_EXPORT_DEPENDENCIES
        "${INJECTED_EXPORT_DEPENDENCIES}set(${EXPORT_NAME}_DEPENDENT_EXPORTS \"${${EXPORT_NAME}_DEPENDENT_EXPORTS_SORTED}\")\n"
    )
  endforeach()

  # create a sanitized version of EXPORT_NAMESPACE
  string(REPLACE "-" "_" EXPORT_NAMESPACE_SANITIZED "${EXPORT_NAMESPACE}")

  # generate the main cmake for finding this package
  set(INJECTED_FIND_PACKAGES_CODE "")
  foreach(EXPORT_NAME ${EXPORTS})
    cs_get_exported_find_packages(${EXPORT_NAME} FIND_PACKAGES_LIST)

    # create a sanitized version of EXPORT_NAME
    string(REPLACE "-" "_" EXPORT_NAME_SANITIZED "${EXPORT_NAME}")

    if(FIND_PACKAGES_LIST)
      set(INJECTED_FIND_PACKAGES_CODE
          "${INJECTED_FIND_PACKAGES_CODE}  if(NOT ${EXPORT_NAMESPACE_SANITIZED}Config_${EXPORT_NAME_SANITIZED}_FIND_DONE)\n"
      )
      set(INJECTED_FIND_PACKAGES_CODE
          "${INJECTED_FIND_PACKAGES_CODE}    if(\"${EXPORT_NAME}\" STREQUAL \"\${COMPONENT_NAME}\")\n")

      foreach(FIND_ARGS ${FIND_PACKAGES_LIST})
        set(INJECTED_FIND_PACKAGES_CODE
            "${INJECTED_FIND_PACKAGES_CODE}      ${EXPORT_NAMESPACE_SANITIZED}_debug_message(\"[${EXPORT_NAMESPACE}Config] find_dependency(${FIND_ARGS})\")\n"
        )
        set(INJECTED_FIND_PACKAGES_CODE "${INJECTED_FIND_PACKAGES_CODE}      find_dependency(${FIND_ARGS})\n")
      endforeach()

      set(INJECTED_FIND_PACKAGES_CODE
          "${INJECTED_FIND_PACKAGES_CODE}      SET(${EXPORT_NAMESPACE_SANITIZED}Config_${EXPORT_NAME_SANITIZED}_FIND_DONE True)\n"
      )

      set(INJECTED_FIND_PACKAGES_CODE "${INJECTED_FIND_PACKAGES_CODE}    endif()\n")
      set(INJECTED_FIND_PACKAGES_CODE "${INJECTED_FIND_PACKAGES_CODE}  else()\n")
      set(INJECTED_FIND_PACKAGES_CODE
          "${INJECTED_FIND_PACKAGES_CODE}   ${EXPORT_NAMESPACE_SANITIZED}_debug_message(\"[${EXPORT_NAMESPACE}Config] find_dependency for ${EXPORT_NAME} already satisfied\")\n"
      )
      set(INJECTED_FIND_PACKAGES_CODE "${INJECTED_FIND_PACKAGES_CODE}  endif()\n")
    endif()
  endforeach()

  if(INJECTED_FIND_PACKAGES_CODE)
    set(INJECTED_FIND_PACKAGES_CODE
        "  # -- find packages section --\n${INJECTED_FIND_PACKAGES_CODE}  # -- end find packages section --")
  endif()

  # get list of components when find_package without arguments is used
  cs_get_exported_list(COMPONENTS_LIST)
  # get list of default components when find_package without arguments is used
  cs_get_exported_list_default(DEFAULT_COMPONENTS_LIST)

  # retrieve output folder for generated files
  cs_get_generate_folder_common(OUTPUT_FOLDER)

  # Write the Config.cmake file
  _cs_configure_config_cmake(
    ${OUTPUT_FOLDER}
    ${EXPORT_NAMESPACE}
    ${EXPORT_NAMESPACE_SANITIZED}
    "${COMPONENTS_LIST}"
    "${DEFAULT_COMPONENTS_LIST}"
    "${INJECTED_FIND_PACKAGES_CODE}"
    "${INJECTED_EXPORT_DEPENDENCIES}")

  # Write a ConfigVersion.cmake file
  write_basic_package_version_file(
    ${OUTPUT_FOLDER}/${EXPORT_NAMESPACE}ConfigVersion.cmake
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY AnyNewerVersion)

  # Install the Config and configVersion files
  install(FILES ${OUTPUT_FOLDER}/${EXPORT_NAMESPACE}Config.cmake ${OUTPUT_FOLDER}/${EXPORT_NAMESPACE}ConfigVersion.cmake
          DESTINATION ${INSTALL_CONFIGDIR})

endfunction()

# Generate <OUTPUT_FOLDER>/<EXPORT_NAMESPACE>Config.cmake from templates/csTemplateConfig.cmake.in. The argument names
# are the @VAR@ placeholders of the template: do not rename them.
function(
  _cs_configure_config_cmake
  OUTPUT_FOLDER
  EXPORT_NAMESPACE
  EXPORT_NAMESPACE_SANITIZED
  COMPONENTS_LIST
  DEFAULT_COMPONENTS_LIST
  INJECTED_FIND_PACKAGES_CODE
  INJECTED_EXPORT_DEPENDENCIES)
  # note, the file csTemplateConfig.cmake.in uses the @variable@ substituion with the values prepared in this function
  # of - EXPORT_NAMESPACE - EXPORT_NAMESPACE_SANITIZED - COMPONENTS_LIST - DEFAULT_COMPONENTS_LIST -
  # INJECTED_FIND_PACKAGES_CODE - INJECTED_EXPORT_DEPENDENCIES do not refactor / change name of those variables

  set(TEMP "${EXPORT_NAMESPACE}")
  string(REPLACE "-" "_" EXPORT_NAMESPACE_SANITIZED "${TEMP}")

  cs_get_base_path(_BASE_PATH)
  configure_package_config_file(
    "${_BASE_PATH}/templates/csTemplateConfig.cmake.in" "${OUTPUT_FOLDER}/${EXPORT_NAMESPACE}Config.cmake"
    INSTALL_DESTINATION ${INSTALL_CONFIGDIR})

endfunction()

# return the csExported${EXPORT_NAME}Targets global property
function(cs_get_exported_targets EXPORT_NAME OUTPUT_VARIABLE_NAME)
  get_property(LIST_VALUES GLOBAL PROPERTY csExported${EXPORT_NAME}Targets)
  if(LIST_VALUES)
    # if exists
    set(${OUTPUT_VARIABLE_NAME}
        ${LIST_VALUES}
        PARENT_SCOPE)
  else()
    # otherwise set to empty list
    set(${OUTPUT_VARIABLE_NAME}
        ""
        PARENT_SCOPE)
  endif()
endfunction()

# return the csExported${EXPORT_NAME}Depends global property
function(cs_get_exported_depends EXPORT_NAME OUTPUT_VARIABLE_NAME)
  get_property(LIST_VALUES GLOBAL PROPERTY csExported${EXPORT_NAME}Depends)
  if(LIST_VALUES)
    # if exists
    set(${OUTPUT_VARIABLE_NAME}
        ${LIST_VALUES}
        PARENT_SCOPE)
  else()
    # otherwise set to empty list
    set(${OUTPUT_VARIABLE_NAME}
        ""
        PARENT_SCOPE)
  endif()
endfunction()

# return the csExported${EXPORT_NAME}DependsSorted global property
function(cs_get_exported_depends_sorted EXPORT_NAME OUTPUT_VARIABLE_NAME)
  get_property(LIST_VALUES GLOBAL PROPERTY csExported${EXPORT_NAME}DependsSorted)
  if(LIST_VALUES)
    # if exists
    set(${OUTPUT_VARIABLE_NAME}
        ${LIST_VALUES}
        PARENT_SCOPE)
  else()
    # otherwise set to empty list
    set(${OUTPUT_VARIABLE_NAME}
        ""
        PARENT_SCOPE)
  endif()
endfunction()

# return the csExported${EXPORT_NAME}FindPackages global property
function(cs_get_exported_find_packages EXPORT_NAME OUTPUT_VARIABLE_NAME)
  get_property(LIST_VALUES GLOBAL PROPERTY csExported${EXPORT_NAME}FindPackages)
  if(LIST_VALUES)
    # if exists
    set(${OUTPUT_VARIABLE_NAME}
        ${LIST_VALUES}
        PARENT_SCOPE)
  else()
    # otherwise set to empty list
    set(${OUTPUT_VARIABLE_NAME}
        ""
        PARENT_SCOPE)
  endif()
endfunction()

# debug, print exported list and information cumulated per each export item
function(cs_print_exported_list_details)
  cs_get_exported_list(EXPORTS)
  foreach(EXPORT ${EXPORTS})
    cs_get_exported_targets(${EXPORT} TARGETS_VALUES)
    cs_get_exported_find_packages(${EXPORT} FIND_PACKAGES_VALUES)
    cs_get_exported_depends(${EXPORT} DEPENDS_VALUES)
    cs_get_exported_depends_sorted(${EXPORT} DEPENDS_VALUES_SORTED)
    cs_debug_message(
      "[cs_print_exported_list_details] export ${EXPORT} contains the following targets: ${TARGETS_VALUES}, has the following find_packages: ${FIND_PACKAGES_VALUES} and depends on those other exports: ${DEPENDS_VALUES} (sorted as ${DEPENDS_VALUES_SORTED})"
    )
  endforeach()

  cs_get_exported_list(EXPORTS_DEFAULT)
  cs_debug_message("[cs_print_exported_list_details] default exported targets  ${EXPORTS_DEFAULT}")
endfunction()
