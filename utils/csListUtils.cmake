include_guard(GLOBAL)

function(csAddToTargetPropertyUnique TARGET_NAME PROPERTY_NAME VALUE)
	get_target_property(LIST_VALUES ${TARGET_NAME} ${PROPERTY_NAME})
	if(NOT ${VALUE} IN_LIST LIST_VALUES)
		set_property(TARGET ${TARGET_NAME} APPEND PROPERTY ${PROPERTY_NAME} ${VALUE})
	endif()
endfunction()