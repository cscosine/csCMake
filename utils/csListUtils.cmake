include_guard(GLOBAL)

# Append each element of values to the list variable list_name of the caller, skipping elements already present.
function(_cs_list_add_list_unique_values list_name values)
  if(values)
    set(output_list ${${list_name}})
    foreach(value IN ITEMS ${values})
      _cs_list_add_unique_value(output_list ${value})
    endforeach()
    set(${list_name}
        ${output_list}
        PARENT_SCOPE)
  endif()
endfunction()

# Append value to the list variable list_name of the caller, unless already present.
function(_cs_list_add_unique_value list_name value)
  set(output_list ${${list_name}})
  if(NOT ${value} IN_LIST output_list)
    list(APPEND output_list ${value})
  endif()
  set(${list_name}
      ${output_list}
      PARENT_SCOPE)
endfunction()

# Append value to the list property property_name of target_name, unless already present.
function(_cs_add_to_target_property_unique_value target_name property_name value)
  get_target_property(list_values ${target_name} ${property_name})
  if(NOT ${value} IN_LIST list_values)
    set_property(
      TARGET ${target_name}
      APPEND
      PROPERTY ${property_name} ${value})
  endif()
endfunction()

# Append value to the global list property property_name, unless already present.
function(_cs_add_to_global_property_unique_value property_name value)
  get_property(list_values GLOBAL PROPERTY ${property_name})
  if(NOT ${value} IN_LIST list_values)
    set_property(GLOBAL APPEND PROPERTY ${property_name} ${value})
  endif()
endfunction()
