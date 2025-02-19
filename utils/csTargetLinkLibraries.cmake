include_guard(GLOBAL)
include(utils/csDebugMessage)

function(cs_target_link_libraries TARGET_NAME)
	cs_debug_message("[cs_target_link_libraries] ${TARGET_NAME} ${ARGN}")
	
	target_link_libraries("${TARGET_NAME}" ${ARGN})
endfunction()

