#.rst:
# csDebugUtils
# ------------
#
# Debug helpers.
#
# Commands
# ^^^^^^^^
include_guard(GLOBAL)

#.rst:
# .. command:: cs_print_target_properties
#
#   Print the properties set on a target (debug messages).
#
#   .. code-block:: cmake
#
#     cs_print_target_properties(<target>)
#
#   Every property CMake knows (cmake --help-property-list), with <CONFIG> expanded to each configuration of the build
#   and <LANG> to CXX.
#
#   ``<target>``
#     A target.
function(cs_print_target_properties tgt)
  cs_debug_message("cs_print_target_properties ${tgt}")
  if(NOT TARGET ${tgt})
    cs_debug_message("There is no target named '${tgt}'")
    return()
  endif()

  # every property that cmake supports, as a CMake list
  execute_process(COMMAND ${CMAKE_COMMAND} --help-property-list OUTPUT_VARIABLE property_list)
  string(REGEX REPLACE ";" "\\\\;" property_list "${property_list}")
  string(REGEX REPLACE "\n" ";" property_list "${property_list}")

  # LOCATION* properties cannot be read any more
  list(FILTER property_list EXCLUDE REGEX "^LOCATION$|^LOCATION_|_LOCATION$")

  # expand the placeholders
  cs_get_build_configurations(configs_list)
  set(expanded_list "")
  foreach(prop ${property_list})
    string(REPLACE "<LANG>" "CXX" prop "${prop}")
    if(prop MATCHES "<CONFIG>")
      foreach(config ${configs_list})
        string(TOUPPER "${config}" config_ucase)
        string(REPLACE "<CONFIG>" "${config_ucase}" prop_of_config "${prop}")
        list(APPEND expanded_list "${prop_of_config}")
      endforeach()
    else()
      list(APPEND expanded_list "${prop}")
    endif()
  endforeach()
  list(REMOVE_DUPLICATES expanded_list)

  foreach(prop ${expanded_list})
    get_property(
      is_set
      TARGET ${tgt}
      PROPERTY ${prop}
      SET)
    if(is_set)
      get_target_property(propval ${tgt} ${prop})
      cs_debug_message("${tgt} ${prop} = ${propval}")
    endif()
  endforeach()
endfunction()
