include_guard(GLOBAL)
include(utils/csDebugMessage)
include(utils/csListUtils)
include(utils/csDebugUtils)

# target properties added by this function - csTargetDependencies${CONFIG}: list of dll necessary to the target, a
# variable for each configuration is created - csTargetDependenciesNotImportedTargets: list of dependent targets that
# are marked as not imported - csTargetDependenciesNonTargets: list of dependencies that are marked as non-target
function(_cs_recursive_analyze_target TARGET_NAME)
  # cmake-lint: disable=R0915
  # get target type
  get_target_property(TARGET_TYPE ${TARGET_NAME} TYPE)

  # initialize the iterative list of target to analyze
  set(TARGETS_TO_ANALYZE_LIST ${TARGET_NAME})
  list(LENGTH TARGETS_TO_ANALYZE_LIST TARGETS_TO_ANALYZE_SIZE)

  # loop
  while(TARGETS_TO_ANALYZE_SIZE GREATER 0)
    # get the first target in the list
    list(GET TARGETS_TO_ANALYZE_LIST 0 TARGET_TO_ANALYZE)
    # and remove it
    list(REMOVE_AT TARGETS_TO_ANALYZE_LIST 0)

    # get target type
    if(TARGET ${TARGET_TO_ANALYZE})
      # get type and imported properties
      get_target_property(TARGET_TO_ANALYZE_TYPE ${TARGET_TO_ANALYZE} TYPE)
      get_target_property(TARGET_TO_ANALYZE_IMPORTED ${TARGET_TO_ANALYZE} IMPORTED)

      # check aliasing and retrieve original name
      get_target_property(ALIASED_TARGET_TO_ANALYZE ${TARGET_TO_ANALYZE} ALIASED_TARGET)
      if(ALIASED_TARGET_TO_ANALYZE)
        cs_debug_message(
          "[_cs_recursive_analyze_target] TARGET_TO_ANALYZE ${TARGET_TO_ANALYZE} ALIAS ${ALIASED_TARGET_TO_ANALYZE} TYPE ${TARGET_TO_ANALYZE_TYPE} IMPORTED ${TARGET_TO_ANALYZE_IMPORTED}"
        )
        set(TARGET_TO_ANALYZE "${ALIASED_TARGET_TO_ANALYZE}")
      else()
        cs_debug_message(
          "[_cs_recursive_analyze_target] TARGET_TO_ANALYZE ${TARGET_TO_ANALYZE} TYPE ${TARGET_TO_ANALYZE_TYPE} IMPORTED ${TARGET_TO_ANALYZE_IMPORTED}"
        )
      endif()

      # get all link libraries of the TARGET_TO_ANALYZE and add as recoursive dependecies to analyze
      set(TARGET_TO_ANALYZE_LINKED_LIBS "")
      _cs_get_all_linked_libs(${TARGET_TO_ANALYZE} TARGET_TO_ANALYZE_LINKED_LIBS)
      cs_debug_message(
        "[_cs_recursive_analyze_target] ${TARGET_TO_ANALYZE} has the following dependencies to be further analyzed TARGET_TO_ANALYZE_LINKED_LIBS: ${TARGET_TO_ANALYZE_LINKED_LIBS}"
      )
      # add to continue the analysis loop
      _cs_list_add_list_unique_values(TARGETS_TO_ANALYZE_LIST "${TARGET_TO_ANALYZE_LINKED_LIBS}")

      if(NOT TARGET_TO_ANALYZE_IMPORTED)
        # not imported target, i.e., a target specified inside the project, will be analyzed further for recursive
        # dependencies
        if(NOT ${TARGET_TO_ANALYZE} STREQUAL ${TARGET_NAME})
          cs_debug_message(
            "[_cs_recursive_analyze_target] ${TARGET_TO_ANALYZE} is not imported (i.e., is defined in this project), add it to the list of non resolved recursive dependencies"
          )
          _cs_add_to_target_property_unique_value(${TARGET_NAME} csTargetDependenciesNotImportedTargets
                                                  ${TARGET_TO_ANALYZE})
        else()
          cs_debug_message(
            "[_cs_recursive_analyze_target] ${TARGET_TO_ANALYZE} is not imported, but is the base target to analyze, do not add it recursively"
          )
        endif()
      else()
        # if the target is a shared, interface or module library, add its paths
        if((${TARGET_TO_ANALYZE_TYPE} STREQUAL "MODULE_LIBRARY")
           OR (${TARGET_TO_ANALYZE_TYPE} STREQUAL "SHARED_LIBRARY")
           OR (${TARGET_TO_ANALYZE_TYPE} STREQUAL "INTERFACE_LIBRARY"))
          cs_debug_message("[_cs_recursive_analyze_target] ${TARGET_TO_ANALYZE} is imported, populate its library path")
          _cs_add_imported_target_locations(${TARGET_NAME} ${TARGET_TO_ANALYZE})
        else()

        endif()
      endif()

    else()
      if(NOT ${TARGET_TO_ANALYZE} STREQUAL ${TARGET_NAME})
        cs_debug_message(
          "[_cs_recursive_analyze_target] TARGET_TO_ANALYZE ${TARGET_TO_ANALYZE} is not a target, add it to the list of non resolved recursive dependencies"
        )
        _cs_add_to_target_property_unique_value(${TARGET_NAME} csTargetDependenciesNonTargets ${TARGET_TO_ANALYZE})
      else()
        cs_debug_message(
          "[_cs_recursive_analyze_target] TARGET_TO_ANALYZE ${TARGET_TO_ANALYZE} is not a target, but is the base target to analyze, do not add it recursively"
        )
      endif()
    endif()

    # finally refresh while condition variable
    list(LENGTH TARGETS_TO_ANALYZE_LIST TARGETS_TO_ANALYZE_SIZE)
  endwhile()

  # print for debug purposes

  # per config
  cs_get_build_configurations(CONFIGS_LIST)
  foreach(CONFIG ${CONFIGS_LIST})

    _cs_get_target_direct_runtime_libraries(${TARGET_NAME} ${CONFIG} TARGET_TO_ANALYZE_DEPENDENCIES)
    cs_debug_message(
      "[_cs_recursive_analyze_target] ${TARGET_NAME} csTargetDependencies${CONFIG}: ${TARGET_TO_ANALYZE_DEPENDENCIES}")

  endforeach()

  _cs_get_target_linked_project_targets(${TARGET_NAME} TARGET_TO_ANALYZE_DEPENDENCIES_NOT_IMPORTED_TARGETS)
  cs_debug_message(
    "[_cs_recursive_analyze_target] ${TARGET_NAME} csTargetDependenciesNotImportedTargets: ${TARGET_TO_ANALYZE_DEPENDENCIES_NOT_IMPORTED_TARGETS}"
  )

  _cs_get_target_linked_non_targets(${TARGET_NAME} TARGET_TO_ANALYZE_DEPENDENCIES_NON_TARGETS)
  cs_debug_message(
    "[_cs_recursive_analyze_target] ${TARGET_NAME} csTargetDependenciesNonTargets: ${TARGET_TO_ANALYZE_DEPENDENCIES_NON_TARGETS}"
  )

  cs_debug_message("[_cs_recursive_analyze_target] ${TARGET_NAME} end")

endfunction()

# return csTargetDependencies${CONFIG} for target
function(_cs_get_target_direct_runtime_libraries TARGET_NAME CONFIG OUTPUT_VARIABLE_NAME)
  get_target_property(_VALUES ${TARGET_NAME} csTargetDependencies${CONFIG})
  if(_VALUES)
    set(${OUTPUT_VARIABLE_NAME}
        ${_VALUES}
        PARENT_SCOPE)
  else()
    set(${OUTPUT_VARIABLE_NAME}
        ""
        PARENT_SCOPE)
  endif()
endfunction()

# return csTargetDependenciesNotImportedTargets for target
function(_cs_get_target_linked_project_targets TARGET_NAME OUTPUT_VARIABLE_NAME)
  get_target_property(_VALUES ${TARGET_NAME} csTargetDependenciesNotImportedTargets)
  if(_VALUES)
    set(${OUTPUT_VARIABLE_NAME}
        ${_VALUES}
        PARENT_SCOPE)
  else()
    set(${OUTPUT_VARIABLE_NAME}
        ""
        PARENT_SCOPE)
  endif()
endfunction()

# * csTargetDependenciesNonTargets
function(_cs_get_target_linked_non_targets TARGET_NAME OUTPUT_VARIABLE_NAME)
  get_target_property(_VALUES ${TARGET_NAME} csTargetDependenciesNonTargets)
  if(_VALUES)
    set(${OUTPUT_VARIABLE_NAME}
        ${_VALUES}
        PARENT_SCOPE)
  else()
    set(${OUTPUT_VARIABLE_NAME}
        ""
        PARENT_SCOPE)
  endif()
endfunction()

# * csTargetDependencies, created in _cs_recursive_analyze_targets_finalize
function(cs_get_target_project_dependencies TARGET_NAME OUTPUT_VARIABLE_NAME)
  get_target_property(_VALUES ${TARGET_NAME} csTargetDependencies)
  if(_VALUES)
    set(${OUTPUT_VARIABLE_NAME}
        ${_VALUES}
        PARENT_SCOPE)
  else()
    set(${OUTPUT_VARIABLE_NAME}
        ""
        PARENT_SCOPE)
  endif()
endfunction()

# * csTargetDependencies${CONFIG}Finalized: list of ${CONFIG} dll necessary to the target
# * csTargetDependencies: list of other target of this project needed for this target during the execution a variable
#   csTargetDependenciesToAnalyze is created as temporary, but it will be used as a "buffer", at exist it is empty
function(_cs_recursive_analyze_targets_finalize TARGETS_LIST)
  cs_debug_message("[_cs_recursive_analyze_targets_finalize] targets: ${TARGETS_LIST}")

  # for each target,
  foreach(TARGET_NAME IN ITEMS ${TARGETS_LIST})
    # * copy csTargetDependencies${CONFIG} to the Finalized copies
    # * create a unique list of target csTargetDependenciesToAnalyze and csTargetDependencies as merge of
    #   csTargetDependenciesNotImportedTargets and csTargetDependenciesNonTargets, by selecting only what is effectively
    #   a target and removing aliases
    _cs_prepare_finalize_target(${TARGET_NAME})
  endforeach()

  # now, for each target, cumulate in Finalized the Finalized of the dependent target. If fully finalized, remove from
  # the list of targets, otherwise add back at the end
  list(LENGTH TARGETS_LIST TARGETS_LIST_SIZE)

  # backup of target list
  set(TARGETS_LIST_ORIGINAL ${TARGETS_LIST})

  # loop
  while(TARGETS_LIST_SIZE GREATER 0)
    # get the first target in the list
    list(GET TARGETS_LIST 0 TARGET_NAME)
    # and remove it
    list(REMOVE_AT TARGETS_LIST 0)

    cs_debug_message("[_cs_recursive_analyze_targets_finalize] analyze target ${TARGET_NAME}")

    _cs_target_is_fully_finalized(${TARGET_NAME} TARGET_FINALIZED)
    if(NOT TARGET_FINALIZED)
      cs_debug_message("[_cs_recursive_analyze_targets_finalize] target ${TARGET_NAME} is not finalized")
      # try to finalize
      _cs_target_try_to_finalize(${TARGET_NAME})
      # and check the result
      _cs_target_is_fully_finalized(${TARGET_NAME} TARGET_FINALIZED)
      if(NOT TARGET_FINALIZED)
        cs_debug_message(
          "[_cs_recursive_analyze_targets_finalize] target ${TARGET_NAME} is not finalized yet, readd it")
        _cs_list_add_unique_value(TARGETS_LIST ${TARGET_NAME})
      else()
        cs_debug_message("[_cs_recursive_analyze_targets_finalize] target ${TARGET_NAME} is now finalized!")
      endif()

    else()
      cs_debug_message("[_cs_recursive_analyze_targets_finalize] target ${TARGET_NAME} is finalized!")
    endif()

    # finally refresh while condition variable
    list(LENGTH TARGETS_LIST TARGETS_LIST_SIZE)
  endwhile()

  # print out final dependency list
  cs_debug_message("[_cs_recursive_analyze_targets_finalize] concluded, print final state")
  foreach(TARGET_NAME IN ITEMS ${TARGETS_LIST_ORIGINAL})
    cs_get_build_configurations(CONFIGS_LIST)
    foreach(CONFIG ${CONFIGS_LIST})
      cs_get_target_runtime_libraries(${TARGET_NAME} ${CONFIG} TARGET_TO_ANALYZE_DEPENDENCIES)
      cs_debug_message(
        "[_cs_recursive_analyze_targets_finalize] ${TARGET_NAME} csTargetDependencies${CONFIG}Finalized : ${TARGET_TO_ANALYZE_DEPENDENCIES}"
      )
    endforeach()
  endforeach()
  cs_debug_message("[_cs_recursive_analyze_targets_finalize] end")

endfunction()

# Merge into the csTargetDependencies<CONFIG>Finalized properties of TARGET_NAME those of its already finalized
# dependencies; the dependencies still pending are kept in csTargetDependenciesToAnalyze.
function(_cs_target_try_to_finalize TARGET_NAME)
  get_target_property(DEP_TARGETS ${TARGET_NAME} csTargetDependenciesToAnalyze)

  set(PENDING_DEP_TARGETS "")
  foreach(DEP_TARGET IN ITEMS "${DEP_TARGETS}")
    _cs_target_is_fully_finalized(${DEP_TARGET} DEP_TARGET_FINALIZED)
    if(DEP_TARGET_FINALIZED)
      # merge the two finalized list of target and dep target
      cs_get_build_configurations(CONFIGS_LIST)
      foreach(CONFIG ${CONFIGS_LIST})

        cs_get_target_runtime_libraries(${TARGET_NAME} ${CONFIG} TARGET_LIB)

        cs_get_target_runtime_libraries(${DEP_TARGET} ${CONFIG} TARGET_LIB_DEP)

        _cs_list_add_list_unique_values(TARGET_LIB "${TARGET_LIB_DEP}")

        # and set back
        set_property(TARGET ${TARGET_NAME} PROPERTY csTargetDependencies${CONFIG}Finalized "${TARGET_LIB}")
      endforeach()

    else()
      _cs_list_add_unique_value(PENDING_DEP_TARGETS ${DEP_TARGET})
    endif()
  endforeach()

  cs_debug_message("[_cs_target_try_to_finalize] target ${TARGET_NAME} pending dependencies ${PENDING_DEP_TARGETS}")
  set_property(TARGET ${TARGET_NAME} PROPERTY csTargetDependenciesToAnalyze "${PENDING_DEP_TARGETS}")

endfunction()

# return true if the csTargetDependenciesToAnalyze of the target is empty
function(_cs_target_is_fully_finalized TARGET_NAME TARGET_FINALIZED)
  get_target_property(_VALUES ${TARGET_NAME} csTargetDependenciesToAnalyze)
  if(_VALUES)
    set(${TARGET_FINALIZED}
        False
        PARENT_SCOPE)
  else()
    set(${TARGET_FINALIZED}
        True
        PARENT_SCOPE)
  endif()
endfunction()

# this function - copy csTargetDependencies${CONFIG} the csTargetDependencies${CONFIG}Finalized copy - merges the
# csTargetDependenciesNotImportedTargets and csTargetDependenciesNonTargets and select valid targets, preparing the list
# in both csTargetDependencies and csTargetDependenciesToAnalyze csTargetDependenciesToAnalyze will be consumed in
# _cs_recursive_analyze_targets_finalize until is empty, while csTargetDependencies remain persistent
function(_cs_prepare_finalize_target TARGET_NAME)
  cs_debug_message("[_cs_prepare_finalize_target] process target: ${TARGET_NAME}")

  # copy on Finalized
  cs_get_build_configurations(CONFIGS_LIST)
  foreach(CONFIG ${CONFIGS_LIST})

    _cs_get_target_direct_runtime_libraries(${TARGET_NAME} ${CONFIG} TARGET_LIBS)
    set_property(TARGET ${TARGET_NAME} PROPERTY csTargetDependencies${CONFIG}Finalized "${TARGET_LIBS}")
    cs_debug_message(
      "[_cs_prepare_finalize_target] ${TARGET_NAME} csTargetDependencies${CONFIG}Finalized: ${TARGET_LIBS}")
  endforeach()

  # retrieve targets to analyze
  _cs_get_target_linked_project_targets(${TARGET_NAME} TARGET_NOT_IMPORTED)
  cs_debug_message(
    "[_cs_prepare_finalize_target] ${TARGET_NAME} csTargetDependenciesNotImportedTargets: ${TARGET_NOT_IMPORTED}")

  _cs_get_target_linked_non_targets(${TARGET_NAME} TARGET_NON_TARGETS)
  cs_debug_message("[_cs_prepare_finalize_target] ${TARGET_NAME} csTargetDependenciesNonTargets: ${TARGET_NON_TARGETS}")

  # join the two list
  set(TARGETS_TO_ANALYZE_LIST_RAW "")
  foreach(TARGET_TO_ANALYZE IN ITEMS ${TARGET_NOT_IMPORTED})
    _cs_list_add_unique_value(TARGETS_TO_ANALYZE_LIST_RAW "${TARGET_TO_ANALYZE}")
  endforeach()
  foreach(TARGET_TO_ANALYZE IN ITEMS ${TARGET_NON_TARGETS})
    _cs_list_add_unique_value(TARGETS_TO_ANALYZE_LIST_RAW "${TARGET_TO_ANALYZE}")
  endforeach()
  cs_debug_message(
    "[_cs_prepare_finalize_target] ${TARGET_NAME} TARGETS_TO_ANALYZE_LIST_RAW ${TARGETS_TO_ANALYZE_LIST_RAW}")

  # select only targets
  set(TARGETS_TO_ANALYZE_LIST "")
  foreach(TARGET_TO_ANALYZE IN ITEMS ${TARGETS_TO_ANALYZE_LIST_RAW})
    if(TARGET ${TARGET_TO_ANALYZE})
      # check aliasing and retrieve original name
      get_target_property(ALIASED_TARGET_TO_ANALYZE ${TARGET_TO_ANALYZE} ALIASED_TARGET)
      if(ALIASED_TARGET_TO_ANALYZE)
        set(TARGET_TO_ANALYZE "${ALIASED_TARGET_TO_ANALYZE}")
      endif()
      _cs_list_add_unique_value(TARGETS_TO_ANALYZE_LIST "${TARGET_TO_ANALYZE}")
    endif()
  endforeach()

  cs_debug_message("[_cs_prepare_finalize_target] ${TARGET_NAME} TARGETS_TO_ANALYZE_LIST ${TARGETS_TO_ANALYZE_LIST}")
  set_property(TARGET ${TARGET_NAME} PROPERTY csTargetDependenciesToAnalyze "${TARGETS_TO_ANALYZE_LIST}")
  set_property(TARGET ${TARGET_NAME} PROPERTY csTargetDependencies "${TARGETS_TO_ANALYZE_LIST}")

endfunction()

# return csTargetDependencies${CONFIG} for target
function(cs_get_target_runtime_libraries TARGET_NAME CONFIG OUTPUT_VARIABLE_NAME)
  get_target_property(_VALUES ${TARGET_NAME} csTargetDependencies${CONFIG}Finalized)
  if(_VALUES)
    set(${OUTPUT_VARIABLE_NAME}
        ${_VALUES}
        PARENT_SCOPE)
  else()
    set(${OUTPUT_VARIABLE_NAME}
        ""
        PARENT_SCOPE)
  endif()
endfunction()

# Add the existing IMPORTED_LOCATION_<CONFIG> files of the imported target TARGET_TO_ANALYZE to the
# csTargetDependencies<CONFIG> properties of TARGET_NAME, falling back to IMPORTED_LOCATION when the per-configuration
# location is missing.
function(_cs_add_imported_target_locations TARGET_NAME TARGET_TO_ANALYZE)
  cs_get_build_configurations(CONFIGS_LIST)

  # per config
  foreach(CONFIG ${CONFIGS_LIST})
    string(TOUPPER "${CONFIG}" CONFIG_UCASE)
    get_target_property(IMPORTED_LOCATION_${CONFIG_UCASE} ${TARGET_TO_ANALYZE} IMPORTED_LOCATION_${CONFIG_UCASE})
    _cs_add_existing_path_to_target_property(${IMPORTED_LOCATION_${CONFIG_UCASE}} ${TARGET_NAME}
                                             csTargetDependencies${CONFIG} ${TARGET_TO_ANALYZE})
  endforeach()

  # generic
  get_target_property(IMPORTED_LOCATION ${TARGET_TO_ANALYZE} IMPORTED_LOCATION)
  foreach(CONFIG ${CONFIGS_LIST})
    string(TOUPPER "${CONFIG}" CONFIG_UCASE)
    if(IMPORTED_LOCATION AND NOT IMPORTED_LOCATION_${CONFIG_UCASE})
      # if imported location and not specific config, use it
      cs_debug_message(
        "[_cs_add_imported_target_locations] target ${TARGET_TO_ANALYZE} has IMPORTED_LOCATION=${IMPORTED_LOCATION} but no IMPORTED_LOCATION_${CONFIG_UCASE}, use IMPORTED_LOCATION for it"
      )
      set(IMPORTED_LOCATION_${CONFIG_UCASE} "${IMPORTED_LOCATION}")
      _cs_add_existing_path_to_target_property(${IMPORTED_LOCATION_${CONFIG_UCASE}} ${TARGET_NAME}
                                               csTargetDependencies${CONFIG} ${TARGET_TO_ANALYZE})
    endif()
  endforeach()

endfunction()

# Append PATH_VALUE to the TARGET_PROPERTY of TARGET_NAME if the file exists, otherwise skip it (TARGET_TO_ANALYZE is
# used for the debug message).
function(_cs_add_existing_path_to_target_property PATH_VALUE TARGET_NAME TARGET_PROPERTY TARGET_TO_ANALYZE)
  if(PATH_VALUE)
    # check file exist
    if(EXISTS ${PATH_VALUE})
      _cs_add_to_target_property_unique_value(${TARGET_NAME} ${TARGET_PROPERTY} ${PATH_VALUE})
    else()
      cs_debug_message(
        "[_csPopulatecsTargetDependencies] ${TARGET_TO_ANALYZE} depends on ${PATH_VALUE} but the file does not exists, skip"
      )
    endif()
  endif()
endfunction()

# Return in TARGET_TO_ANALYZE_LINKED_LIBS_OUT every library TARGET_TO_ANALYZE links to, without duplicates:
# (INTERFACE_)LINK_LIBRARIES, the legacy LINK_INTERFACE_LIBRARIES, the imported link interfaces and the link depends,
# including their per-configuration variants.
function(_cs_get_all_linked_libs TARGET_TO_ANALYZE TARGET_TO_ANALYZE_LINKED_LIBS_OUT)
  cs_get_build_configurations(CONFIGS_LIST)

  set(TARGET_TO_ANALYZE_LINKED_LIBS "")

  get_target_property(tmp_list ${TARGET_TO_ANALYZE} LINK_LIBRARIES)
  _cs_list_add_list_unique_values(TARGET_TO_ANALYZE_LINKED_LIBS "${tmp_list}")

  # interface link (seems to be legacy...)
  get_target_property(tmp_list ${TARGET_TO_ANALYZE} LINK_INTERFACE_LIBRARIES)
  _cs_list_add_list_unique_values(TARGET_TO_ANALYZE_LINKED_LIBS "${tmp_list}")

  foreach(CONFIG ${CONFIGS_LIST})
    string(TOUPPER "${CONFIG}" CONFIG_UCASE)

    get_target_property(tmp_list ${TARGET_TO_ANALYZE} LINK_INTERFACE_LIBRARIES_${CONFIG_UCASE})
    _cs_list_add_list_unique_values(TARGET_TO_ANALYZE_LINKED_LIBS "${tmp_list}")
  endforeach()

  # interface link depends
  get_target_property(tmp_list ${TARGET_TO_ANALYZE} INTERFACE_LINK_DEPENDS)
  _cs_list_add_list_unique_values(TARGET_TO_ANALYZE_LINKED_LIBS "${tmp_list}")

  # interface link libraries
  get_target_property(tmp_list ${TARGET_TO_ANALYZE} INTERFACE_LINK_LIBRARIES)
  _cs_list_add_list_unique_values(TARGET_TO_ANALYZE_LINKED_LIBS "${tmp_list}")

  foreach(CONFIG ${CONFIGS_LIST})
    string(TOUPPER "${CONFIG}" CONFIG_UCASE)

    get_target_property(tmp_list ${TARGET_TO_ANALYZE} INTERFACE_LINK_LIBRARIES_${CONFIG_UCASE})
    _cs_list_add_list_unique_values(TARGET_TO_ANALYZE_LINKED_LIBS "${tmp_list}")
  endforeach()

  # imported interface link libraries
  get_target_property(tmp_list ${TARGET_TO_ANALYZE} IMPORTED_LINK_INTERFACE_LIBRARIES)
  _cs_list_add_list_unique_values(TARGET_TO_ANALYZE_LINKED_LIBS "${tmp_list}")

  foreach(CONFIG ${CONFIGS_LIST})
    string(TOUPPER "${CONFIG}" CONFIG_UCASE)

    get_target_property(tmp_list ${TARGET_TO_ANALYZE} IMPORTED_LINK_INTERFACE_LIBRARIES_${CONFIG_UCASE})
    _cs_list_add_list_unique_values(TARGET_TO_ANALYZE_LINKED_LIBS "${tmp_list}")
  endforeach()

  # link depends
  get_target_property(tmp_list ${TARGET_TO_ANALYZE} LINK_DEPENDS)
  _cs_list_add_list_unique_values(TARGET_TO_ANALYZE_LINKED_LIBS "${tmp_list}")

  # link dependent
  get_target_property(tmp_list ${TARGET_TO_ANALYZE} IMPORTED_LINK_DEPENDENT_LIBRARIES)
  _cs_list_add_list_unique_values(TARGET_TO_ANALYZE_LINKED_LIBS "${tmp_list}")

  foreach(CONFIG ${CONFIGS_LIST})
    string(TOUPPER "${CONFIG}" CONFIG_UCASE)

    get_target_property(tmp_list ${TARGET_TO_ANALYZE} IMPORTED_LINK_DEPENDENT_LIBRARIES_${CONFIG_UCASE})
    _cs_list_add_list_unique_values(TARGET_TO_ANALYZE_LINKED_LIBS "${tmp_list}")
  endforeach()

  get_target_property(tmp_list ${TARGET_TO_ANALYZE} MANUALLY_ADDED_DEPENDENCIES)
  _cs_list_add_list_unique_values(TARGET_TO_ANALYZE_LINKED_LIBS "${tmp_list}")

  # set output value
  set(${TARGET_TO_ANALYZE_LINKED_LIBS_OUT}
      ${TARGET_TO_ANALYZE_LINKED_LIBS}
      PARENT_SCOPE)
endfunction()
