include_guard(GLOBAL)

function(cs_print_target_properties tgt)
  # Get all propreties that cmake supports
  execute_process(COMMAND cmake --help-property-list OUTPUT_VARIABLE CMAKE_PROPERTY_LIST)

  # Convert command output into a CMake list
  STRING(REGEX REPLACE ";" "\\\\;" CMAKE_PROPERTY_LIST "${CMAKE_PROPERTY_LIST}")
  STRING(REGEX REPLACE "\n" ";" CMAKE_PROPERTY_LIST "${CMAKE_PROPERTY_LIST}")

  # Remove all LOCATION* properties, that are no more readable
  list(FILTER CMAKE_PROPERTY_LIST EXCLUDE REGEX "^LOCATION$|^LOCATION_|_LOCATION$")

  # remove duplicates
  list(REMOVE_DUPLICATES CMAKE_PROPERTY_LIST)

  message("cs_print_target_properties ${tgt}")
  if(NOT TARGET ${tgt})
      message("There is no target named '${tgt}'")
      return()
  endif()

  foreach (prop ${PROP_LIST})
      string(REPLACE "<CONFIG>" "${CMAKE_BUILD_TYPE}" prop ${prop})
      # message ("Checking ${prop}")
      get_property(propval TARGET ${tgt} PROPERTY ${prop} SET)
      if (propval)
          get_target_property(propval ${tgt} ${prop})
          message ("${tgt} ${prop} = ${propval}")
      endif()
  endforeach(prop)
endfunction()
