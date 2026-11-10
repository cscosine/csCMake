#.rst:
# csPrintInitialState
# -------------------
#
# Debug print of the csCMake state.
#
# Commands
# ^^^^^^^^
include_guard(GLOBAL)

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
