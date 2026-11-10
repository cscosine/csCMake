#.rst:
# csDebug
# -------
#
# Debug messages and prints of csCMake: :command:`cs_debug_message` (shown with
# :variable:`<project>_CSCMAKE_DEBUG`), the state of csCMake, the properties of a target.
#
# Commands
# ^^^^^^^^

include_guard(GLOBAL)

#.rst:
# .. command:: cs_debug_message
#
#   Print a debug message of csCMake.
#
#   .. code-block:: cmake
#
#     cs_debug_message(<text>...)
#
#   The arguments are concatenated like message() does (also when they contain ";") and printed as a STATUS message when
#   the debug messages of the current project are enabled.
#
#   ``<text>``
#     The message, its arguments concatenated as :command:`message` does.
#
#   :Reads: :variable:`_cscmake_debug_option`, :variable:`<project>_CSCMAKE_DEBUG`
function(cs_debug_message)
  if(NOT _cscmake_debug_option OR NOT ${_cscmake_debug_option})
    return()
  endif()
  # ARGV<n> one by one: ARGN would split the arguments containing ";"
  set(text "")
  set(index 0)
  while(index LESS ARGC)
    string(APPEND text "${ARGV${index}}")
    math(EXPR index "${index} + 1")
  endwhile()
  message(STATUS "${text}")
endfunction()

#.rst:
# .. command:: cs_print_state
#
#   Print the csCMake state (debug messages): module and prefix paths, install prefix, configurations and their
#   variables.
#
#   .. code-block:: cmake
#
#     cs_print_state(<header>)
#
#   ``<header>``
#     A text printed in the header of the output.
function(cs_print_state header_message)
  # cmake-lint: disable=W0106
  # (the "ENV{CMAKE_PREFIX_PATH}" label below is intentional text, not a broken variable reference)
  cs_debug_message("--- csCMake ${header_message} state ---")
  cs_debug_message("  csCMake path: ${CMAKE_CURRENT_LIST_DIR}")
  cs_debug_message("  CSCMAKE_MODULE_PATH_HEAD: ${CSCMAKE_MODULE_PATH_HEAD}")
  cs_debug_message("  CMAKE_MODULE_PATH: ${CMAKE_MODULE_PATH}")
  cs_debug_message("  CSCMAKE_MODULE_PATH_TAIL: ${CSCMAKE_MODULE_PATH_TAIL}")
  cs_debug_message("  Packages search paths:")
  cs_debug_message("    ENV{CMAKE_PREFIX_PATH} = $ENV{CMAKE_PREFIX_PATH}")
  cs_debug_message("    CSCMAKE_PREFIX_PATH_HEAD = ${CSCMAKE_PREFIX_PATH_HEAD}")
  cs_debug_message("    CMAKE_PREFIX_PATH = ${CMAKE_PREFIX_PATH}")
  cs_debug_message("    CSCMAKE_PREFIX_PATH_TAIL = ${CSCMAKE_PREFIX_PATH_TAIL}")
  cs_debug_message("    CMAKE_INSTALL_PREFIX = ${CMAKE_INSTALL_PREFIX}")
  cs_debug_message("  CMAKE_CONFIGURATION_TYPES = ${CMAKE_CONFIGURATION_TYPES}")
  cs_debug_message("  CMAKE_BUILD_TYPE = ${CMAKE_BUILD_TYPE}")
  cs_debug_message("  DEBUG_CONFIGURATIONS = ${DEBUG_CONFIGURATIONS}")

  cs_get_build_configurations(list)
  cs_debug_message("  CSCMAKE_BUILD_CONFIGURATIONS ${list}")

  cs_print_all_configurations_variables("[${header_message} state]")
  cs_debug_message("--- csCMake ---")
endfunction()

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
