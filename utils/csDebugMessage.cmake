# Debug messages of csCMake: cs_debug_message.
include_guard(GLOBAL)

# Print a debug message of csCMake.
#
# cs_debug_message(<text>...)
#
# The arguments are concatenated like message() does (also when they contain ";") and printed as a STATUS message when
# the debug messages of the current project are enabled.
#
# Reads:
#
# * variable _cscmake_debug_option: name of the debug option of the project
# * cache variable <project>_CSCMAKE_DEBUG
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
