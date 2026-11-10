#.rst:
# csInstall
# ---------
#
# Installation: the targets and their headers in the components of the package of the project
# (:command:`cs_install_target`), the install RPATH of the targets. The dependencies between the
# components and the generated ``<namespace>Config.cmake``: :doc:`csPackageConfig`.
#
# Commands
# ^^^^^^^^

include_guard(GLOBAL)
include(modules/csFindPackage)
include(modules/csInternal)
include(modules/csBaseInclude)
include(modules/csTargetDependencies)

include(GNUInstallDirs)

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
  _cs_headers_per_configuration(per_configuration)
  if(per_configuration)
    # includes are installed per configuration, independently if we are with a multi generator or a single one
    set(folder "${CMAKE_INSTALL_INCLUDEDIR}/$<CONFIG>")
    set(${install_folder_expression} "${folder}" PARENT_SCOPE)
  else()
    set(folder "${CMAKE_INSTALL_INCLUDEDIR}")
    set(${install_folder_expression} "${folder}" PARENT_SCOPE)
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
  _cs_relative_install_folder(destination_folder)

  # add the EXPORT_NAME to the list of exports
  _cs_add_to_global_property_unique_value(CSCMAKE_${CSCMAKE_NAMESPACE}_COMPONENTS ${export_name})

  # add the target to default list
  if("${ARGC}" EQUAL 2)
    # nothing to do, do not
  elseif("${ARGC}" EQUAL 3)
    if("${ARGV2}" STREQUAL "DEFAULT")
      _cs_add_to_global_property_unique_value(CSCMAKE_${CSCMAKE_NAMESPACE}_DEFAULT_COMPONENTS ${export_name})
    else()
      message(FATAL_ERROR "cs_install_target argument 3 should be DEFAULT or should be empty")
    endif()
  else()
    message(FATAL_ERROR "cs_install_target expects 2 or 3 arguments")
  endif()

  # retrieve the source files that have to be installed
  _cs_get_target_sources_to_install(${target_name} files_to_install)
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
  _cs_get_target_sources_to_install_absolute_path(${target_name} files_to_install)
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
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  )

  # and install the pdb file for debugging if exists
  if(WIN32)
    get_target_property(target_type ${target_name} TYPE)
    if(("${target_type}" STREQUAL "SHARED_LIBRARY" OR "${target_type}" STREQUAL "EXECUTABLE"))
      install(FILES $<TARGET_PDB_FILE:${target_name}> DESTINATION ${CMAKE_INSTALL_BINDIR} OPTIONAL)
    endif()
  endif()

  # add the target to the list of target of this export
  _cs_add_to_global_property_unique_value(CSCMAKE_${CSCMAKE_NAMESPACE}_COMPONENT_${export_name}_TARGETS ${target_name})

  # get all the find_packages propagated for this target
  _cs_get_target_find_packages(${target_name} find_packages_list)
  foreach(find_package ${find_packages_list})
    _cs_add_to_global_property_unique_value(CSCMAKE_${CSCMAKE_NAMESPACE}_COMPONENT_${export_name}_FIND_PACKAGES
                                            ${find_package}
    )
  endforeach()
endfunction()

# Set the install RPATH of target_name, an executable or a shared or module library, on Linux and macOS: relative to the
# binary ($ORIGIN, @loader_path), towards CMAKE_INSTALL_LIBDIR. Nothing when the target has its own INSTALL_RPATH (not
# empty) or CSCMAKE_INSTALL_RPATH is OFF.
#
# Writes:
#
# * target property INSTALL_RPATH
function(_cs_set_install_rpath target_name)
  if(WIN32 OR (DEFINED CSCMAKE_INSTALL_RPATH AND NOT CSCMAKE_INSTALL_RPATH))
    return()
  endif()
  get_target_property(target_type ${target_name} TYPE)
  # initialized by CMake from CMAKE_INSTALL_RPATH (empty when not set)
  get_target_property(own_rpath ${target_name} INSTALL_RPATH)
  if(own_rpath OR NOT target_type MATCHES "^(EXECUTABLE|SHARED_LIBRARY|MODULE_LIBRARY)$")
    return()
  endif()

  if(APPLE)
    set(origin "@loader_path")
  else()
    set(origin "$ORIGIN")
  endif()
  # an executable is installed in CMAKE_INSTALL_BINDIR, a library next to the other libraries
  if(target_type STREQUAL "EXECUTABLE")
    file(RELATIVE_PATH bin_to_lib "/${CMAKE_INSTALL_BINDIR}" "/${CMAKE_INSTALL_LIBDIR}")
    set(rpath "${origin}/${bin_to_lib}")
  else()
    set(rpath "${origin}")
  endif()
  cs_debug_message("[cs_finalize_target] ${target_name} INSTALL_RPATH ${rpath}")
  set_property(TARGET ${target_name} PROPERTY INSTALL_RPATH "${rpath}")
endfunction()

# Return the components of the project.
#
# Reads:
#
# * global property CSCMAKE_<namespace>_COMPONENTS
function(_cs_get_components output_variable_name)
  # empty when the property is not set
  get_property(list_values GLOBAL PROPERTY CSCMAKE_${CSCMAKE_NAMESPACE}_COMPONENTS)
  set(${output_variable_name} "${list_values}" PARENT_SCOPE)
endfunction()

# Return the default components of the project (loaded by :command:`find_package` without COMPONENTS).
#
# Reads:
#
# * global property CSCMAKE_<namespace>_DEFAULT_COMPONENTS
function(_cs_get_default_components output_variable_name)
  # empty when the property is not set
  get_property(list_values GLOBAL PROPERTY CSCMAKE_${CSCMAKE_NAMESPACE}_DEFAULT_COMPONENTS)
  set(${output_variable_name} "${list_values}" PARENT_SCOPE)
endfunction()

# Return the component of a target (:command:`cs_install_target`).
#
# Reads:
#
# * target property CSCMAKE_COMPONENT
function(_cs_get_target_component target_name output_variable_name)
  get_target_property(value ${target_name} CSCMAKE_COMPONENT)
  set(${output_variable_name} ${value} PARENT_SCOPE)
endfunction()

# Return the targets of a component.
#
# Reads:
#
# * global property CSCMAKE_<namespace>_COMPONENT_<component>_TARGETS
function(_cs_get_component_targets export_name output_variable_name)
  # empty when the property is not set
  get_property(list_values GLOBAL PROPERTY CSCMAKE_${CSCMAKE_NAMESPACE}_COMPONENT_${export_name}_TARGETS)
  set(${output_variable_name} "${list_values}" PARENT_SCOPE)
endfunction()

# Return the :command:`find_package` arguments propagated by a component (:command:`find_dependency` in the installed
# package).
#
# Reads:
#
# * global property CSCMAKE_<namespace>_COMPONENT_<component>_FIND_PACKAGES
function(_cs_get_component_find_packages export_name output_variable_name)
  # empty when the property is not set
  get_property(list_values GLOBAL PROPERTY CSCMAKE_${CSCMAKE_NAMESPACE}_COMPONENT_${export_name}_FIND_PACKAGES)
  set(${output_variable_name} "${list_values}" PARENT_SCOPE)
endfunction()

# Print the components of the project with their targets, :command:`find_package` arguments and dependencies (debug
# messages).
function(_cs_print_components)
  _cs_get_components(exports)
  foreach(export ${exports})
    _cs_get_component_targets(${export} targets_values)
    _cs_get_component_find_packages(${export} find_packages_values)
    _cs_get_component_dependencies(${export} depends_values)
    _cs_get_component_dependencies_sorted(${export} depends_values_sorted)
    cs_debug_message(
      "[_cs_print_components] export ${export} contains the following targets: ${targets_values}, has the "
      "following find_packages: ${find_packages_values} and depends on those other exports: ${depends_values} "
      "(sorted as ${depends_values_sorted})"
    )
  endforeach()

  _cs_get_default_components(exports_default)
  cs_debug_message("[_cs_print_components] default components: ${exports_default}")
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
