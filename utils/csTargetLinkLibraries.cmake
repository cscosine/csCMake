include_guard(GLOBAL)
include(utils/csDebugMessage)

# Drop-in replacement for target_link_libraries(target_name ...): links target_name to the arguments (PUBLIC, PRIVATE
# and INTERFACE keywords included), resolving aliases of project targets to the real target.
function(cs_target_link_libraries target_name)
  cs_debug_message("[cs_target_link_libraries] ${target_name} ${ARGN}")

  set(link_targets_list "")
  foreach(linked_target ${ARGN})
    if(${linked_target} STREQUAL "INTERFACE"
       OR ${linked_target} STREQUAL "PUBLIC"
       OR ${linked_target} STREQUAL "PRIVATE")
      list(APPEND link_targets_list ${linked_target})
      continue()
    else()
      cs_debug_message("[cs_target_link_libraries] analyze ${linked_target} lib")
      if(TARGET ${linked_target})
        get_target_property(linked_target_imported ${linked_target} IMPORTED)
        if(linked_target_imported)
          list(APPEND link_targets_list ${linked_target})
          cs_debug_message(
            "[cs_target_link_libraries] ${target_name} links to ${linked_target} which is a IMPORTED target")
        else()
          get_target_property(aliased_linked_target ${linked_target} ALIASED_TARGET)
          if(aliased_linked_target)
            list(APPEND link_targets_list ${aliased_linked_target})
            cs_debug_message(
              "[cs_target_link_libraries] ${target_name} links to ${linked_target} which is a alias for project target ${aliased_linked_target}"
            )
          else()
            list(APPEND link_targets_list ${linked_target})
            cs_debug_message(
              "[cs_target_link_libraries] ${target_name} links to ${linked_target} which is a project target")
          endif()
        endif()
      else()
        list(APPEND link_targets_list ${linked_target})
        cs_debug_message(
          "[cs_target_link_libraries] ${target_name} links to ${linked_target} which is not a target.\n Check your target creation order to remove this warning."
        )
      endif()
    endif()
  endforeach()

  # TODO(sc) if the target contains generator expression, we might need to skip it to avoid too many warning emitted
  # string(GENEX_STRIP "${FOO_POSSIBLY_RELATIVE_POSSIBLY_GENEX_PATH}" no_genex)

  cs_debug_message("[cs_target_link_libraries] original  ${target_name} ${ARGN}" True)
  cs_debug_message("[cs_target_link_libraries] converted ${target_name} ${link_targets_list}" True)

  target_link_libraries("${target_name}" ${link_targets_list})
endfunction()
