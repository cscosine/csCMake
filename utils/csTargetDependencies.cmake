include_guard(GLOBAL)
include(utils/csDebugMessage)
include(utils/csListUtils)
include(utils/csDebugUtils)

# target properties added by this function - CSCMAKE_DIRECT_RUNTIME_LIBRARIES_<CONFIG>: list of dll necessary to the
# target, a variable for each configuration is created - CSCMAKE_LINKED_PROJECT_TARGETS: list of dependent targets that
# are marked as not imported - CSCMAKE_LINKED_NON_TARGETS: list of dependencies that are marked as non-target
function(_cs_recursive_analyze_target target_name)
  # cmake-lint: disable=R0915
  # get target type
  get_target_property(target_type ${target_name} TYPE)

  # initialize the iterative list of target to analyze
  set(targets_to_analyze_list ${target_name})
  list(LENGTH targets_to_analyze_list targets_to_analyze_size)

  # loop
  while(targets_to_analyze_size GREATER 0)
    # get the first target in the list
    list(GET targets_to_analyze_list 0 target_to_analyze)
    # and remove it
    list(REMOVE_AT targets_to_analyze_list 0)

    # get target type
    if(TARGET ${target_to_analyze})
      # get type and imported properties
      get_target_property(target_to_analyze_type ${target_to_analyze} TYPE)
      get_target_property(target_to_analyze_imported ${target_to_analyze} IMPORTED)

      # check aliasing and retrieve original name
      get_target_property(aliased_target_to_analyze ${target_to_analyze} ALIASED_TARGET)
      if(aliased_target_to_analyze)
        cs_debug_message(
          "[_cs_recursive_analyze_target] TARGET_TO_ANALYZE ${target_to_analyze} ALIAS "
          "${aliased_target_to_analyze} TYPE ${target_to_analyze_type} IMPORTED ${target_to_analyze_imported}")
        set(target_to_analyze "${aliased_target_to_analyze}")
      else()
        cs_debug_message(
          "[_cs_recursive_analyze_target] TARGET_TO_ANALYZE ${target_to_analyze} TYPE ${target_to_analyze_type} "
          "IMPORTED ${target_to_analyze_imported}")
      endif()

      # get all link libraries of the TARGET_TO_ANALYZE and add as recoursive dependecies to analyze
      set(target_to_analyze_linked_libs "")
      _cs_get_all_linked_libs(${target_to_analyze} target_to_analyze_linked_libs)
      cs_debug_message(
        "[_cs_recursive_analyze_target] ${target_to_analyze} has the following dependencies to be further "
        "analyzed TARGET_TO_ANALYZE_LINKED_LIBS: ${target_to_analyze_linked_libs}")
      # add to continue the analysis loop
      _cs_list_add_list_unique_values(targets_to_analyze_list "${target_to_analyze_linked_libs}")

      if(NOT target_to_analyze_imported)
        # not imported target, i.e., a target specified inside the project, will be analyzed further for recursive
        # dependencies
        if(NOT ${target_to_analyze} STREQUAL ${target_name})
          cs_debug_message(
            "[_cs_recursive_analyze_target] ${target_to_analyze} is not imported (i.e., is defined in this "
            "project), add it to the list of non resolved recursive dependencies")
          _cs_add_to_target_property_unique_value(${target_name} CSCMAKE_LINKED_PROJECT_TARGETS ${target_to_analyze})
        else()
          cs_debug_message(
            "[_cs_recursive_analyze_target] ${target_to_analyze} is not imported, but is the base target to "
            "analyze, do not add it recursively")
        endif()
      else()
        # if the target is a shared, interface or module library, add its paths
        if((${target_to_analyze_type} STREQUAL "MODULE_LIBRARY")
           OR (${target_to_analyze_type} STREQUAL "SHARED_LIBRARY")
           OR (${target_to_analyze_type} STREQUAL "INTERFACE_LIBRARY"))
          cs_debug_message("[_cs_recursive_analyze_target] ${target_to_analyze} is imported, populate its library path")
          _cs_add_imported_target_locations(${target_name} ${target_to_analyze})
        else()

        endif()
      endif()

    else()
      if(NOT ${target_to_analyze} STREQUAL ${target_name})
        cs_debug_message(
          "[_cs_recursive_analyze_target] TARGET_TO_ANALYZE ${target_to_analyze} is not a target, add it to the "
          "list of non resolved recursive dependencies")
        _cs_add_to_target_property_unique_value(${target_name} CSCMAKE_LINKED_NON_TARGETS ${target_to_analyze})
      else()
        cs_debug_message(
          "[_cs_recursive_analyze_target] TARGET_TO_ANALYZE ${target_to_analyze} is not a target, but is the "
          "base target to analyze, do not add it recursively")
      endif()
    endif()

    # finally refresh while condition variable
    list(LENGTH targets_to_analyze_list targets_to_analyze_size)
  endwhile()

  # print for debug purposes

  # per config
  cs_get_build_configurations(configs_list)
  foreach(config ${configs_list})
    string(TOUPPER "${config}" config_ucase)

    _cs_get_target_direct_runtime_libraries(${target_name} ${config} target_to_analyze_dependencies)
    cs_debug_message("[_cs_recursive_analyze_target] ${target_name} CSCMAKE_DIRECT_RUNTIME_LIBRARIES_${config_ucase}: "
                     "${target_to_analyze_dependencies}")

  endforeach()

  _cs_get_target_linked_project_targets(${target_name} target_to_analyze_dependencies_not_imported_targets)
  cs_debug_message("[_cs_recursive_analyze_target] ${target_name} CSCMAKE_LINKED_PROJECT_TARGETS: "
                   "${target_to_analyze_dependencies_not_imported_targets}")

  _cs_get_target_linked_non_targets(${target_name} target_to_analyze_dependencies_non_targets)
  cs_debug_message("[_cs_recursive_analyze_target] ${target_name} CSCMAKE_LINKED_NON_TARGETS: "
                   "${target_to_analyze_dependencies_non_targets}")

  cs_debug_message("[_cs_recursive_analyze_target] ${target_name} end")

endfunction()

# return CSCMAKE_DIRECT_RUNTIME_LIBRARIES_<config> for target
function(_cs_get_target_direct_runtime_libraries target_name config output_variable_name)
  string(TOUPPER "${config}" config_ucase)
  get_target_property(values ${target_name} CSCMAKE_DIRECT_RUNTIME_LIBRARIES_${config_ucase})
  if(values)
    set(${output_variable_name}
        ${values}
        PARENT_SCOPE)
  else()
    set(${output_variable_name}
        ""
        PARENT_SCOPE)
  endif()
endfunction()

# return CSCMAKE_LINKED_PROJECT_TARGETS for target
function(_cs_get_target_linked_project_targets target_name output_variable_name)
  get_target_property(values ${target_name} CSCMAKE_LINKED_PROJECT_TARGETS)
  if(values)
    set(${output_variable_name}
        ${values}
        PARENT_SCOPE)
  else()
    set(${output_variable_name}
        ""
        PARENT_SCOPE)
  endif()
endfunction()

# * CSCMAKE_LINKED_NON_TARGETS
function(_cs_get_target_linked_non_targets target_name output_variable_name)
  get_target_property(values ${target_name} CSCMAKE_LINKED_NON_TARGETS)
  if(values)
    set(${output_variable_name}
        ${values}
        PARENT_SCOPE)
  else()
    set(${output_variable_name}
        ""
        PARENT_SCOPE)
  endif()
endfunction()

# * CSCMAKE_PROJECT_DEPENDENCIES, created in _cs_recursive_analyze_targets_finalize
function(cs_get_target_project_dependencies target_name output_variable_name)
  get_target_property(values ${target_name} CSCMAKE_PROJECT_DEPENDENCIES)
  if(values)
    set(${output_variable_name}
        ${values}
        PARENT_SCOPE)
  else()
    set(${output_variable_name}
        ""
        PARENT_SCOPE)
  endif()
endfunction()

# * CSCMAKE_RUNTIME_LIBRARIES_<CONFIG>: list of <CONFIG> dll necessary to the target
# * CSCMAKE_PROJECT_DEPENDENCIES: list of other target of this project needed for this target during the execution a
#   variable _CSCMAKE_PENDING_DEPENDENCIES is created as temporary, but it will be used as a "buffer", at exist it is
#   empty
function(_cs_recursive_analyze_targets_finalize targets_list)
  cs_debug_message("[_cs_recursive_analyze_targets_finalize] targets: ${targets_list}")

  # for each target,
  foreach(target_name IN ITEMS ${targets_list})
    # * copy CSCMAKE_DIRECT_RUNTIME_LIBRARIES_<CONFIG> to the Finalized copies
    # * create a unique list of target _CSCMAKE_PENDING_DEPENDENCIES and CSCMAKE_PROJECT_DEPENDENCIES as merge of
    #   CSCMAKE_LINKED_PROJECT_TARGETS and CSCMAKE_LINKED_NON_TARGETS, by selecting only what is effectively a target
    #   and removing aliases
    _cs_prepare_finalize_target(${target_name})
  endforeach()

  # now, for each target, cumulate in Finalized the Finalized of the dependent target. If fully finalized, remove from
  # the list of targets, otherwise add back at the end
  list(LENGTH targets_list targets_list_size)

  # backup of target list
  set(targets_list_original ${targets_list})

  # loop
  while(targets_list_size GREATER 0)
    # get the first target in the list
    list(GET targets_list 0 target_name)
    # and remove it
    list(REMOVE_AT targets_list 0)

    cs_debug_message("[_cs_recursive_analyze_targets_finalize] analyze target ${target_name}")

    _cs_target_is_fully_finalized(${target_name} target_finalized)
    if(NOT target_finalized)
      cs_debug_message("[_cs_recursive_analyze_targets_finalize] target ${target_name} is not finalized")
      # try to finalize
      _cs_target_try_to_finalize(${target_name})
      # and check the result
      _cs_target_is_fully_finalized(${target_name} target_finalized)
      if(NOT target_finalized)
        cs_debug_message(
          "[_cs_recursive_analyze_targets_finalize] target ${target_name} is not finalized yet, readd it")
        _cs_list_add_unique_value(targets_list ${target_name})
      else()
        cs_debug_message("[_cs_recursive_analyze_targets_finalize] target ${target_name} is now finalized!")
      endif()

    else()
      cs_debug_message("[_cs_recursive_analyze_targets_finalize] target ${target_name} is finalized!")
    endif()

    # finally refresh while condition variable
    list(LENGTH targets_list targets_list_size)
  endwhile()

  # print out final dependency list
  cs_debug_message("[_cs_recursive_analyze_targets_finalize] concluded, print final state")
  foreach(target_name IN ITEMS ${targets_list_original})
    cs_get_build_configurations(configs_list)
    foreach(config ${configs_list})
      string(TOUPPER "${config}" config_ucase)
      cs_get_target_runtime_libraries(${target_name} ${config} target_to_analyze_dependencies)
      cs_debug_message(
        "[_cs_recursive_analyze_targets_finalize] ${target_name} CSCMAKE_RUNTIME_LIBRARIES_${config_ucase} : "
        "${target_to_analyze_dependencies}")
    endforeach()
  endforeach()
  cs_debug_message("[_cs_recursive_analyze_targets_finalize] end")

endfunction()

# Merge into the CSCMAKE_RUNTIME_LIBRARIES_<CONFIG> properties of target_name those of its already finalized
# dependencies; the dependencies still pending are kept in _CSCMAKE_PENDING_DEPENDENCIES.
function(_cs_target_try_to_finalize target_name)
  get_target_property(dep_targets ${target_name} _CSCMAKE_PENDING_DEPENDENCIES)

  set(pending_dep_targets "")
  # ${dep_targets} unquoted: one iteration per pending dependency
  foreach(dep_target IN ITEMS ${dep_targets})
    _cs_target_is_fully_finalized(${dep_target} dep_target_finalized)
    if(dep_target_finalized)
      # merge the two finalized list of target and dep target
      cs_get_build_configurations(configs_list)
      foreach(config ${configs_list})
        string(TOUPPER "${config}" config_ucase)

        cs_get_target_runtime_libraries(${target_name} ${config} target_lib)

        cs_get_target_runtime_libraries(${dep_target} ${config} target_lib_dep)

        _cs_list_add_list_unique_values(target_lib "${target_lib_dep}")

        # and set back
        set_property(TARGET ${target_name} PROPERTY CSCMAKE_RUNTIME_LIBRARIES_${config_ucase} "${target_lib}")
      endforeach()

    else()
      _cs_list_add_unique_value(pending_dep_targets ${dep_target})
    endif()
  endforeach()

  cs_debug_message("[_cs_target_try_to_finalize] target ${target_name} pending dependencies ${pending_dep_targets}")
  set_property(TARGET ${target_name} PROPERTY _CSCMAKE_PENDING_DEPENDENCIES "${pending_dep_targets}")

endfunction()

# return true if the _CSCMAKE_PENDING_DEPENDENCIES of the target is empty
function(_cs_target_is_fully_finalized target_name target_finalized)
  get_target_property(values ${target_name} _CSCMAKE_PENDING_DEPENDENCIES)
  if(values)
    set(${target_finalized}
        False
        PARENT_SCOPE)
  else()
    set(${target_finalized}
        True
        PARENT_SCOPE)
  endif()
endfunction()

# this function - copy CSCMAKE_DIRECT_RUNTIME_LIBRARIES_<CONFIG> the CSCMAKE_RUNTIME_LIBRARIES_<CONFIG> copy - merges
# the CSCMAKE_LINKED_PROJECT_TARGETS and CSCMAKE_LINKED_NON_TARGETS and select valid targets, preparing the list in both
# CSCMAKE_PROJECT_DEPENDENCIES and _CSCMAKE_PENDING_DEPENDENCIES _CSCMAKE_PENDING_DEPENDENCIES will be consumed in
# _cs_recursive_analyze_targets_finalize until is empty, while CSCMAKE_PROJECT_DEPENDENCIES remain persistent
function(_cs_prepare_finalize_target target_name)
  cs_debug_message("[_cs_prepare_finalize_target] process target: ${target_name}")

  # copy on Finalized
  cs_get_build_configurations(configs_list)
  foreach(config ${configs_list})
    string(TOUPPER "${config}" config_ucase)

    _cs_get_target_direct_runtime_libraries(${target_name} ${config} target_libs)
    set_property(TARGET ${target_name} PROPERTY CSCMAKE_RUNTIME_LIBRARIES_${config_ucase} "${target_libs}")
    cs_debug_message(
      "[_cs_prepare_finalize_target] ${target_name} CSCMAKE_RUNTIME_LIBRARIES_${config_ucase}: ${target_libs}")
  endforeach()

  # retrieve targets to analyze
  _cs_get_target_linked_project_targets(${target_name} target_not_imported)
  cs_debug_message(
    "[_cs_prepare_finalize_target] ${target_name} CSCMAKE_LINKED_PROJECT_TARGETS: ${target_not_imported}")

  _cs_get_target_linked_non_targets(${target_name} target_non_targets)
  cs_debug_message("[_cs_prepare_finalize_target] ${target_name} CSCMAKE_LINKED_NON_TARGETS: ${target_non_targets}")

  # join the two list
  set(targets_to_analyze_list_raw "")
  foreach(target_to_analyze IN ITEMS ${target_not_imported})
    _cs_list_add_unique_value(targets_to_analyze_list_raw "${target_to_analyze}")
  endforeach()
  foreach(target_to_analyze IN ITEMS ${target_non_targets})
    _cs_list_add_unique_value(targets_to_analyze_list_raw "${target_to_analyze}")
  endforeach()
  cs_debug_message(
    "[_cs_prepare_finalize_target] ${target_name} TARGETS_TO_ANALYZE_LIST_RAW ${targets_to_analyze_list_raw}")

  # select only targets
  set(targets_to_analyze_list "")
  foreach(target_to_analyze IN ITEMS ${targets_to_analyze_list_raw})
    if(TARGET ${target_to_analyze})
      # check aliasing and retrieve original name
      get_target_property(aliased_target_to_analyze ${target_to_analyze} ALIASED_TARGET)
      if(aliased_target_to_analyze)
        set(target_to_analyze "${aliased_target_to_analyze}")
      endif()
      _cs_list_add_unique_value(targets_to_analyze_list "${target_to_analyze}")
    endif()
  endforeach()

  cs_debug_message("[_cs_prepare_finalize_target] ${target_name} TARGETS_TO_ANALYZE_LIST ${targets_to_analyze_list}")
  set_property(TARGET ${target_name} PROPERTY _CSCMAKE_PENDING_DEPENDENCIES "${targets_to_analyze_list}")
  set_property(TARGET ${target_name} PROPERTY CSCMAKE_PROJECT_DEPENDENCIES "${targets_to_analyze_list}")

endfunction()

# return CSCMAKE_RUNTIME_LIBRARIES_<config> (transitive) for target
function(cs_get_target_runtime_libraries target_name config output_variable_name)
  string(TOUPPER "${config}" config_ucase)
  get_target_property(values ${target_name} CSCMAKE_RUNTIME_LIBRARIES_${config_ucase})
  if(values)
    set(${output_variable_name}
        ${values}
        PARENT_SCOPE)
  else()
    set(${output_variable_name}
        ""
        PARENT_SCOPE)
  endif()
endfunction()

# Add the existing IMPORTED_LOCATION_<CONFIG> files of the imported target target_to_analyze to the
# CSCMAKE_DIRECT_RUNTIME_LIBRARIES_<CONFIG> properties of target_name, falling back to IMPORTED_LOCATION when the
# per-configuration location is missing.
function(_cs_add_imported_target_locations target_name target_to_analyze)
  cs_get_build_configurations(configs_list)

  # per config
  foreach(config ${configs_list})
    string(TOUPPER "${config}" config_ucase)
    get_target_property(imported_location_${config_ucase} ${target_to_analyze} IMPORTED_LOCATION_${config_ucase})
    _cs_add_existing_path_to_target_property(${imported_location_${config_ucase}} ${target_name}
                                             CSCMAKE_DIRECT_RUNTIME_LIBRARIES_${config_ucase} ${target_to_analyze})
  endforeach()

  # generic
  get_target_property(imported_location ${target_to_analyze} IMPORTED_LOCATION)
  foreach(config ${configs_list})
    string(TOUPPER "${config}" config_ucase)
    if(imported_location AND NOT imported_location_${config_ucase})
      # if imported location and not specific config, use it
      cs_debug_message(
        "[_cs_add_imported_target_locations] target ${target_to_analyze} has "
        "IMPORTED_LOCATION=${imported_location} but no IMPORTED_LOCATION_${config_ucase}, use IMPORTED_LOCATION "
        "for it")
      set(imported_location_${config_ucase} "${imported_location}")
      _cs_add_existing_path_to_target_property(${imported_location_${config_ucase}} ${target_name}
                                               CSCMAKE_DIRECT_RUNTIME_LIBRARIES_${config_ucase} ${target_to_analyze})
    endif()
  endforeach()

endfunction()

# Append path_value to the target_property of target_name if the file exists, otherwise skip it (target_to_analyze is
# used for the debug message).
function(_cs_add_existing_path_to_target_property path_value target_name target_property target_to_analyze)
  if(path_value)
    # check file exist
    if(EXISTS ${path_value})
      _cs_add_to_target_property_unique_value(${target_name} ${target_property} ${path_value})
    else()
      # not silent: the runtime dependencies (Visual Studio debugger PATH) would miss it
      message(WARNING "[csCMake] ${target_name} depends on the imported target ${target_to_analyze}, whose file "
                      "${path_value} does not exist: not added to its runtime libraries")
    endif()
  endif()
endfunction()

# Return in target_to_analyze_linked_libs_out every library target_to_analyze links to, without duplicates:
# (INTERFACE_)LINK_LIBRARIES, the legacy LINK_INTERFACE_LIBRARIES, the imported link interfaces and the link depends,
# including their per-configuration variants.
function(_cs_get_all_linked_libs target_to_analyze target_to_analyze_linked_libs_out)
  cs_get_build_configurations(configs_list)

  set(target_to_analyze_linked_libs "")

  get_target_property(tmp_list ${target_to_analyze} LINK_LIBRARIES)
  _cs_list_add_list_unique_values(target_to_analyze_linked_libs "${tmp_list}")

  # interface link (seems to be legacy...)
  get_target_property(tmp_list ${target_to_analyze} LINK_INTERFACE_LIBRARIES)
  _cs_list_add_list_unique_values(target_to_analyze_linked_libs "${tmp_list}")

  foreach(config ${configs_list})
    string(TOUPPER "${config}" config_ucase)

    get_target_property(tmp_list ${target_to_analyze} LINK_INTERFACE_LIBRARIES_${config_ucase})
    _cs_list_add_list_unique_values(target_to_analyze_linked_libs "${tmp_list}")
  endforeach()

  # interface link depends
  get_target_property(tmp_list ${target_to_analyze} INTERFACE_LINK_DEPENDS)
  _cs_list_add_list_unique_values(target_to_analyze_linked_libs "${tmp_list}")

  # interface link libraries
  get_target_property(tmp_list ${target_to_analyze} INTERFACE_LINK_LIBRARIES)
  _cs_list_add_list_unique_values(target_to_analyze_linked_libs "${tmp_list}")

  foreach(config ${configs_list})
    string(TOUPPER "${config}" config_ucase)

    get_target_property(tmp_list ${target_to_analyze} INTERFACE_LINK_LIBRARIES_${config_ucase})
    _cs_list_add_list_unique_values(target_to_analyze_linked_libs "${tmp_list}")
  endforeach()

  # imported interface link libraries
  get_target_property(tmp_list ${target_to_analyze} IMPORTED_LINK_INTERFACE_LIBRARIES)
  _cs_list_add_list_unique_values(target_to_analyze_linked_libs "${tmp_list}")

  foreach(config ${configs_list})
    string(TOUPPER "${config}" config_ucase)

    get_target_property(tmp_list ${target_to_analyze} IMPORTED_LINK_INTERFACE_LIBRARIES_${config_ucase})
    _cs_list_add_list_unique_values(target_to_analyze_linked_libs "${tmp_list}")
  endforeach()

  # link depends
  get_target_property(tmp_list ${target_to_analyze} LINK_DEPENDS)
  _cs_list_add_list_unique_values(target_to_analyze_linked_libs "${tmp_list}")

  # link dependent
  get_target_property(tmp_list ${target_to_analyze} IMPORTED_LINK_DEPENDENT_LIBRARIES)
  _cs_list_add_list_unique_values(target_to_analyze_linked_libs "${tmp_list}")

  foreach(config ${configs_list})
    string(TOUPPER "${config}" config_ucase)

    get_target_property(tmp_list ${target_to_analyze} IMPORTED_LINK_DEPENDENT_LIBRARIES_${config_ucase})
    _cs_list_add_list_unique_values(target_to_analyze_linked_libs "${tmp_list}")
  endforeach()

  get_target_property(tmp_list ${target_to_analyze} MANUALLY_ADDED_DEPENDENCIES)
  _cs_list_add_list_unique_values(target_to_analyze_linked_libs "${tmp_list}")

  # set output value
  set(${target_to_analyze_linked_libs_out}
      ${target_to_analyze_linked_libs}
      PARENT_SCOPE)
endfunction()
