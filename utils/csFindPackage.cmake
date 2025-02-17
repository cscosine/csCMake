include_guard(GLOBAL)
include(utils/csDebugMessage)
include(utils/csListUtils)

macro(cs_find_package TARGET_NAME PROPAGATE_MODE)
	# this has to be a macro, because some find_package out variable needs to be visible to the caller

	csDebugMessage("[cs_find_package] target ${TARGET_NAME} find ${ARGN} with mode ${PROPAGATE_MODE}")
  
	find_package(${ARGN})
	_csAddFindPackageArgsToTarget("${TARGET_NAME}" "${PROPAGATE_MODE}" "${ARGN}")
endmacro()

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
  if(N GREATER 0)
    message(STATUS "csPrintFindPackagesForTarget ${TARGET_NAME}: ${PACKAGES}")
  else()
    message(STATUS "csPrintFindPackagesForTarget ${TARGET_NAME} empty")
  endif()
endfunction()

# append to csFindPackage property of the target
function(_csAddFindPackageArgsToTarget TARGET_NAME PROPAGATE_MODE)
	list(JOIN ARGN " " JOINED_ARGN)
	csDebugMessage("[csAddFindPackageArgsToTarget] target ${TARGET_NAME} arguments ${JOINED_ARGN}")

  # TODO(sc) support PROPAGATE_MODE as one of PUBLIC or PRIVATE
  
  _csAddToTargetPropertyUniqueValue("${TARGET_NAME}" csFindPackage "${JOINED_ARGN}")
endfunction()
