include_guard(GLOBAL)
include(utils/csDebugMessage)

# support the three types as in target_sources PRIVATE PUBLIC INTERFACE however, supports PRIVATE_INSTALL PUBLIC_INSTALL
# INTERFACE_INSTALL to add the files to a list of file to be installed when the target is installed note: includes does
# not need to be PUBLIC, therefore, normally only PRIVATE and PRIVATE_INSTALL are used it adds all headers to be
# installed to the target a property CSCMAKE_SOURCES_TO_INSTALL so that can be easily retrieved
function(cs_target_sources target_name)
  cs_debug_message("[cs_target_sources] target ${target_name} find ${ARGN}")

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
  file(RELATIVE_PATH destination_folder ${CMAKE_SOURCE_DIR} ${CMAKE_CURRENT_LIST_DIR})
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

# return the CSCMAKE_SOURCES_TO_INSTALL property of the target, i.e., a list, eventually empty
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

# return the CSCMAKE_SOURCES_TO_INSTALL_ABSOLUTE property of the target, i.e., a list, eventually empty
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

# Print (debug) the sources of target_name queued for installation, as relative and as absolute paths.
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
