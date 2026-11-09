include_guard(GLOBAL)
include(utils/csDebugMessage)

# Drop-in replacement for target_link_libraries(TARGET_NAME ...): links TARGET_NAME to the arguments (PUBLIC, PRIVATE
# and INTERFACE keywords included), resolving aliases of project targets to the real target.
function(cs_target_link_libraries TARGET_NAME)
  cs_debug_message("[cs_target_link_libraries] ${TARGET_NAME} ${ARGN}")

  set(LINK_TARGETS_LIST "")
  foreach(LINKED_TARGET ${ARGN})
    if(${LINKED_TARGET} STREQUAL "INTERFACE"
       OR ${LINKED_TARGET} STREQUAL "PUBLIC"
       OR ${LINKED_TARGET} STREQUAL "PRIVATE")
      list(APPEND LINK_TARGETS_LIST ${LINKED_TARGET})
      continue()
    else()
      cs_debug_message("[cs_target_link_libraries] analyze ${LINKED_TARGET} lib")
      if(TARGET ${LINKED_TARGET})
        get_target_property(LINKED_TARGET_IMPORTED ${LINKED_TARGET} IMPORTED)
        if(LINKED_TARGET_IMPORTED)
          list(APPEND LINK_TARGETS_LIST ${LINKED_TARGET})
          cs_debug_message(
            "[cs_target_link_libraries] ${TARGET_NAME} links to ${LINKED_TARGET} which is a IMPORTED target")
        else()
          get_target_property(ALIASED_LINKED_TARGET ${LINKED_TARGET} ALIASED_TARGET)
          if(ALIASED_LINKED_TARGET)
            list(APPEND LINK_TARGETS_LIST ${ALIASED_LINKED_TARGET})
            cs_debug_message(
              "[cs_target_link_libraries] ${TARGET_NAME} links to ${LINKED_TARGET} which is a alias for project target ${ALIASED_LINKED_TARGET}"
            )
          else()
            list(APPEND LINK_TARGETS_LIST ${LINKED_TARGET})
            cs_debug_message(
              "[cs_target_link_libraries] ${TARGET_NAME} links to ${LINKED_TARGET} which is a project target")
          endif()
        endif()
      else()
        list(APPEND LINK_TARGETS_LIST ${LINKED_TARGET})
        cs_debug_message(
          "[cs_target_link_libraries] ${TARGET_NAME} links to ${LINKED_TARGET} which is not a target.\n Check your target creation order to remove this warning."
        )
      endif()
    endif()
  endforeach()

  # TODO(sc) if the target contains generator expression, we might need to skip it to avoid too many warning emitted
  # string(GENEX_STRIP "${FOO_POSSIBLY_RELATIVE_POSSIBLY_GENEX_PATH}" no_genex)

  cs_debug_message("[cs_target_link_libraries] original  ${TARGET_NAME} ${ARGN}" True)
  cs_debug_message("[cs_target_link_libraries] converted ${TARGET_NAME} ${LINK_TARGETS_LIST}" True)

  target_link_libraries("${TARGET_NAME}" ${LINK_TARGETS_LIST})
endfunction()
