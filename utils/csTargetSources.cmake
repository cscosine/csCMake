# Sources of the targets, and the ones installed with them (headers): cs_target_sources.
include_guard(GLOBAL)
include(utils/csDebugMessage)

# Add sources to a target, like target_sources, and queue the ones to install with it.
#
# cs_target_sources(<target> [PRIVATE|PUBLIC|INTERFACE <file>...] [PRIVATE_INSTALL|PUBLIC_INSTALL|INTERFACE_INSTALL
# <file>...] [PRIVATE_INSTALL_ABSOLUTE_PATH|PUBLIC_INSTALL_ABSOLUTE_PATH|INTERFACE_INSTALL_ABSOLUTE_PATH <file>...])
#
# Every file is a source of the target in the build tree, with the given scope. The *_INSTALL files (usually headers,
# relative to the current folder) are installed by cs_install_target, keeping their path relative to the folder of
# cs_initialize_project; the *_INSTALL_ABSOLUTE_PATH files (absolute paths, e.g. generated headers) are installed in the
# include folder of the current folder. Headers do not need to be PUBLIC: PRIVATE and PRIVATE_INSTALL are usual.
#
# Arguments:
#
# * target: a target of the project
# * PRIVATE, PUBLIC, INTERFACE: sources, as in target_sources
# * PRIVATE_INSTALL, PUBLIC_INSTALL, INTERFACE_INSTALL: sources installed with the target
# * PRIVATE_INSTALL_ABSOLUTE_PATH, PUBLIC_INSTALL_ABSOLUTE_PATH, INTERFACE_INSTALL_ABSOLUTE_PATH: sources given by
#   absolute path, installed with the target
#
# Reads:
#
# * variable CSCMAKE_SOURCE_DIR
#
# Writes:
#
# * target property CSCMAKE_SOURCES_TO_INSTALL: the *_INSTALL files
# * target property CSCMAKE_SOURCES_TO_INSTALL_ABSOLUTE: the *_INSTALL_ABSOLUTE_PATH files
function(cs_target_sources target_name)
  cs_debug_message("[cs_target_sources] target ${target_name}: ${ARGN}")

  # split arguments in groups according to keywords
  set(keywords
      PRIVATE
      PUBLIC
      INTERFACE
      PRIVATE_INSTALL
      PUBLIC_INSTALL
      INTERFACE_INSTALL
      PRIVATE_INSTALL_ABSOLUTE_PATH
      PUBLIC_INSTALL_ABSOLUTE_PATH
      INTERFACE_INSTALL_ABSOLUTE_PATH)
  cmake_parse_arguments(arg "" "" "${keywords}" ${ARGN})

  # retrieve the relative install path
  file(RELATIVE_PATH destination_folder ${CSCMAKE_SOURCE_DIR} ${CMAKE_CURRENT_SOURCE_DIR})
  cs_debug_message("[cs_target_sources] relative install path is ${destination_folder}")

  # get the different groups
  foreach(base_type IN ITEMS PRIVATE PUBLIC INTERFACE)

    # add the files not to be installed
    cs_debug_message("[cs_target_sources] arg_${base_type} contains ${arg_${base_type}}")
    foreach(file_path ${arg_${base_type}})
      target_sources(${target_name} ${base_type} $<BUILD_INTERFACE:${file_path}>)
    endforeach()

    # add the files to be installed
    cs_debug_message("[cs_target_sources] arg_${base_type}_INSTALL contains ${arg_${base_type}_INSTALL}")
    foreach(file_path ${arg_${base_type}_INSTALL})
      target_sources(${target_name} ${base_type} $<BUILD_INTERFACE:${file_path}>)
      _cs_add_to_target_property_unique_value(${target_name} CSCMAKE_SOURCES_TO_INSTALL "${file_path}")
    endforeach()

    # add the files to be installed from absolute path
    cs_debug_message(
      "[cs_target_sources] arg_${base_type}_INSTALL_ABSOLUTE_PATH contains ${arg_${base_type}_INSTALL_ABSOLUTE_PATH}")
    foreach(file_path ${arg_${base_type}_INSTALL_ABSOLUTE_PATH})
      target_sources(${target_name} ${base_type} $<BUILD_INTERFACE:${file_path}>)
      _cs_add_to_target_property_unique_value(${target_name} CSCMAKE_SOURCES_TO_INSTALL_ABSOLUTE "${file_path}")
    endforeach()

  endforeach()
endfunction()

# Return the sources of a target installed with it, relative to its folder.
#
# cs_get_target_sources_to_install(<target> <out-var>)
#
# Reads:
#
# * target property CSCMAKE_SOURCES_TO_INSTALL
function(cs_get_target_sources_to_install target_name output_variable_name)
  get_target_property(list_values ${target_name} CSCMAKE_SOURCES_TO_INSTALL)
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

# Return the sources of a target installed with it, given by absolute path.
#
# cs_get_target_sources_to_install_absolute_path(<target> <out-var>)
#
# Reads:
#
# * target property CSCMAKE_SOURCES_TO_INSTALL_ABSOLUTE
function(cs_get_target_sources_to_install_absolute_path target_name output_variable_name)
  get_target_property(list_values ${target_name} CSCMAKE_SOURCES_TO_INSTALL_ABSOLUTE)
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

# Print the sources of a target installed with it (debug messages).
#
# cs_print_target_sources_to_install(<target>)
#
# Reads:
#
# * target property CSCMAKE_SOURCES_TO_INSTALL
# * target property CSCMAKE_SOURCES_TO_INSTALL_ABSOLUTE
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
