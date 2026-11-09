include_guard(GLOBAL)
include(utils/csDebugMessage)
include(utils/csListUtils)

# propagate_mode: PUBLIC or PRIVATE - PUBLIC will propagate the very same line as a find_package in the cmake prepared
# for installation - PROVATE will not propagate the very same line as a find_package in the cmake prepared for
# installation
macro(cs_find_package target_name propagate_mode)
  cs_debug_message("[cs_find_package] target ${target_name} find ${ARGN} with mode ${propagate_mode}")

  # this has to be a macro, because some find_package out variable needs to be visible to the caller
  find_package(${ARGN})
  _cs_add_find_package_args_to_target("${target_name}" "${propagate_mode}" "${ARGN}")
endmacro()

# return the CSCMAKE_FIND_PACKAGES property of the target, i.e., a list, eventually empty
function(cs_get_target_find_packages target_name output_variable_name)
  get_target_property(list_values ${target_name} CSCMAKE_FIND_PACKAGES)
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

# Print (debug) the find_package arguments recorded as PUBLIC for target_name (see cs_find_package).
function(cs_print_target_find_packages target_name)
  set(packages "")
  cs_get_target_find_packages("${target_name}" packages)
  list(LENGTH packages count)
  if(count GREATER 0)
    cs_debug_message("cs_print_target_find_packages ${target_name}: ${packages}")
  else()
    cs_debug_message("cs_print_target_find_packages ${target_name} empty")
  endif()
endfunction()

# append to CSCMAKE_FIND_PACKAGES property of the target
function(_cs_add_find_package_args_to_target target_name propagate_mode)
  list(JOIN ARGN " " joined_argn)
  cs_debug_message("[_cs_add_find_package_args_to_target] target ${target_name} arguments ${joined_argn}")

  if(propagate_mode STREQUAL "PUBLIC")
    _cs_add_to_target_property_unique_value("${target_name}" CSCMAKE_FIND_PACKAGES "${joined_argn}")
  elseif(propagate_mode STREQUAL "PRIVATE")
    # nothin to do
  else()
    message(
      FATAL_ERROR
        "cs_find_package PROPAGATE_MODE should be PUBLIC or PRIVATE, other values are not supported (called with PROPAGATE_MODE=${propagate_mode})"
    )
  endif()
endfunction()
