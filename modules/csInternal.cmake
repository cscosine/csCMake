# Internal helpers of csCMake: lists, properties, paths.
include_guard(GLOBAL)

# Append value to the list variable list_name of the caller, unless already present.
function(_cs_list_add_unique_value list_name value)
  set(output_list ${${list_name}})
  if(NOT "${value}" IN_LIST output_list)
    list(APPEND output_list ${value})
  endif()
  set(${list_name} ${output_list} PARENT_SCOPE)
endfunction()

# Append value to the list property property_name of target_name, unless already present.
function(_cs_add_to_target_property_unique_value target_name property_name value)
  get_target_property(list_values ${target_name} ${property_name})
  if(NOT "${value}" IN_LIST list_values)
    set_property(TARGET ${target_name} APPEND PROPERTY ${property_name} ${value})
  endif()
endfunction()

# Append value to the global list property property_name, unless already present.
function(_cs_add_to_global_property_unique_value property_name value)
  get_property(list_values GLOBAL PROPERTY ${property_name})
  if(NOT "${value}" IN_LIST list_values)
    set_property(GLOBAL APPEND PROPERTY ${property_name} ${value})
  endif()
endfunction()

# Normalize (cmake_path NORMALIZE) every path of the list variable input_list_name of the caller.
function(_cs_path_list_normalize input_list_name)
  set(output_list "")
  foreach(path_item IN ITEMS ${${input_list_name}})
    cmake_path(SET normalized_path NORMALIZE "${path_item}")
    list(APPEND output_list ${normalized_path})
  endforeach()
  set(${input_list_name} ${output_list} PARENT_SCOPE)
endfunction()

# Set out to the folder of CMAKE_CURRENT_SOURCE_DIR relative to the folder of cs_initialize_project (empty there): the
# install folder of the headers of the current folder, below the include folder.
#
# Reads:
#
# * variable CSCMAKE_SOURCE_DIR
function(_cs_relative_install_folder out)
  file(RELATIVE_PATH folder "${CSCMAKE_SOURCE_DIR}" "${CMAKE_CURRENT_SOURCE_DIR}")
  set(${out} "${folder}" PARENT_SCOPE)
endfunction()

# Set out to TRUE when the headers are installed per configuration (include/<CONFIG>): the project has several
# configurations, with any generator.
#
# Reads:
#
# * global property CSCMAKE_BUILD_CONFIGURATIONS
function(_cs_headers_per_configuration out)
  get_property(configs_list GLOBAL PROPERTY CSCMAKE_BUILD_CONFIGURATIONS)
  list(LENGTH configs_list count)
  if(count GREATER 1)
    set(${out} TRUE PARENT_SCOPE)
  else()
    set(${out} FALSE PARENT_SCOPE)
  endif()
endfunction()
