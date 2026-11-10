#.rst:
# csAddLibraryExecutable
# ----------------------
#
# The targets of the project.
#
# Commands
# ^^^^^^^^
include_guard(GLOBAL)
include(utils/csDebugMessage)
include(utils/csListUtils)

#.rst:
# .. command:: cs_add_library
#
#   Add a library to the project, like :command:`add_library`.
#
#   .. code-block:: cmake
#
#     cs_add_library(<target> <add_library arguments>...)
#
#   The library gets the output name postfix of each configuration and the MSVC runtime library of the project, and is
#   registered in the project (:command:`cs_finalize_target` is then mandatory for it). An ALIAS is created as with
#   :command:`add_library` and not registered.
function(cs_add_library target_name)
  add_library("${target_name}" ${ARGN})
  _cs_add_target_to_project_targets(${target_name})
endfunction()

#.rst:
# .. command:: cs_add_executable
#
#   Add an executable to the project, like :command:`add_executable`.
#
#   .. code-block:: cmake
#
#     cs_add_executable(<target> <add_executable arguments>...)
#
#   As :command:`cs_add_library`: output name postfixes, MSVC runtime library, registered in the project
#   (:command:`cs_finalize_target` is mandatory).
function(cs_add_executable target_name)
  add_executable("${target_name}" ${ARGN})
  _cs_add_target_to_project_targets(${target_name})
endfunction()

# Register target_name in the project (unless it is an ALIAS): output name postfix of each configuration, MSVC runtime
# library, namespace. Fails if cs_initialize_project was not called.
#
# Reads:
#
# * variable CSCMAKE_<CONFIG>_POSTFIX
# * variable CSCMAKE_MSVC_RUNTIME_LIBRARY_GENERATOR_EXPRESSION
#
# Writes:
#
# * target property <CONFIG>_POSTFIX, MSVC_RUNTIME_LIBRARY
# * target property CSCMAKE_NAMESPACE: the namespace of the project of the target
# * global property CSCMAKE_<namespace>_PROJECT_TARGETS: the targets of the project
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

#.rst:
# .. command:: cs_finalize_target
#
#   Finalize a target: apply its compile profiles, analyze its runtime dependencies, record its links.
#
#   .. code-block:: cmake
#
#     cs_finalize_target(<target>)
#
#   Mandatory for every target of :command:`cs_add_library` / :command:`cs_add_executable`, after its links:
#   :command:`cs_finalize_project` fails for a target not finalized, or whose links changed afterwards.
#
#   :Writes: :prop_tgt:`_CSCMAKE_FINALIZED_LINKS`
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

# Return in links_out the links of target_name (LINK_LIBRARIES and INTERFACE_LINK_LIBRARIES) as a single string.
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

# Fail if a target of the project was not finalized with cs_finalize_target, or if its links changed after it.
#
# Reads:
#
# * global property CSCMAKE_<namespace>_PROJECT_TARGETS
# * target property _CSCMAKE_FINALIZED_LINKS
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

#.rst:
# .. command:: cs_get_project_targets
#
#   Return the targets of the project (:command:`cs_add_library`, :command:`cs_add_executable`, the default target).
#
#   .. code-block:: cmake
#
#     cs_get_project_targets(<out-var>)
#
#   :Reads: :prop_gbl:`CSCMAKE_<namespace>_PROJECT_TARGETS`
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

#.rst:
# .. command:: cs_print_project_targets
#
#   Print the targets of the project (debug messages).
#
#   .. code-block:: cmake
#
#     cs_print_project_targets()
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

#.rst:
# Target properties
# ^^^^^^^^^^^^^^^^^
#
# .. prop_tgt:: CSCMAKE_NAMESPACE
#
#   The namespace of the project of the target.
#
# .. prop_tgt:: _CSCMAKE_FINALIZED_LINKS
#
#   Internal: the links of the target when :command:`cs_finalize_target` ran.
#
# Global properties
# ^^^^^^^^^^^^^^^^^
#
# .. prop_gbl:: CSCMAKE_<namespace>_PROJECT_TARGETS
#
#   The targets of the project: :command:`cs_add_library`, :command:`cs_add_executable`, the default target.
