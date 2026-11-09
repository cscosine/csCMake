include_guard(GLOBAL)

# Print the arguments, concatenated like message() does, as a STATUS message when the csCMake debug messages of the
# current project are enabled (option <project>_CSCMAKE_DEBUG, defined by cs_initialize_project). Arguments are kept as
# they are, also when they contain ";".
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
