include_guard(GLOBAL)
include(utils/csDebugMessage)
include(utils/csListUtils)

# PROPAGATE_MODE: PUBLIC or PRIVATE - PUBLIC will propagate the very same line
# as a find_package in the cmake prepared for installation - PROVATE will not
# propagate the very same line as a find_package in the cmake prepared for
# installation
macro(cs_find_package TARGET_NAME PROPAGATE_MODE)
  cs_debug_message(
    "[cs_find_package] target ${TARGET_NAME} find ${ARGN} with mode ${PROPAGATE_MODE}"
  )

  # this has to be a macro, because some find_package out variable needs to be
  # visible to the caller
  find_package(${ARGN})
  _cs_add_find_package_args_to_target("${TARGET_NAME}" "${PROPAGATE_MODE}"
                                      "${ARGN}")
endmacro()

# return the csFindPackage property of the target, i.e., a list, eventually
# empty
function(cs_get_target_find_packages TARGET_NAME OUTPUT_VARIABLE_NAME)
  get_target_property(LIST_VALUES ${TARGET_NAME} csFindPackage)
  if(LIST_VALUES)
    # if exists
    set(${OUTPUT_VARIABLE_NAME}
        ${LIST_VALUES}
        PARENT_SCOPE)
  else()
    # otherwise set to empty list
    set(${OUTPUT_VARIABLE_NAME}
        ""
        PARENT_SCOPE)
  endif()
endfunction()

function(cs_print_target_find_packages TARGET_NAME)
  set(PACKAGES "")
  cs_get_target_find_packages("${TARGET_NAME}" PACKAGES)
  list(LENGTH PACKAGES N)
  if(N GREATER 0)
    cs_debug_message("csPrintFindPackagesForTarget ${TARGET_NAME}: ${PACKAGES}")
  else()
    cs_debug_message("csPrintFindPackagesForTarget ${TARGET_NAME} empty")
  endif()
endfunction()

# append to csFindPackage property of the target
function(_cs_add_find_package_args_to_target TARGET_NAME PROPAGATE_MODE)
  list(JOIN ARGN " " JOINED_ARGN)
  cs_debug_message(
    "[csAddFindPackageArgsToTarget] target ${TARGET_NAME} arguments ${JOINED_ARGN}"
  )

  if(PROPAGATE_MODE STREQUAL "PUBLIC")
    _cs_add_to_target_property_unique_value("${TARGET_NAME}" csFindPackage
                                            "${JOINED_ARGN}")
  elseif(PROPAGATE_MODE STREQUAL "PRIVATE")
    # nothin to do
  else()
    message(
      FATAL_ERROR
        "cs_find_package PROPAGATE_MODE should be PUBLIC or PRIVATE, other values are not supported (called with PROPAGATE_MODE=${PROPAGATE_MODE})"
    )
  endif()
endfunction()
