include_guard(GLOBAL)

# option to print out messages as "STATUS" from this module
option(${CMAKE_PROJECT_NAME}_CSCMAKE_DEBUG "activate the debug of csCMake for the current project" OFF)

# print message msg if ${CMAKE_PROJECT_NAME}_CSCMAKE_DEBUG is ON, or if a additional parameter at end is true
function(cs_debug_message msg)
  set(forced False)
  if(ARGC EQUAL 2)
    set(forced ${ARGV1})
  endif()

  if(${forced} OR ${CMAKE_PROJECT_NAME}_CSCMAKE_DEBUG)
    message(STATUS "${msg}")
  endif()
endfunction()
