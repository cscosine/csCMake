include_guard(GLOBAL)
include(utils/csDebugMessage)

function(cs_target_link_libraries TARGET_NAME)
	csDebugMessage("[cs_target_link_libraries ] ${TARGET_NAME} ${ARGN}")
	
	target_link_libraries("${TARGET_NAME}" ${ARGN})
endfunction()

