include_guard(GLOBAL)
include(utils/csDebugMessage)
include(utils/csListUtils)

# add a target as library and add to list csProjectTargets
function(cs_add_library TARGET_NAME)
	add_library("${TARGET_NAME}" ${ARGN})
  _cs_add_target_to_project_targets(${TARGET_NAME})
endfunction()

# add a target as executable and add to list csProjectTargets
function(cs_add_executable TARGET_NAME)
	add_executable("${TARGET_NAME}" ${ARGN})
  _cs_add_target_to_project_targets(${TARGET_NAME})
endfunction()

function (_cs_add_target_to_project_targets TARGET_NAME)
  # add to list of targets if it is not an alias
	get_target_property(TARGET_NAME_ALIAS ${TARGET_NAME} ALIASED_TARGET)
	if(NOT TARGET_NAME_ALIAS)
	  _csAddToGlobalPropertyUniqueValue(csProjectTargets ${TARGET_NAME})
  endif()
endfunction()


function (cs_finalize_target TARGET_NAME)
  _cs_recursive_analyze_target(${TARGET_NAME})
endfunction()

# return all targets added in csProjectTargets
function(cs_get_all_targets OUTPUT_VARIABLE_NAME)
	get_property(LIST_VALUES GLOBAL PROPERTY csProjectTargets)
  if(LIST_VALUES)
    # if exists
    set(${OUTPUT_VARIABLE_NAME} ${LIST_VALUES} PARENT_SCOPE)
  else()
    # otherwise set to empty list
    set(${OUTPUT_VARIABLE_NAME} "" PARENT_SCOPE)
  endif()
endfunction()

function(cs_print_all_target)
  set(TARGETS "")
  cs_get_all_targets(TARGETS)
  list(LENGTH TARGETS N)
  if(N GREATER 0)
    message(STATUS "cs_print_all_target ${TARGETS}")
  else()
    message(STATUS "cs_print_all_target empty")
  endif()
endfunction()
