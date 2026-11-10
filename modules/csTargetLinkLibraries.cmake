#.rst:
# csTargetLinkLibraries
# ---------------------
#
# Links between targets.
#
# Commands
# ^^^^^^^^
include_guard(GLOBAL)
include(modules/csDebug)

#.rst:
# .. command:: cs_target_link_libraries
#
#   Link a target, like :command:`target_link_libraries`, resolving the aliases of the project targets.
#
#   .. code-block:: cmake
#
#     cs_target_link_libraries(<target> <target_link_libraries arguments>...)
#
#   The scope keywords stay where they are; an ALIAS of a project target becomes the target itself, imported targets and
#   names that are not targets are passed unchanged.
#
#   ``<target>``
#     A target of the project.
#
#   ``<target_link_libraries arguments>``
#     The other arguments of :command:`target_link_libraries`: scope keywords and libraries.
function(cs_target_link_libraries target_name)
  cs_debug_message("[cs_target_link_libraries] ${target_name} ${ARGN}")

  set(link_targets_list "")
  foreach(linked_target ${ARGN})
    if(
      "${linked_target}" STREQUAL "INTERFACE"
      OR "${linked_target}" STREQUAL "PUBLIC"
      OR "${linked_target}" STREQUAL "PRIVATE"
    )
      list(APPEND link_targets_list ${linked_target})
      continue()
    else()
      cs_debug_message("[cs_target_link_libraries] analyze ${linked_target} lib")
      if(TARGET ${linked_target})
        get_target_property(linked_target_imported ${linked_target} IMPORTED)
        if(linked_target_imported)
          list(APPEND link_targets_list ${linked_target})
          cs_debug_message(
            "[cs_target_link_libraries] ${target_name} links to ${linked_target} which is a IMPORTED target"
          )
        else()
          get_target_property(aliased_linked_target ${linked_target} ALIASED_TARGET)
          if(aliased_linked_target)
            list(APPEND link_targets_list ${aliased_linked_target})
            cs_debug_message(
              "[cs_target_link_libraries] ${target_name} links to ${linked_target} which is a alias for project "
              "target ${aliased_linked_target}"
            )
          else()
            list(APPEND link_targets_list ${linked_target})
            cs_debug_message(
              "[cs_target_link_libraries] ${target_name} links to ${linked_target} which is a project target"
            )
          endif()
        endif()
      else()
        list(APPEND link_targets_list ${linked_target})
        cs_debug_message(
          "[cs_target_link_libraries] ${target_name} links to ${linked_target} which is not a target.\n Check "
          "your target creation order to remove this warning."
        )
      endif()
    endif()
  endforeach()

  # TODO(sc) if the target contains generator expression, we might need to skip it to avoid too many warning emitted
  # string(GENEX_STRIP "${FOO_POSSIBLY_RELATIVE_POSSIBLY_GENEX_PATH}" no_genex)

  cs_debug_message("[cs_target_link_libraries] original  ${target_name} ${ARGN}")
  cs_debug_message("[cs_target_link_libraries] converted ${target_name} ${link_targets_list}")

  target_link_libraries("${target_name}" ${link_targets_list})
endfunction()
