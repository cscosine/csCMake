# Internal helpers of csCMake: lists, properties, paths.
include_guard(GLOBAL)

# Append each element of values to the list variable list_name of the caller, skipping the ones already present.
function(_cs_list_add_list_unique_values list_name values)
  if(values)
    set(output_list ${${list_name}})
    foreach(value IN ITEMS ${values})
      _cs_list_add_unique_value(output_list ${value})
    endforeach()
    set(${list_name} ${output_list} PARENT_SCOPE)
  endif()
endfunction()

# Append value to the list variable list_name of the caller, unless already present.
function(_cs_list_add_unique_value list_name value)
  set(output_list ${${list_name}})
  if(NOT ${value} IN_LIST output_list)
    list(APPEND output_list ${value})
  endif()
  set(${list_name} ${output_list} PARENT_SCOPE)
endfunction()

# Append value to the list property property_name of target_name, unless already present.
function(_cs_add_to_target_property_unique_value target_name property_name value)
  get_target_property(list_values ${target_name} ${property_name})
  if(NOT ${value} IN_LIST list_values)
    set_property(TARGET ${target_name} APPEND PROPERTY ${property_name} ${value})
  endif()
endfunction()

# Append value to the global list property property_name, unless already present.
function(_cs_add_to_global_property_unique_value property_name value)
  get_property(list_values GLOBAL PROPERTY ${property_name})
  if(NOT ${value} IN_LIST list_values)
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

# Return in out_list the unique parent folders of the files given after it.
function(_cs_unique_parent_dirs out_list)
  set(out_tmp "")
  foreach(file_path ${ARGN})
    get_filename_component(dir_path "${file_path}" DIRECTORY)
    _cs_list_add_unique_value(out_tmp ${dir_path})
  endforeach()
  set(${out_list} ${out_tmp} PARENT_SCOPE)
endfunction()
