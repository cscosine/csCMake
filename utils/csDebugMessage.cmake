include_guard(GLOBAL)

# option to print out messages as "STATUS" from this module
OPTION(${CMAKE_PROJECT_NAME}_CS_CMAKE_DEBUG OFF)

# print message msg if ${CMAKE_PROJECT_NAME}_CS_CMAKE_DEBUG is ON, or if a additional parameter at end is true
function(cs_debug_message msg)
	set(forced False)
	if(ARGC EQUAL 2)
		set(forced ${ARGV1})
	endif()

	if(${forced} OR ${CMAKE_PROJECT_NAME}_CS_CMAKE_DEBUG)
		MESSAGE(STATUS "${msg}")
	endif()
endfunction()
