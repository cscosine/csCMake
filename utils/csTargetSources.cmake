include_guard(GLOBAL)
include(utils/csDebugMessage)

function(cs_target_sources TARGET_NAME)
	csDebugMessage("[cs_target_sources] target ${TARGET_NAME} find ${ARGN}")
	
	target_sources("${TARGET_NAME}" ${ARGN})
  # TODO(sc): add what is missing to manage properly the sources (what should be installed etc..)
endfunction()

