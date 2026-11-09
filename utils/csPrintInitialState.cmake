include_guard(GLOBAL)

# Print (debug) the csCMake state, tagged with HEADER_MESSAGE: module and prefix paths, install prefix, configurations
# and their variables.
function(cs_print_state HEADER_MESSAGE)
  # cmake-lint: disable=W0106
  # (the "ENV{CMAKE_PREFIX_PATH}" label below is intentional text, not a broken variable reference)
  cs_debug_message("--- csCMake ${HEADER_MESSAGE} state ---")
  cs_debug_message("  csCMake path: ${CMAKE_CURRENT_LIST_DIR}")
  cs_debug_message("  CS_CMAKE_MODULE_PATH_HEAD: ${CS_CMAKE_MODULE_PATH_HEAD}")
  cs_debug_message("  CMAKE_MODULE_PATH: ${CMAKE_MODULE_PATH}")
  cs_debug_message("  CS_CMAKE_MODULE_PATH_TAIL: ${CS_CMAKE_MODULE_PATH_TAIL}")
  cs_debug_message("  Packages search paths:")
  cs_debug_message("    ENV{CMAKE_PREFIX_PATH} = $ENV{CMAKE_PREFIX_PATH}")
  cs_debug_message("    CS_CMAKE_PREFIX_PATH_HEAD = ${CS_CMAKE_PREFIX_PATH_HEAD}")
  cs_debug_message("    CMAKE_PREFIX_PATH = ${CMAKE_PREFIX_PATH}")
  cs_debug_message("    CS_CMAKE_PREFIX_PATH_TAIL = ${CS_CMAKE_PREFIX_PATH_TAIL}")
  cs_debug_message("    CMAKE_INSTALL_PREFIX = ${CMAKE_INSTALL_PREFIX}")
  cs_debug_message("  CMAKE_CONFIGURATION_TYPES = ${CMAKE_CONFIGURATION_TYPES}")
  cs_debug_message("  CMAKE_BUILD_TYPE = ${CMAKE_BUILD_TYPE}")
  cs_debug_message("  DEBUG_CONFIGURATIONS = ${DEBUG_CONFIGURATIONS}")

  cs_get_build_configurations(LIST)
  cs_debug_message("  csCMakeConfigurationTypes ${LIST}")

  cs_print_all_configurations_variables("[${HEADER_MESSAGE} state]")
  cs_debug_message("--- csCMake ---")
endfunction()
