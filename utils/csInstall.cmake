#.rst:
# csInstall
# ---------
#
# Installation: the components of the package of the project (:command:`cs_install_target`), the dependencies between
# them, the generated ``<namespace>Config.cmake`` (``find_package(<namespace> [COMPONENTS ...])``).
#
# Commands
# ^^^^^^^^
include_guard(GLOBAL)
include(utils/csFindPackage)
include(utils/csListUtils)
include(utils/csPathUtils)
include(utils/csTargetDependencies)

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

#.rst:
# .. command:: cs_get_install_include_dir
#
#   Return the install folder of the headers, for ``install(... DESTINATION ...)``: CMAKE_INSTALL_INCLUDEDIR, plus a
#   $<CONFIG> sub-folder when the project has more than one configuration (evaluated with the configuration being
#   installed). The consumers get the include folders from ``<namespace>::cscmake_base_include``, which follow the
#   configuration CMake selects for them.
#
#   .. code-block:: cmake
#
#     cs_get_install_include_dir(<out-var>)
#
#   ``<out-var>``
#     The variable to set, in the scope of the caller.
function(cs_get_install_include_dir install_folder_expression)
  cs_get_build_configurations(configs_list)
  list(LENGTH configs_list count)
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

#.rst:
# .. command:: cs_install_target
#
#   Install a target in a component of the package of the project.
#
#   .. code-block:: cmake
#
#     cs_install_target(<target> <component> [DEFAULT])
#
#   The target, its PDB file (Windows) and its headers queued by :command:`cs_target_sources` (``*_INSTALL``) are
#   installed; the component is a ``find_package(<namespace> COMPONENTS ...)`` component, DEFAULT adds it to the
#   components loaded when none is requested.
#
#   ``<target>``
#     A target of the project.
#
#   ``<component>``
#     The component of the package the target belongs to: what consumers ask for with ``find_package(<namespace>
#     COMPONENTS <component>)``.
#
#   ``DEFAULT``
#     The component is loaded when the consumer gives no ``COMPONENTS``.
#
#   :Reads: :prop_tgt:`CSCMAKE_SOURCES_TO_INSTALL`, :prop_tgt:`CSCMAKE_SOURCES_TO_INSTALL_ABSOLUTE`,
#     :prop_tgt:`CSCMAKE_FIND_PACKAGES`, :variable:`CSCMAKE_SOURCE_DIR`, :variable:`CSCMAKE_NAMESPACE`
#   :Writes: :prop_tgt:`CSCMAKE_COMPONENT`, :prop_gbl:`CSCMAKE_<namespace>_COMPONENTS`,
#     :prop_gbl:`CSCMAKE_<namespace>_DEFAULT_COMPONENTS`, :prop_gbl:`CSCMAKE_<namespace>_COMPONENT_<component>_TARGETS`,
#     :prop_gbl:`CSCMAKE_<namespace>_COMPONENT_<component>_FIND_PACKAGES`
function(cs_install_target target_name export_name)
  cs_debug_message("[cs_install_target] target ${target_name} export to ${export_name}")

  # set the CSCMAKE_COMPONENT property
  set_target_properties(${target_name} PROPERTIES CSCMAKE_COMPONENT ${export_name})

  # get the relative folder from the target folder to the base of the project
  file(RELATIVE_PATH destination_folder ${CSCMAKE_SOURCE_DIR} ${CMAKE_CURRENT_SOURCE_DIR})

  # add the EXPORT_NAME to the list of exports
  _cs_add_to_global_property_unique_value(CSCMAKE_${CSCMAKE_NAMESPACE}_COMPONENTS ${export_name})

  # add the target to default list
  if(${ARGC} EQUAL 2)
    # nothing to do, do not
  elseif(${ARGC} EQUAL 3)
    if(${ARGV2} STREQUAL "DEFAULT")
      _cs_add_to_global_property_unique_value(CSCMAKE_${CSCMAKE_NAMESPACE}_DEFAULT_COMPONENTS ${export_name})
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
    cs_debug_message("-- [cs_install_target] install ${source_path} to ${dest_path}")
  endforeach()

  # retrieve the source files that have to be installed from a absolute path
  cs_get_target_sources_to_install_absolute_path(${target_name} files_to_install)
  foreach(file ${files_to_install})
    set(source_path ${file})
    set(dest_path ${install_folder_expression}/${destination_folder}/)
    install(FILES ${source_path} DESTINATION ${dest_path})
    cs_debug_message("-- [cs_install_target] install ${source_path} to ${dest_path}")
  endforeach()

  # install effectively the target
  install(
    TARGETS ${target_name}
    EXPORT ${CSCMAKE_NAMESPACE}_${export_name}-targets
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})

  # and install the pdb file for debugging if exists
  if(WIN32)
    get_target_property(target_type ${target_name} TYPE)
    if((${target_type} STREQUAL "SHARED_LIBRARY" OR ${target_type} STREQUAL "EXECUTABLE"))
      install(
        FILES $<TARGET_PDB_FILE:${target_name}>
        DESTINATION ${CMAKE_INSTALL_BINDIR}
        OPTIONAL)
    endif()
  endif()

  # add the target to the list of target of this export
  _cs_add_to_global_property_unique_value(CSCMAKE_${CSCMAKE_NAMESPACE}_COMPONENT_${export_name}_TARGETS ${target_name})

  # get all the find_packages propagated for this target
  cs_get_target_find_packages(${target_name} find_packages_list)
  foreach(find_package ${find_packages_list})
    _cs_add_to_global_property_unique_value(CSCMAKE_${CSCMAKE_NAMESPACE}_COMPONENT_${export_name}_FIND_PACKAGES
                                            ${find_package})
  endforeach()

endfunction()

#.rst:
# .. command:: cs_get_components
#
#   Return the components of the project.
#
#   .. code-block:: cmake
#
#     cs_get_components(<out-var>)
#
#   ``<out-var>``
#     The variable to set, in the scope of the caller.
#
#   :Reads: :prop_gbl:`CSCMAKE_<namespace>_COMPONENTS`
function(cs_get_components output_variable_name)
  get_property(list_values GLOBAL PROPERTY CSCMAKE_${CSCMAKE_NAMESPACE}_COMPONENTS)
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

#.rst:
# .. command:: cs_get_default_components
#
#   Return the default components of the project (loaded by :command:`find_package` without COMPONENTS).
#
#   .. code-block:: cmake
#
#     cs_get_default_components(<out-var>)
#
#   ``<out-var>``
#     The variable to set, in the scope of the caller.
#
#   :Reads: :prop_gbl:`CSCMAKE_<namespace>_DEFAULT_COMPONENTS`
function(cs_get_default_components output_variable_name)
  get_property(list_values GLOBAL PROPERTY CSCMAKE_${CSCMAKE_NAMESPACE}_DEFAULT_COMPONENTS)
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

#.rst:
# .. command:: cs_get_target_component
#
#   Return the component of a target (:command:`cs_install_target`).
#
#   .. code-block:: cmake
#
#     cs_get_target_component(<target> <out-var>)
#
#   ``<target>``
#     A target of the project.
#
#   ``<out-var>``
#     The variable to set, in the scope of the caller.
#
#   :Reads: :prop_tgt:`CSCMAKE_COMPONENT`
function(cs_get_target_component target_name output_variable_name)
  get_target_property(value ${target_name} CSCMAKE_COMPONENT)
  set(${output_variable_name}
      ${value}
      PARENT_SCOPE)
endfunction()

# Compute the components export_name depends on (the components of the project targets its targets link to); a target of
# another csCMake project of the build adds a find_dependency of that package instead.
#
# Reads:
#
# * target property CSCMAKE_COMPONENT, CSCMAKE_NAMESPACE, CSCMAKE_PROJECT_DEPENDENCIES
#
# Writes:
#
# * global property CSCMAKE_<namespace>_COMPONENT_<component>_DEPENDENCIES
# * global property CSCMAKE_<namespace>_COMPONENT_<component>_FIND_PACKAGES
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

      # a target of another csCMake project of the build (nested project): its package is a dependency of this component
      get_target_property(dep_namespace ${target_dep_name} CSCMAKE_NAMESPACE)
      if(dep_namespace AND NOT dep_namespace STREQUAL CSCMAKE_NAMESPACE)
        _cs_add_to_global_property_unique_value(CSCMAKE_${CSCMAKE_NAMESPACE}_COMPONENT_${export_name}_FIND_PACKAGES
                                                "${dep_namespace} COMPONENTS ${export_dep_name} REQUIRED CONFIG")
        continue()
      endif()
      cs_debug_message(
        "[_cs_populate_component_dependencies] ---- subtarget ${target_dep_name} is exported to ${export_dep_name}")
      if(NOT ${export_dep_name} STREQUAL ${export_name})
        cs_debug_message("[_cs_populate_component_dependencies] ---- add ${export_dep_name}")
        _cs_add_to_global_property_unique_value(CSCMAKE_${CSCMAKE_NAMESPACE}_COMPONENT_${export_name}_DEPENDENCIES
                                                ${export_dep_name})
      else()
        cs_debug_message("[_cs_populate_component_dependencies] ---- subtarget is in my same export set")
      endif()

    endforeach()

  endforeach()

  cs_get_component_dependencies(${export_name} dependent_exports)
  cs_debug_message(
    "[_cs_populate_component_dependencies] final result, EXPORT ${export_name} depends on EXPORTS ${dependent_exports}")
endfunction()

# Depth-first visit of the components export_name depends on (visited_list: the current path); fail on a cycle.
function(_cs_check_component_cycles_recursive export_name visited_list)
  cs_debug_message(
    "[_cs_check_component_cycles_recursive] -- for export ${export_name} with visited list = ${visited_list}")

  if(${export_name} IN_LIST visited_list)
    string(REPLACE ";" " -> " cycle "${visited_list};${export_name}")
    message(
      FATAL_ERROR "[cs_finalize_project] cyclic dependency between the components: ${cycle}: a component cannot "
                  "depend on itself through other components; move the targets so that the dependencies go one way")
  endif()

  list(APPEND visited_list ${export_name})

  cs_get_component_dependencies(${export_name} next_elements_list)
  foreach(next_element ${next_elements_list})
    cs_debug_message(
      "[_cs_check_component_cycles_recursive] -- for export ${export_name} call recursive on ${next_element} "
      "with visited list = ${visited_list}")
    _cs_check_component_cycles_recursive(${next_element} "${visited_list}")
  endforeach()

endfunction()

# Fail if the dependencies between the components reachable from export_name contain a cycle.
function(_cs_check_component_cycles export_name)
  cs_debug_message("[_cs_check_component_cycles] -- for export ${export_name}")

  set(visited_list "")
  _cs_check_component_cycles_recursive(${export_name} "${visited_list}")

endfunction()

# Sort the components export_name depends on, each one after the ones it depends on.
#
# Writes:
#
# * global property CSCMAKE_<namespace>_COMPONENT_<component>_DEPENDENCIES_SORTED
function(_cs_sort_component_dependencies export_name)
  cs_get_component_dependencies(${export_name} dependent_exports_unsorted)
  cs_debug_message("[_cs_sort_component_dependencies] -- for export ${export_name} sort ${dependent_exports_unsorted}")

  # initialize the iterative list of target to analyze
  set(dependent_exports_list ${dependent_exports_unsorted})
  list(LENGTH dependent_exports_list dependent_exports_list_size)

  cs_debug_message("[_cs_sort_component_dependencies] -- initial list has ${dependent_exports_list_size} elements: "
                   "${dependent_exports_list}")

  set(dependent_exports_sorted "")
  # loop
  while(dependent_exports_list_size GREATER 0)
    # get the first target in the list
    list(GET dependent_exports_list 0 current_element)
    # and remove it
    list(REMOVE_AT dependent_exports_list 0)

    # get the dependencies of the current element
    cs_get_component_dependencies(${current_element} current_element_dependent_exports)
    cs_debug_message("[_cs_sort_component_dependencies] ---- analyze ${current_element}, it depends on: "
                     "${current_element_dependent_exports}")

    # clean up and keep only the one not yet satisfied
    set(current_element_dependent_exports_clean "")
    foreach(temp_element ${current_element_dependent_exports})
      if(NOT ${temp_element} IN_LIST dependent_exports_sorted)
        _cs_list_add_unique_value(current_element_dependent_exports_clean ${temp_element})
      endif()
    endforeach()

    list(LENGTH current_element_dependent_exports_clean current_element_dependent_exports_clean_size)
    cs_debug_message(
      "[_cs_sort_component_dependencies] ---- analyze ${current_element}, cleaned up list of unsatisfied "
      "dependency has ${current_element_dependent_exports_clean_size} elements: "
      "${current_element_dependent_exports_clean}")

    # finally add the element itself if is a leaf, or recursive add its dependencies and itself later
    if(current_element_dependent_exports_clean_size EQUAL 0)
      cs_debug_message(
        "[_cs_sort_component_dependencies] ------ add ${current_element} to sorted list, is a leaf (no other "
        "dependencies)")
      _cs_list_add_unique_value(dependent_exports_sorted ${current_element})
    else()
      foreach(temp_element ${current_element_dependent_exports_clean})
        cs_debug_message(
          "[_cs_sort_component_dependencies] ------ add ${temp_element} to the elements to be re-evaluated")
        _cs_list_add_unique_value(dependent_exports_list ${temp_element})
      endforeach()
      cs_debug_message(
        "[_cs_sort_component_dependencies] ------ add the original ${current_element} to the elements to be "
        "re-evaluated")
      _cs_list_add_unique_value(dependent_exports_list ${current_element})
    endif()

    # finally refresh while condition variable
    list(LENGTH dependent_exports_list dependent_exports_list_size)
  endwhile()

  cs_debug_message("[_cs_sort_component_dependencies] -- sort result: ${dependent_exports_sorted}")
  set_property(GLOBAL PROPERTY CSCMAKE_${CSCMAKE_NAMESPACE}_COMPONENT_${export_name}_DEPENDENCIES_SORTED
                               "${dependent_exports_sorted}")
endfunction()

# Install the components of the project in the namespace export_namespace: their <component>Targets.cmake, the
# dependencies between them (failing on cycles), <namespace>Config.cmake and <namespace>ConfigVersion.cmake.
function(_cs_finalize_install export_namespace)
  # directory to install cmake files
  set(install_configdir ${CMAKE_INSTALL_LIBDIR}/cmake/${export_namespace})

  # get export list
  cs_get_components(exports)
  # and install cmake files of them
  foreach(name ${exports})
    install(
      EXPORT ${CSCMAKE_NAMESPACE}_${name}-targets
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
    _cs_sort_component_dependencies(${export_name})
    cs_get_component_dependencies_sorted(${export_name} ${export_name}_DEPENDENT_EXPORTS_SORTED)
    cs_debug_message("[_cs_finalize_install] -- EXPORT ${export_name} depends on other exports (sorted) "
                     "${${export_name}_DEPENDENT_EXPORTS_SORTED}")
  endforeach()

  # the components each component depends on: <namespace>_<component>_DEPENDENCIES in the Config
  set(injected_export_dependencies "")
  foreach(export_name ${exports})
    string(APPEND injected_export_dependencies "set(${export_namespace}_${export_name}_DEPENDENCIES "
           "\"${${export_name}_DEPENDENT_EXPORTS_SORTED}\")\n")
  endforeach()
  string(STRIP "${injected_export_dependencies}" injected_export_dependencies)

  # create a sanitized version of EXPORT_NAMESPACE
  string(REPLACE "-" "_" export_namespace_sanitized "${export_namespace}")

  # the find_dependency() calls of each component (body of <namespace>_find_dependency_for_component in the Config)
  set(injected_find_packages_code "")
  set(debug_message "${export_namespace_sanitized}_debug_message")
  foreach(export_name ${exports})
    cs_get_component_find_packages(${export_name} find_packages_list)
    if(find_packages_list)
      string(APPEND injected_find_packages_code "if(\"\${component_name}\" STREQUAL \"${export_name}\")\n")
      foreach(find_args ${find_packages_list})
        string(APPEND injected_find_packages_code
               "      ${debug_message}(\"[${export_namespace}Config] find_dependency(${find_args})\")\n"
               "      find_dependency(${find_args})\n")
      endforeach()
      string(APPEND injected_find_packages_code "    endif()\n    ")
    endif()
  endforeach()

  # the placeholder line of the template is indented: the first line has no leading spaces, the last one ends with the
  # indentation of the next line
  set(injected_find_packages_code "# -- find_dependency() per component --\n    ${injected_find_packages_code}# --")

  # get list of components when find_package without arguments is used
  cs_get_components(components_list)
  # get list of default components when find_package without arguments is used
  cs_get_default_components(default_components_list)

  # retrieve output folder for generated files
  cs_get_generated_dir(output_folder)

  # Write the Config.cmake file
  _cs_configure_config_cmake(
    OUTPUT_FOLDER
    "${output_folder}"
    INSTALL_CONFIGDIR
    "${install_configdir}"
    EXPORT_NAMESPACE
    "${export_namespace}"
    EXPORT_NAMESPACE_SANITIZED
    "${export_namespace_sanitized}"
    COMPONENTS_LIST
    "${components_list}"
    DEFAULT_COMPONENTS_LIST
    "${default_components_list}"
    INJECTED_FIND_PACKAGES_CODE
    "${injected_find_packages_code}"
    INJECTED_EXPORT_DEPENDENCIES
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

# Generate <OUTPUT_FOLDER>/<EXPORT_NAMESPACE>Config.cmake from templates/csTemplateConfig.cmake.in, to be installed in
# INSTALL_CONFIGDIR (relative to the install prefix). The other keywords, lowercase, are @VAR@ placeholders of the
# template. Keyword arguments, one value each (lists and code quoted): PARSE_ARGV keeps their ; and newlines.
function(_cs_configure_config_cmake)
  set(placeholders EXPORT_NAMESPACE EXPORT_NAMESPACE_SANITIZED COMPONENTS_LIST DEFAULT_COMPONENTS_LIST
                   INJECTED_FIND_PACKAGES_CODE INJECTED_EXPORT_DEPENDENCIES)
  cmake_parse_arguments(PARSE_ARGV 0 arg "" "OUTPUT_FOLDER;INSTALL_CONFIGDIR;${placeholders}" "")

  # templates/csTemplateConfig.cmake.in uses these variables as @variable@ placeholders: rename them together
  #
  # * export_namespace, export_namespace_sanitized
  # * components_list, default_components_list
  # * injected_find_packages_code, injected_export_dependencies
  # * config_dir_to_prefix
  foreach(keyword IN LISTS placeholders)
    string(TOLOWER "${keyword}" placeholder)
    set(${placeholder} "${arg_${keyword}}")
  endforeach()

  # path from the installed Config folder to the install prefix (e.g. ../../.. for lib/cmake/<namespace>) (computed
  # against an absolute folder, the build folder: "/" is not absolute on Windows)
  file(RELATIVE_PATH config_dir_to_prefix "${CMAKE_BINARY_DIR}/${arg_INSTALL_CONFIGDIR}" "${CMAKE_BINARY_DIR}")

  _cs_get_root_dir(base_path)
  configure_file("${base_path}/templates/csTemplateConfig.cmake.in"
                 "${arg_OUTPUT_FOLDER}/${export_namespace}Config.cmake" @ONLY)

endfunction()

#.rst:
# .. command:: cs_get_component_targets
#
#   Return the targets of a component.
#
#   .. code-block:: cmake
#
#     cs_get_component_targets(<component> <out-var>)
#
#   ``<component>``
#     A component of the project (:command:`cs_install_target`).
#
#   ``<out-var>``
#     The variable to set, in the scope of the caller.
#
#   :Reads: :prop_gbl:`CSCMAKE_<namespace>_COMPONENT_<component>_TARGETS`
function(cs_get_component_targets export_name output_variable_name)
  get_property(list_values GLOBAL PROPERTY CSCMAKE_${CSCMAKE_NAMESPACE}_COMPONENT_${export_name}_TARGETS)
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

#.rst:
# .. command:: cs_get_component_dependencies
#
#   Return the components a component depends on.
#
#   .. code-block:: cmake
#
#     cs_get_component_dependencies(<component> <out-var>)
#
#   ``<component>``
#     A component of the project (:command:`cs_install_target`).
#
#   ``<out-var>``
#     The variable to set, in the scope of the caller.
#
#   :Reads: :prop_gbl:`CSCMAKE_<namespace>_COMPONENT_<component>_DEPENDENCIES`
function(cs_get_component_dependencies export_name output_variable_name)
  get_property(list_values GLOBAL PROPERTY CSCMAKE_${CSCMAKE_NAMESPACE}_COMPONENT_${export_name}_DEPENDENCIES)
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

#.rst:
# .. command:: cs_get_component_dependencies_sorted
#
#   Return the components a component depends on, each one after the ones it depends on (computed by
#   :command:`cs_finalize_project`).
#
#   .. code-block:: cmake
#
#     cs_get_component_dependencies_sorted(<component> <out-var>)
#
#   ``<component>``
#     A component of the project (:command:`cs_install_target`).
#
#   ``<out-var>``
#     The variable to set, in the scope of the caller.
#
#   :Reads: :prop_gbl:`CSCMAKE_<namespace>_COMPONENT_<component>_DEPENDENCIES_SORTED`
function(cs_get_component_dependencies_sorted export_name output_variable_name)
  get_property(list_values GLOBAL PROPERTY CSCMAKE_${CSCMAKE_NAMESPACE}_COMPONENT_${export_name}_DEPENDENCIES_SORTED)
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

#.rst:
# .. command:: cs_get_component_find_packages
#
#   Return the :command:`find_package` arguments propagated by a component (:command:`find_dependency` in the installed
#   package).
#
#   .. code-block:: cmake
#
#     cs_get_component_find_packages(<component> <out-var>)
#
#   ``<component>``
#     A component of the project (:command:`cs_install_target`).
#
#   ``<out-var>``
#     The variable to set, in the scope of the caller.
#
#   :Reads: :prop_gbl:`CSCMAKE_<namespace>_COMPONENT_<component>_FIND_PACKAGES`
function(cs_get_component_find_packages export_name output_variable_name)
  get_property(list_values GLOBAL PROPERTY CSCMAKE_${CSCMAKE_NAMESPACE}_COMPONENT_${export_name}_FIND_PACKAGES)
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

#.rst:
# .. command:: cs_print_components
#
#   Print the components of the project with their targets, :command:`find_package` arguments and dependencies (debug
#   messages).
#
#   .. code-block:: cmake
#
#     cs_print_components()
function(cs_print_components)
  cs_get_components(exports)
  foreach(export ${exports})
    cs_get_component_targets(${export} targets_values)
    cs_get_component_find_packages(${export} find_packages_values)
    cs_get_component_dependencies(${export} depends_values)
    cs_get_component_dependencies_sorted(${export} depends_values_sorted)
    cs_debug_message(
      "[cs_print_components] export ${export} contains the following targets: ${targets_values}, has the "
      "following find_packages: ${find_packages_values} and depends on those other exports: ${depends_values} "
      "(sorted as ${depends_values_sorted})")
  endforeach()

  cs_get_default_components(exports_default)
  cs_debug_message("[cs_print_components] default components: ${exports_default}")
endfunction()

#.rst:
# Target properties
# ^^^^^^^^^^^^^^^^^
#
# .. prop_tgt:: CSCMAKE_COMPONENT
#
#   The component of the target (:command:`cs_install_target`).
#
# Global properties
# ^^^^^^^^^^^^^^^^^
#
# .. prop_gbl:: CSCMAKE_<namespace>_COMPONENTS
#
#   The components of the project.
#
# .. prop_gbl:: CSCMAKE_<namespace>_DEFAULT_COMPONENTS
#
#   The components loaded by ``find_package(<namespace>)`` without ``COMPONENTS``.
#
# .. prop_gbl:: CSCMAKE_<namespace>_COMPONENT_<component>_TARGETS
#
#   The targets of a component.
#
# .. prop_gbl:: CSCMAKE_<namespace>_COMPONENT_<component>_FIND_PACKAGES
#
#   The :command:`find_package` arguments of a component: ``find_dependency`` calls of the installed package.
#
# .. prop_gbl:: CSCMAKE_<namespace>_COMPONENT_<component>_DEPENDENCIES
#
#   The components a component depends on.
#
# .. prop_gbl:: CSCMAKE_<namespace>_COMPONENT_<component>_DEPENDENCIES_SORTED
#
#   The same, each one after the ones it depends on.
