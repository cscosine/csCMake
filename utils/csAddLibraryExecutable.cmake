include_guard(GLOBAL)
include(utils/csDebugMessage)
include(utils/csListUtils)

# add a target as library and add to list CSCMAKE_<namespace>_PROJECT_TARGETS
function(cs_add_library target_name)
  add_library("${target_name}" ${ARGN})
  _cs_add_target_to_project_targets(${target_name})
endfunction()

# add a target as executable and add to list CSCMAKE_<namespace>_PROJECT_TARGETS
function(cs_add_executable target_name)
  add_executable("${target_name}" ${ARGN})
  _cs_add_target_to_project_targets(${target_name})
endfunction()

# Register target_name (unless it is an ALIAS) in the CSCMAKE_<namespace>_PROJECT_TARGETS global property, after setting
# on it the per- configuration output postfix (CSCMAKE_<CONFIG>_POSTFIX) and the MSVC runtime library generator
# expression. Fails if cs_initialize_project did not define them.
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
            "CSCMAKE_${config}_POSTFIX variable do not exists, call cs_initialize_project before adding targets")
      endif()

    endforeach()

    # path to allow execution inside visual studio
    if(DEFINED CSCMAKE_MSVC_RUNTIME_LIBRARY_GENERATOR_EXPRESSION)
      set_target_properties(${target_name} PROPERTIES MSVC_RUNTIME_LIBRARY
                                                      "${CSCMAKE_MSVC_RUNTIME_LIBRARY_GENERATOR_EXPRESSION}")
    else()
      message(
        FATAL_ERROR
          "CSCMAKE_MSVC_RUNTIME_LIBRARY_GENERATOR_EXPRESSION variable do not exists, call cs_initialize_project "
          "before adding targets")
    endif()

    # the csCMake project of the target (its namespace): used for the links between projects of the same build
    set_property(TARGET ${target_name} PROPERTY CSCMAKE_NAMESPACE ${CSCMAKE_NAMESPACE})
    _cs_add_to_global_property_unique_value(CSCMAKE_${CSCMAKE_NAMESPACE}_PROJECT_TARGETS ${target_name})
  endif()
endfunction()

# Finalize target_name: run the recursive dependency analysis (_cs_recursive_analyze_target) and record its links.
# Mandatory for every target of cs_add_library / cs_add_executable, after its links are set: cs_finalize_project fails
# for a target not finalized, or whose links changed after cs_finalize_target.
function(cs_finalize_target target_name)
  get_target_property(aliased ${target_name} ALIASED_TARGET)
  if(aliased)
    set(target_name ${aliased})
  endif()
  get_property(
    finalized
    TARGET ${target_name}
    PROPERTY _CSCMAKE_FINALIZED_LINKS
    SET)
  if(NOT finalized)
    _cs_apply_compile_profiles(${target_name})
  endif()
  _cs_recursive_analyze_target(${target_name})
  _cs_target_links(${target_name} links)
  set_property(TARGET ${target_name} PROPERTY _CSCMAKE_FINALIZED_LINKS "${links}")
endfunction()

# Return in links_out the links of target_name (LINK_LIBRARIES and INTERFACE_LINK_LIBRARIES), as a single string.
function(_cs_target_links target_name links_out)
  set(links "")
  foreach(property LINK_LIBRARIES INTERFACE_LINK_LIBRARIES)
    get_target_property(values ${target_name} ${property})
    if(NOT values)
      set(values "")
    endif()
    string(APPEND links "${property}=${values} ")
  endforeach()
  set(${links_out}
      "${links}"
      PARENT_SCOPE)
endfunction()

# Fail (FATAL_ERROR) if a target of the project was not finalized with cs_finalize_target, or if its links changed after
# cs_finalize_target (finalized too early: the dependency analysis missed the later links).
function(_cs_check_targets_finalized)
  cs_get_project_targets(targets)
  set(not_finalized "")
  set(changed "")
  foreach(target_name ${targets})
    get_property(
      finalized
      TARGET ${target_name}
      PROPERTY _CSCMAKE_FINALIZED_LINKS
      SET)
    if(NOT finalized)
      list(APPEND not_finalized ${target_name})
    else()
      get_target_property(recorded ${target_name} _CSCMAKE_FINALIZED_LINKS)
      _cs_target_links(${target_name} current)
      if(NOT "${recorded}" STREQUAL "${current}")
        list(APPEND changed ${target_name})
      endif()
    endif()
  endforeach()
  if(not_finalized)
    list(JOIN not_finalized ", " not_finalized)
    message(FATAL_ERROR "[cs_finalize_project] cs_finalize_target(<target>) is required for every target, after its "
                        "links: missing for ${not_finalized}")
  endif()
  if(changed)
    list(JOIN changed ", " changed)
    message(FATAL_ERROR "[cs_finalize_project] links added after cs_finalize_target: ${changed} (call "
                        "cs_finalize_target after cs_target_link_libraries)")
  endif()
endfunction()

# return all targets added in CSCMAKE_<namespace>_PROJECT_TARGETS
function(cs_get_project_targets output_variable_name)
  get_property(list_values GLOBAL PROPERTY CSCMAKE_${CSCMAKE_NAMESPACE}_PROJECT_TARGETS)
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

# Print (debug) the targets registered in the CSCMAKE_<namespace>_PROJECT_TARGETS global property.
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
