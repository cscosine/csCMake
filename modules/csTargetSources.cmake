#.rst:
# csTargetSources
# ---------------
#
# The sources of the targets, and the ones installed with them (headers).
#
# Commands
# ^^^^^^^^
include_guard(GLOBAL)
include(modules/csDebug)

#.rst:
# .. command:: cs_target_sources
#
#   Add sources to a target, like :command:`target_sources`, and queue the ones to install with it.
#
#   .. code-block:: cmake
#
#     cs_target_sources(<target>
#       [PRIVATE|PUBLIC|INTERFACE <file>...]
#       [PRIVATE_INSTALL|PUBLIC_INSTALL|INTERFACE_INSTALL <file>...]
#       [PRIVATE_INSTALL_ABSOLUTE_PATH|PUBLIC_INSTALL_ABSOLUTE_PATH|INTERFACE_INSTALL_ABSOLUTE_PATH <file>...])
#
#   Every file is a source of the target in the build tree, with the given scope (a relative path is relative to the
#   current folder). Headers do not need to be ``PUBLIC``: ``PRIVATE`` and ``PRIVATE_INSTALL`` are usual.
#
#   ``<target>``
#     A target of the project.
#
#   ``PRIVATE``, ``PUBLIC``, ``INTERFACE``
#     Sources, as in :command:`target_sources`.
#
#   ``PRIVATE_INSTALL``, ``PUBLIC_INSTALL``, ``INTERFACE_INSTALL``
#     Sources installed with the target by :command:`cs_install_target` (usually headers, relative to the current
#     folder), keeping their path relative to the folder of :command:`cs_initialize_project`.
#
#   ``PRIVATE_INSTALL_ABSOLUTE_PATH``, ``PUBLIC_INSTALL_ABSOLUTE_PATH``, ``INTERFACE_INSTALL_ABSOLUTE_PATH``
#     Sources given by absolute path (e.g. generated headers), installed with the target in the include folder of the
#     current folder.
#
#   :Reads: :variable:`CSCMAKE_SOURCE_DIR`
#   :Writes: :prop_tgt:`CSCMAKE_SOURCES_TO_INSTALL`, :prop_tgt:`CSCMAKE_SOURCES_TO_INSTALL_ABSOLUTE`
function(cs_target_sources target_name)
  cs_debug_message("[cs_target_sources] target ${target_name}: ${ARGN}")

  # split arguments in groups according to keywords
  set(
    keywords
    PRIVATE
    PUBLIC
    INTERFACE
    PRIVATE_INSTALL
    PUBLIC_INSTALL
    INTERFACE_INSTALL
    PRIVATE_INSTALL_ABSOLUTE_PATH
    PUBLIC_INSTALL_ABSOLUTE_PATH
    INTERFACE_INSTALL_ABSOLUTE_PATH
  )
  cmake_parse_arguments(arg "" "" "${keywords}" ${ARGN})

  # retrieve the relative install path
  file(RELATIVE_PATH destination_folder ${CSCMAKE_SOURCE_DIR} ${CMAKE_CURRENT_SOURCE_DIR})
  cs_debug_message("[cs_target_sources] relative install path is ${destination_folder}")

  # get the different groups
  foreach(base_type IN ITEMS PRIVATE PUBLIC INTERFACE)
    # add the files not to be installed
    cs_debug_message("[cs_target_sources] arg_${base_type} contains ${arg_${base_type}}")
    foreach(file_path ${arg_${base_type}})
      # absolute: CMake rejects relative paths in the INTERFACE_SOURCES of PUBLIC / INTERFACE ones
      cmake_path(ABSOLUTE_PATH file_path BASE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" OUTPUT_VARIABLE build_path)
      target_sources(${target_name} ${base_type} $<BUILD_INTERFACE:${build_path}>)
    endforeach()

    # add the files to be installed
    cs_debug_message("[cs_target_sources] arg_${base_type}_INSTALL contains ${arg_${base_type}_INSTALL}")
    foreach(file_path ${arg_${base_type}_INSTALL})
      # absolute: CMake rejects relative paths in the INTERFACE_SOURCES of PUBLIC / INTERFACE ones
      cmake_path(ABSOLUTE_PATH file_path BASE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" OUTPUT_VARIABLE build_path)
      target_sources(${target_name} ${base_type} $<BUILD_INTERFACE:${build_path}>)
      _cs_add_to_target_property_unique_value(${target_name} CSCMAKE_SOURCES_TO_INSTALL "${file_path}")
    endforeach()

    # add the files to be installed from absolute path
    cs_debug_message(
      "[cs_target_sources] arg_${base_type}_INSTALL_ABSOLUTE_PATH contains ${arg_${base_type}_INSTALL_ABSOLUTE_PATH}"
    )
    foreach(file_path ${arg_${base_type}_INSTALL_ABSOLUTE_PATH})
      # absolute: CMake rejects relative paths in the INTERFACE_SOURCES of PUBLIC / INTERFACE ones
      cmake_path(ABSOLUTE_PATH file_path BASE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" OUTPUT_VARIABLE build_path)
      target_sources(${target_name} ${base_type} $<BUILD_INTERFACE:${build_path}>)
      _cs_add_to_target_property_unique_value(${target_name} CSCMAKE_SOURCES_TO_INSTALL_ABSOLUTE "${file_path}")
    endforeach()
  endforeach()
endfunction()

#.rst:
# .. command:: cs_get_target_sources_to_install
#
#   Return the sources of a target installed with it, relative to its folder.
#
#   .. code-block:: cmake
#
#     cs_get_target_sources_to_install(<target> <out-var>)
#
#   ``<target>``
#     A target of the project.
#
#   ``<out-var>``
#     The variable to set, in the scope of the caller.
#
#   :Reads: :prop_tgt:`CSCMAKE_SOURCES_TO_INSTALL`
function(cs_get_target_sources_to_install target_name output_variable_name)
  # empty when the property is not set
  get_property(list_values TARGET ${target_name} PROPERTY CSCMAKE_SOURCES_TO_INSTALL)
  set(${output_variable_name} "${list_values}" PARENT_SCOPE)
endfunction()

#.rst:
# .. command:: cs_get_target_sources_to_install_absolute_path
#
#   Return the sources of a target installed with it, given by absolute path.
#
#   .. code-block:: cmake
#
#     cs_get_target_sources_to_install_absolute_path(<target> <out-var>)
#
#   ``<target>``
#     A target of the project.
#
#   ``<out-var>``
#     The variable to set, in the scope of the caller.
#
#   :Reads: :prop_tgt:`CSCMAKE_SOURCES_TO_INSTALL_ABSOLUTE`
function(cs_get_target_sources_to_install_absolute_path target_name output_variable_name)
  # empty when the property is not set
  get_property(list_values TARGET ${target_name} PROPERTY CSCMAKE_SOURCES_TO_INSTALL_ABSOLUTE)
  set(${output_variable_name} "${list_values}" PARENT_SCOPE)
endfunction()

#.rst:
# .. command:: cs_print_target_sources_to_install
#
#   Print the sources of a target installed with it (debug messages of the project).
#
#   .. code-block:: cmake
#
#     cs_print_target_sources_to_install(<target>)
#
#   ``<target>``
#     A target of the project.
#
#   :Reads: :prop_tgt:`CSCMAKE_SOURCES_TO_INSTALL`, :prop_tgt:`CSCMAKE_SOURCES_TO_INSTALL_ABSOLUTE`
function(cs_print_target_sources_to_install target_name)
  set(values "")

  cs_get_target_sources_to_install("${target_name}" values)
  list(LENGTH values count)
  if(count GREATER 0)
    cs_debug_message("cs_print_target_sources_to_install ${target_name}: ${values}")
  else()
    cs_debug_message("cs_print_target_sources_to_install ${target_name}: empty")
  endif()

  cs_get_target_sources_to_install_absolute_path("${target_name}" values)
  list(LENGTH values count)
  if(count GREATER 0)
    cs_debug_message("cs_print_target_sources_to_install (absolute path) ${target_name}: ${values}")
  else()
    cs_debug_message("cs_print_target_sources_to_install (absolute path) ${target_name}: empty")
  endif()
endfunction()

#.rst:
# Target properties
# ^^^^^^^^^^^^^^^^^
#
# .. prop_tgt:: CSCMAKE_SOURCES_TO_INSTALL
#
#   The sources of the target installed with it (``*_INSTALL`` of :command:`cs_target_sources`), relative to the
#   folder of the target.
#
# .. prop_tgt:: CSCMAKE_SOURCES_TO_INSTALL_ABSOLUTE
#
#   The sources of the target installed with it, given by absolute path (``*_INSTALL_ABSOLUTE_PATH`` of
#   :command:`cs_target_sources`).
