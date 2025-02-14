include_guard(GLOBAL)
include(utils/csDebugMessage)
include(utils/csListUtils)

macro(cs_find_package TARGET_NAME)
	# this has to be a macro, because some find_package out variable needs to be visible to the caller

	csDebugMessage("[cs_find_package] target ${TARGET_NAME} find ${ARGN}")
	
	find_package(${ARGN})
	csAddFindPackageArgsToTarget("${TARGET_NAME}" "${ARGN}")
endmacro()

# append to csFindPackage property of the target
function(csAddFindPackageArgsToTarget TARGET_NAME)
	list(JOIN ARGN " " JOINED_ARGN)
	csDebugMessage("[csAddFindPackageArgsToTarget] target ${TARGET_NAME} arguments ${JOINED_ARGN}")
  csAddToTargetPropertyUnique("${TARGET_NAME}" csFindPackage "${JOINED_ARGN}")
endfunction()

# return the csFindPackage property of the target, i.e., a list, eventually empty
function(csGetFindPackagesForTarget TARGET_NAME OUTPUT_VARIABLE_NAME)
  get_target_property(LIST_VALUES ${TARGET_NAME} csFindPackage)
  if(LIST_VALUES)
    # if exists
    set(${OUTPUT_VARIABLE_NAME} ${LIST_VALUES} PARENT_SCOPE)
  else()
    # otherwise set to empty list
    set(${OUTPUT_VARIABLE_NAME} "" PARENT_SCOPE)
  endif()
endfunction()
 
function(csPrintFindPackagesForTarget TARGET_NAME)
  set(PACKAGES "")
  csGetFindPackagesForTarget("${TARGET_NAME}" PACKAGES)
  list(LENGTH PACKAGES N)
  message(STATUS "N ${N}")
  if(N GREATER 0)
    message(STATUS "csPrintFindPackagesForTarget ${TARGET_NAME}: ${PACKAGES}")
  else()
    message(STATUS "csPrintFindPackagesForTarget ${TARGET_NAME} empty")
  endif()
endfunction()
