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

# Register TARGET_NAME (unless it is an ALIAS) in the csProjectTargets global property, after setting on it the per-
# configuration output postfix (CSCMAKE_<CONFIG>_POSTFIX) and the MSVC runtime library generator expression. Fails if
# cs_initialize_project did not define them.
function(_cs_add_target_to_project_targets TARGET_NAME)
  # add to list of targets if it is not an alias
  get_target_property(TARGET_NAME_ALIAS ${TARGET_NAME} ALIASED_TARGET)
  if(NOT TARGET_NAME_ALIAS)
    # iterate on all specified configurations and add the target postfix
    cs_get_build_configurations(CONFIGS_LIST)
    foreach(CONFIG ${CONFIGS_LIST})
      string(TOUPPER "${CONFIG}" CONFIG)

      # postfix for file (d=debug, rd=relWithDebInfo, etc...)
      if(DEFINED CSCMAKE_${CONFIG}_POSTFIX)
        set_target_properties(${TARGET_NAME} PROPERTIES ${CONFIG}_POSTFIX "${CSCMAKE_${CONFIG}_POSTFIX}")
      else()
        message(
          FATAL_ERROR
            "CSCMAKE_${CONFIG}_POSTFIX variable do not exists, have you properly added configurations via _cs_add_custom_build_configuration?"
        )
      endif()

    endforeach()

    # path to allow execution inside visual studio
    if(DEFINED CSCMAKE_MSVC_RUNTIME_LIBRARY_GENERATOR_EXPRESSION)
      set_target_properties(${TARGET_NAME} PROPERTIES MSVC_RUNTIME_LIBRARY
                                                      "${CSCMAKE_MSVC_RUNTIME_LIBRARY_GENERATOR_EXPRESSION}")
    else()
      message(
        FATAL_ERROR
          "CSCMAKE_MSVC_RUNTIME_LIBRARY_GENERATOR_EXPRESSION variable do not exists, have you used properly cs_initialize_project?"
      )
    endif()

    _cs_add_to_global_property_unique_value(csProjectTargets ${TARGET_NAME})
  endif()
endfunction()

# Finalize TARGET_NAME by running the recursive dependency analysis (_cs_recursive_analyze_target). Call it once, after
# all the properties and links of the target are set.
function(cs_finalize_target TARGET_NAME)
  _cs_recursive_analyze_target(${TARGET_NAME})
endfunction()

# return all targets added in csProjectTargets
function(cs_get_project_targets OUTPUT_VARIABLE_NAME)
  get_property(LIST_VALUES GLOBAL PROPERTY csProjectTargets)
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

# Print (debug) the targets registered in the csProjectTargets global property.
function(cs_print_project_targets)
  set(TARGETS "")
  cs_get_project_targets(TARGETS)
  list(LENGTH TARGETS N)
  if(N GREATER 0)
    cs_debug_message("cs_print_project_targets ${TARGETS}")
  else()
    cs_debug_message("cs_print_project_targets empty")
  endif()
endfunction()
