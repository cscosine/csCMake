include_guard(GLOBAL)
include(utils/csDebugMessage)
include(utils/csListUtils)

# add a target as library and add to list CSCMAKE_PROJECT_TARGETS
function(cs_add_library target_name)
  add_library("${target_name}" ${ARGN})
  _cs_add_target_to_project_targets(${target_name})
endfunction()

# add a target as executable and add to list CSCMAKE_PROJECT_TARGETS
function(cs_add_executable target_name)
  add_executable("${target_name}" ${ARGN})
  _cs_add_target_to_project_targets(${target_name})
endfunction()

# Register target_name (unless it is an ALIAS) in the CSCMAKE_PROJECT_TARGETS global property, after setting on it the
# per- configuration output postfix (CSCMAKE_<CONFIG>_POSTFIX) and the MSVC runtime library generator expression. Fails
# if cs_initialize_project did not define them.
function(_cs_add_target_to_project_targets target_name)
  # add to list of targets if it is not an alias
  get_target_property(target_name_alias ${target_name} ALIASED_TARGET)
  if(NOT target_name_alias)
    # iterate on all specified configurations and add the target postfix
    cs_get_build_configurations(configs_list)
    foreach(config ${configs_list})
      string(TOUPPER "${config}" config)

      # postfix for file (d=debug, rd=relWithDebInfo, etc...)
      if(DEFINED CSCMAKE_${config}_POSTFIX)
        set_target_properties(${target_name} PROPERTIES ${config}_POSTFIX "${CSCMAKE_${config}_POSTFIX}")
      else()
        message(
          FATAL_ERROR
            "CSCMAKE_${config}_POSTFIX variable do not exists, have you properly added configurations via _cs_add_custom_build_configuration?"
        )
      endif()

    endforeach()

    # path to allow execution inside visual studio
    if(DEFINED CSCMAKE_MSVC_RUNTIME_LIBRARY_GENERATOR_EXPRESSION)
      set_target_properties(${target_name} PROPERTIES MSVC_RUNTIME_LIBRARY
                                                      "${CSCMAKE_MSVC_RUNTIME_LIBRARY_GENERATOR_EXPRESSION}")
    else()
      message(
        FATAL_ERROR
          "CSCMAKE_MSVC_RUNTIME_LIBRARY_GENERATOR_EXPRESSION variable do not exists, have you used properly cs_initialize_project?"
      )
    endif()

    _cs_add_to_global_property_unique_value(CSCMAKE_PROJECT_TARGETS ${target_name})
  endif()
endfunction()

# Finalize target_name by running the recursive dependency analysis (_cs_recursive_analyze_target). Call it once, after
# all the properties and links of the target are set.
function(cs_finalize_target target_name)
  _cs_recursive_analyze_target(${target_name})
endfunction()

# return all targets added in CSCMAKE_PROJECT_TARGETS
function(cs_get_project_targets output_variable_name)
  get_property(list_values GLOBAL PROPERTY CSCMAKE_PROJECT_TARGETS)
  if(list_values)
    # if exists
    set(${output_variable_name}
        ${list_values}
        PARENT_SCOPE)
  else()
    # otherwise set to empty list
    set(${output_variable_name}
        ""
        PARENT_SCOPE)
  endif()
endfunction()

# Print (debug) the targets registered in the CSCMAKE_PROJECT_TARGETS global property.
function(cs_print_project_targets)
  set(targets "")
  cs_get_project_targets(targets)
  list(LENGTH targets count)
  if(count GREATER 0)
    cs_debug_message("cs_print_project_targets ${targets}")
  else()
    cs_debug_message("cs_print_project_targets empty")
  endif()
endfunction()
