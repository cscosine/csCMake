include_guard(GLOBAL)
# cmake-lint: disable=R0913
# (only _cs_configure_config_cmake has more than 5 arguments: one per @VAR@ placeholder of the template)
include(utils/csFindPackage)
include(utils/csListUtils)
include(utils/csPathUtils)
include(utils/csTargetDependencies)

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

# Return in install_folder_expression the install folder for headers: CMAKE_INSTALL_INCLUDEDIR, plus a $<CONFIG> sub-
# folder when the project has more than one configuration.
function(cs_get_install_include_dir install_folder_expression)
  cs_get_build_configurations(CONFIGS_LIST)
  list(LENGTH CONFIGS_LIST count)
  if(count GREATER 1)
    # includes are installed per configuration, independently if we are with a multi generator or a single one
    set(folder "${CMAKE_INSTALL_INCLUDEDIR}/$<CONFIG>")
    set(${install_folder_expression}
        "${folder}"
        PARENT_SCOPE)
  else()
    set(folder "${CMAKE_INSTALL_INCLUDEDIR}")
    set(${install_folder_expression}
        "${folder}"
        PARENT_SCOPE)
  endif()
endfunction()

# create a global variable CSCMAKE_COMPONENTS collecting all the different export_name used create a global variable
# CSCMAKE_COMPONENT_<export_name>_FIND_PACKAGES containing the list of find_package(ARGS...) that will be added to the
# installed configuration file if DEFAULT is passed as additional arguments, the export_name will be added to the list
# CSCMAKE_DEFAULT_COMPONENTS global variable add a target property CSCMAKE_COMPONENT with the name of the export
function(cs_install_target target_name export_name)
  cs_debug_message("[cs_install_target] target ${target_name} export to ${export_name}")

  # set the CSCMAKE_COMPONENT property
  set_target_properties(${target_name} PROPERTIES CSCMAKE_COMPONENT ${export_name})

  # get the relative folder from the target folder to the base of the project
  file(RELATIVE_PATH destination_folder ${CMAKE_SOURCE_DIR} ${CMAKE_CURRENT_SOURCE_DIR})

  # add the EXPORT_NAME to the list of exports
  _cs_add_to_global_property_unique_value(CSCMAKE_COMPONENTS ${export_name})

  # add the target to default list
  if(${ARGC} EQUAL 2)
    # nothing to do, do not
  elseif(${ARGC} EQUAL 3)
    if(${ARGV2} STREQUAL "DEFAULT")
      _cs_add_to_global_property_unique_value(CSCMAKE_DEFAULT_COMPONENTS ${export_name})
    else()
      message(FATAL_ERROR "cs_install_target argument 3 should be DEFAULT or should be empty")
    endif()
  else()
    message(FATAL_ERROR "cs_install_target expects 2 or 3 arguments")
  endif()

  # retrieve the source files that have to be installed
  cs_get_target_sources_to_install(${target_name} files_to_install)
  cs_get_install_include_dir(install_folder_expression)
  foreach(file ${files_to_install})
    set(source_path ${CMAKE_CURRENT_SOURCE_DIR}/${file})

    # preserve subfolders structure
    get_filename_component(file_dir "${file}" DIRECTORY)
    if(file_dir)
      set(file_dir "${file_dir}/")
    endif()
    set(dest_path ${install_folder_expression}/${destination_folder}/${file_dir})

    install(FILES ${source_path} DESTINATION ${dest_path})
    cs_debug_message("-- [cs_install_target] install ${source_path} to ${dest_path}" true)
  endforeach()

  # retrieve the source files that have to be installed from a absolute path
  cs_get_target_sources_to_install_absolute_path(${target_name} files_to_install)
  foreach(file ${files_to_install})
    set(source_path ${file})
    set(dest_path ${install_folder_expression}/${destination_folder}/)
    install(FILES ${source_path} DESTINATION ${dest_path})
    cs_debug_message("-- [cs_install_target] install ${source_path} to ${dest_path}" true)
  endforeach()

  # install effectively the target
  install(
    TARGETS ${target_name}
    EXPORT ${export_name}-targets
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})

  # and install the pdb file for debugging if exists
  if(WIN32)
    get_target_property(target_type ${target_name} TYPE)
    if((${target_type} STREQUAL "SHARED_LIBRARY" OR ${target_type} STREQUAL "EXECUTABLE"))
      install(
        FILES $<TARGET_PDB_FILE:${target_name}>
        DESTINATION bin
        OPTIONAL)
    endif()
  endif()

  # add the target to the list of target of this export
  _cs_add_to_global_property_unique_value(CSCMAKE_COMPONENT_${export_name}_TARGETS ${target_name})

  # get all the find_packages propagated for this target
  cs_get_target_find_packages(${target_name} find_packages_list)
  foreach(find_package ${find_packages_list})
    _cs_add_to_global_property_unique_value(CSCMAKE_COMPONENT_${export_name}_FIND_PACKAGES ${find_package})
  endforeach()

endfunction()

# return the CSCMAKE_COMPONENTS global property
function(cs_get_components output_variable_name)
  get_property(list_values GLOBAL PROPERTY CSCMAKE_COMPONENTS)
  if(list_values)
    # if exists
    set(${output_variable_name}
        ${list_values}
        PARENT_SCOPE)
  else()
    # otherwise set to empty list
    set(${output_variable_name}
        ""
        PARENT_SCOPE)
  endif()
endfunction()

# return the CSCMAKE_DEFAULT_COMPONENTS global property
function(cs_get_default_components output_variable_name)
  get_property(list_values GLOBAL PROPERTY CSCMAKE_DEFAULT_COMPONENTS)
  if(list_values)
    # if exists
    set(${output_variable_name}
        ${list_values}
        PARENT_SCOPE)
  else()
    # otherwise set to empty list
    set(${output_variable_name}
        ""
        PARENT_SCOPE)
  endif()
endfunction()

# return the CSCMAKE_COMPONENT target property
function(cs_get_target_component target_name output_variable_name)
  get_target_property(value ${target_name} CSCMAKE_COMPONENT)
  set(${output_variable_name}
      ${value}
      PARENT_SCOPE)
endfunction()

# Compute the exports export_name depends on (the exports of the project targets its targets link to) and store them in
# the CSCMAKE_COMPONENT_<export_name>_DEPENDENCIES global property.
function(_cs_populate_component_dependencies export_name)
  cs_get_component_targets(${export_name} targets_list)
  cs_debug_message(
    "[_cs_populate_component_dependencies] EXPORT ${export_name} has the following targets: ${targets_list}")

  foreach(target_name ${targets_list})
    cs_get_target_project_dependencies(${target_name} target_deps)
    cs_debug_message(
      "[_cs_populate_component_dependencies] -- target ${target_name} depends on internal targets ${target_deps}")

    foreach(target_dep_name ${target_deps})
      cs_get_target_component(${target_dep_name} export_dep_name)
      cs_debug_message(
        "[_cs_populate_component_dependencies] ---- subtarget ${target_dep_name} is exported to ${export_dep_name}")
      if(NOT ${export_dep_name} STREQUAL ${export_name})
        cs_debug_message("[_cs_populate_component_dependencies] ---- add ${export_dep_name}")
        _cs_add_to_global_property_unique_value(CSCMAKE_COMPONENT_${export_name}_DEPENDENCIES ${export_dep_name})
      else()
        cs_debug_message("[_cs_populate_component_dependencies] ---- subtarget is in my same export set")
      endif()

    endforeach()

  endforeach()

  cs_get_component_dependencies(${export_name} dependent_exports)
  cs_debug_message(
    "[_cs_populate_component_dependencies] final result, EXPORT ${export_name} depends on EXPORTS ${dependent_exports}")
endfunction()

# Depth-first visit of the dependent exports of export_name; visited_list is the current path. Fails with FATAL_ERROR on
# a cycle.
function(_cs_check_component_cycles_recursive export_name visited_list)
  cs_debug_message(
    "[_cs_check_component_cycles_recursive] -- for export ${export_name} with visited list = ${visited_list}")

  if(${export_name} IN_LIST visited_list)
    message(
      FATAL_ERROR "[_cs_check_component_cycles_recursive] detected cyclic dependency: ${visited_list} -> ${export_name}"
    )
  endif()

  list(APPEND visited_list ${export_name})

  cs_get_component_dependencies(${export_name} next_elements_list)
  foreach(next_element ${next_elements_list})
    cs_debug_message(
      "[_cs_check_component_cycles_recursive] -- for export ${export_name} call recursive on ${next_element} with visited list = ${visited_list}"
    )
    _cs_check_component_cycles_recursive(${next_element} "${visited_list}")
  endforeach()

endfunction()

# Fail with FATAL_ERROR if the export dependencies reachable from export_name contain a cycle.
function(_cs_check_component_cycles export_name)
  cs_debug_message("[_cs_check_component_cycles] -- for export ${export_name}")

  set(visited_list "")
  _cs_check_component_cycles_recursive(${export_name} "${visited_list}")

endfunction()

# Sort the dependent exports of export_name so that each export comes after the exports it depends on, and store the
# result in the CSCMAKE_COMPONENT_<export_name>_DEPENDENCIES_SORTED global property.
function(_cs_sort_component_dependencies export_name)
  cs_get_component_dependencies(${export_name} dependent_exports_unsorted)
  cs_debug_message("[_cs_sort_component_dependencies] -- for export ${export_name} sort ${dependent_exports_unsorted}")

  # initialize the iterative list of target to analyze
  set(dependent_exports_list ${dependent_exports_unsorted})
  list(LENGTH dependent_exports_list dependent_exports_list_size)

  cs_debug_message(
    "[_cs_sort_component_dependencies] -- initial list has ${dependent_exports_list_size} elements: ${dependent_exports_list}"
  )

  set(dependent_exports_sorted "")
  # loop
  while(dependent_exports_list_size GREATER 0)
    # get the first target in the list
    list(GET dependent_exports_list 0 current_element)
    # and remove it
    list(REMOVE_AT dependent_exports_list 0)

    # get the dependencies of the current element
    cs_get_component_dependencies(${current_element} current_element_dependent_exports)
    cs_debug_message(
      "[_cs_sort_component_dependencies] ---- analyze ${current_element}, it depends on: ${current_element_dependent_exports}"
    )

    # clean up and keep only the one not yet satisfied
    set(current_element_dependent_exports_clean "")
    foreach(temp_element ${current_element_dependent_exports})
      if(NOT ${temp_element} IN_LIST dependent_exports_sorted)
        _cs_list_add_unique_value(current_element_dependent_exports_clean ${temp_element})
      endif()
    endforeach()

    list(LENGTH current_element_dependent_exports_clean current_element_dependent_exports_clean_size)
    cs_debug_message(
      "[_cs_sort_component_dependencies] ---- analyze ${current_element}, cleaned up list of unsatisfied dependency has ${current_element_dependent_exports_clean_size} elements: ${current_element_dependent_exports_clean}"
    )

    # finally add the element itself if is a leaf, or recursive add its dependencies and itself later
    if(current_element_dependent_exports_clean_size EQUAL 0)
      cs_debug_message(
        "[_cs_sort_component_dependencies] ------ add ${current_element} to sorted list, is a leaf (no other dependencies)"
      )
      _cs_list_add_unique_value(dependent_exports_sorted ${current_element})
    else()
      foreach(temp_element ${current_element_dependent_exports_clean})
        cs_debug_message(
          "[_cs_sort_component_dependencies] ------ add ${temp_element} to the elements to be re-evaluated")
        _cs_list_add_unique_value(dependent_exports_list ${temp_element})
      endforeach()
      cs_debug_message(
        "[_cs_sort_component_dependencies] ------ add the original ${current_element} to the elements to be re-evaluated"
      )
      _cs_list_add_unique_value(dependent_exports_list ${current_element})
    endif()

    # finally refresh while condition variable
    list(LENGTH dependent_exports_list dependent_exports_list_size)
  endwhile()

  cs_debug_message("[_cs_sort_component_dependencies] -- sort result: ${dependent_exports_sorted}")
  set_property(GLOBAL PROPERTY CSCMAKE_COMPONENT_${export_name}_DEPENDENCIES_SORTED "${dependent_exports_sorted}")
endfunction()

# Install the export sets of the project in the export_namespace namespace: install the <export>Targets.cmake files,
# resolve and sort the dependencies between exports (failing on cycles), then generate and install
# <export_namespace>Config.cmake and <export_namespace>ConfigVersion.cmake.
function(_cs_finalize_install export_namespace)
  # directory to install cmake files
  set(install_configdir ${CMAKE_INSTALL_LIBDIR}/cmake/${export_namespace})

  # get export list
  cs_get_components(exports)
  # and install cmake files of them
  foreach(name ${exports})
    install(
      EXPORT ${name}-targets
      FILE ${name}Targets.cmake
      NAMESPACE ${export_namespace}::
      DESTINATION ${install_configdir}/targets)
  endforeach()

  # per each export, prepare a list of the export it depends
  foreach(export_name ${exports})
    _cs_populate_component_dependencies(${export_name})

    # retrieve for debug purposes
    cs_get_component_dependencies(${export_name} dependent_exports)
    cs_debug_message(
      "[_cs_finalize_install] -- EXPORT ${export_name} depends on other exports (unsorted) ${dependent_exports}")
  endforeach()

  # fail if cyclic loops in exports are detected
  foreach(export_name ${exports})
    _cs_check_component_cycles(${export_name})
  endforeach()

  # then sort the dependencies in order to have independent exports before
  foreach(export_name ${exports})
    _cs_sort_component_dependencies(${export_name} DEPENDENT_EXPORTS_SORTED)
    cs_get_component_dependencies_sorted(${export_name} ${export_name}_DEPENDENT_EXPORTS_SORTED)
    cs_debug_message(
      "[_cs_finalize_install] -- EXPORT ${export_name} depends on other exports (sorted) ${${export_name}_DEPENDENT_EXPORTS_SORTED}"
    )
  endforeach()

  # write all ${${EXPORT_NAME}_DEPENDENT_EXPORTS} in the cmake config
  set(injected_export_dependencies "")
  foreach(export_name ${exports})
    set(injected_export_dependencies
        "${injected_export_dependencies}set(${export_name}_DEPENDENT_EXPORTS \"${${export_name}_DEPENDENT_EXPORTS_SORTED}\")\n"
    )
  endforeach()

  # create a sanitized version of EXPORT_NAMESPACE
  string(REPLACE "-" "_" export_namespace_sanitized "${export_namespace}")

  # generate the main cmake for finding this package
  set(injected_find_packages_code "")
  foreach(export_name ${exports})
    cs_get_component_find_packages(${export_name} find_packages_list)

    # create a sanitized version of EXPORT_NAME
    string(REPLACE "-" "_" export_name_sanitized "${export_name}")

    if(find_packages_list)
      set(injected_find_packages_code
          "${injected_find_packages_code}  if(NOT ${export_namespace_sanitized}Config_${export_name_sanitized}_FIND_DONE)\n"
      )
      set(injected_find_packages_code
          "${injected_find_packages_code}    if(\"${export_name}\" STREQUAL \"\${component_name}\")\n")

      foreach(find_args ${find_packages_list})
        set(injected_find_packages_code
            "${injected_find_packages_code}      ${export_namespace_sanitized}_debug_message(\"[${export_namespace}Config] find_dependency(${find_args})\")\n"
        )
        set(injected_find_packages_code "${injected_find_packages_code}      find_dependency(${find_args})\n")
      endforeach()

      set(injected_find_packages_code
          "${injected_find_packages_code}      SET(${export_namespace_sanitized}Config_${export_name_sanitized}_FIND_DONE True)\n"
      )

      set(injected_find_packages_code "${injected_find_packages_code}    endif()\n")
      set(injected_find_packages_code "${injected_find_packages_code}  else()\n")
      set(injected_find_packages_code
          "${injected_find_packages_code}   ${export_namespace_sanitized}_debug_message(\"[${export_namespace}Config] find_dependency for ${export_name} already satisfied\")\n"
      )
      set(injected_find_packages_code "${injected_find_packages_code}  endif()\n")
    endif()
  endforeach()

  # always wrapped (also when empty): the template indents the placeholder line, so the first line has no leading spaces
  # and an empty section does not leave a whitespace-only line in the generated Config.cmake
  set(injected_find_packages_code
      "# -- find packages section --\n${injected_find_packages_code}  # -- end find packages section --")

  # get list of components when find_package without arguments is used
  cs_get_components(components_list)
  # get list of default components when find_package without arguments is used
  cs_get_default_components(default_components_list)

  # retrieve output folder for generated files
  cs_get_generated_dir(output_folder)

  # Write the Config.cmake file
  _cs_configure_config_cmake(
    ${output_folder}
    ${export_namespace}
    ${export_namespace_sanitized}
    "${components_list}"
    "${default_components_list}"
    "${injected_find_packages_code}"
    "${injected_export_dependencies}")

  # Write a ConfigVersion.cmake file
  write_basic_package_version_file(
    ${output_folder}/${export_namespace}ConfigVersion.cmake
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY AnyNewerVersion)

  # Install the Config and configVersion files
  install(FILES ${output_folder}/${export_namespace}Config.cmake ${output_folder}/${export_namespace}ConfigVersion.cmake
          DESTINATION ${install_configdir})

endfunction()

# Generate <output_folder>/<export_namespace>Config.cmake from templates/csTemplateConfig.cmake.in. The argument names
# are the @VAR@ placeholders of the template: do not rename them.
function(
  _cs_configure_config_cmake
  output_folder
  export_namespace
  export_namespace_sanitized
  components_list
  default_components_list
  injected_find_packages_code
  injected_export_dependencies)
  # templates/csTemplateConfig.cmake.in uses these variables as @variable@ placeholders: rename them together
  #
  # * export_namespace, export_namespace_sanitized
  # * components_list, default_components_list
  # * injected_find_packages_code, injected_export_dependencies

  set(temp "${export_namespace}")
  string(REPLACE "-" "_" export_namespace_sanitized "${temp}")

  _cs_get_root_dir(base_path)
  configure_package_config_file(
    "${base_path}/templates/csTemplateConfig.cmake.in" "${output_folder}/${export_namespace}Config.cmake"
    INSTALL_DESTINATION ${install_configdir})

endfunction()

# return the CSCMAKE_COMPONENT_${export_name}_TARGETS global property
function(cs_get_component_targets export_name output_variable_name)
  get_property(list_values GLOBAL PROPERTY CSCMAKE_COMPONENT_${export_name}_TARGETS)
  if(list_values)
    # if exists
    set(${output_variable_name}
        ${list_values}
        PARENT_SCOPE)
  else()
    # otherwise set to empty list
    set(${output_variable_name}
        ""
        PARENT_SCOPE)
  endif()
endfunction()

# return the CSCMAKE_COMPONENT_${export_name}_DEPENDENCIES global property
function(cs_get_component_dependencies export_name output_variable_name)
  get_property(list_values GLOBAL PROPERTY CSCMAKE_COMPONENT_${export_name}_DEPENDENCIES)
  if(list_values)
    # if exists
    set(${output_variable_name}
        ${list_values}
        PARENT_SCOPE)
  else()
    # otherwise set to empty list
    set(${output_variable_name}
        ""
        PARENT_SCOPE)
  endif()
endfunction()

# return the CSCMAKE_COMPONENT_${export_name}_DEPENDENCIES_SORTED global property
function(cs_get_component_dependencies_sorted export_name output_variable_name)
  get_property(list_values GLOBAL PROPERTY CSCMAKE_COMPONENT_${export_name}_DEPENDENCIES_SORTED)
  if(list_values)
    # if exists
    set(${output_variable_name}
        ${list_values}
        PARENT_SCOPE)
  else()
    # otherwise set to empty list
    set(${output_variable_name}
        ""
        PARENT_SCOPE)
  endif()
endfunction()

# return the CSCMAKE_COMPONENT_${export_name}_FIND_PACKAGES global property
function(cs_get_component_find_packages export_name output_variable_name)
  get_property(list_values GLOBAL PROPERTY CSCMAKE_COMPONENT_${export_name}_FIND_PACKAGES)
  if(list_values)
    # if exists
    set(${output_variable_name}
        ${list_values}
        PARENT_SCOPE)
  else()
    # otherwise set to empty list
    set(${output_variable_name}
        ""
        PARENT_SCOPE)
  endif()
endfunction()

# debug, print exported list and information cumulated per each export item
function(cs_print_components)
  cs_get_components(exports)
  foreach(export ${exports})
    cs_get_component_targets(${export} targets_values)
    cs_get_component_find_packages(${export} find_packages_values)
    cs_get_component_dependencies(${export} depends_values)
    cs_get_component_dependencies_sorted(${export} depends_values_sorted)
    cs_debug_message(
      "[cs_print_components] export ${export} contains the following targets: ${targets_values}, has the following find_packages: ${find_packages_values} and depends on those other exports: ${depends_values} (sorted as ${depends_values_sorted})"
    )
  endforeach()

  cs_get_components(exports_default)
  cs_debug_message("[cs_print_components] default exported targets  ${exports_default}")
endfunction()
