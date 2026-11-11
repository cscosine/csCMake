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
#   Link a target, like :command:`target_link_libraries`, before its project is finalized.
#
#   .. code-block:: cmake
#
#     cs_target_link_libraries(<target> <target_link_libraries arguments>...)
#
#   The arguments go to :command:`target_link_libraries` as they are. A link added after the project of the target is
#   finalized (end of the ``CMakeLists.txt`` of :command:`cs_initialize_project`, e.g. from a parent project) fails
#   here: the dependencies between components are computed from the links at that moment.
#
#   ``<target>``
#     A target of the project (an alias of one is accepted for the check).
#
#   ``<target_link_libraries arguments>``
#     The other arguments of :command:`target_link_libraries`: scope keywords and libraries.
#
#   :Reads: :prop_tgt:`_CSCMAKE_FINALIZED`
function(cs_target_link_libraries target_name)
  _cs_message_context(cs_target_link_libraries)
  list(JOIN ARGN " " links)
  message(DEBUG "${CSCMAKE_NAMESPACE}: ${target_name} links ${links}")
  set(checked "${target_name}")
  if(TARGET "${target_name}")
    get_target_property(aliased "${target_name}" ALIASED_TARGET)
    if(aliased)
      set(checked "${aliased}")
    endif()
    get_property(finalized TARGET "${checked}" PROPERTY _CSCMAKE_FINALIZED SET)
    if(finalized)
      message(
        FATAL_ERROR
        "[cs_target_link_libraries] ${target_name}: its project is already finalized (end of the CMakeLists.txt of "
        "its cs_initialize_project); link it in its own project"
      )
    endif()
  endif()
  target_link_libraries("${target_name}" ${ARGN})
endfunction()
