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
#   Link a target, like :command:`target_link_libraries`, before :command:`cs_finalize_target`.
#
#   .. code-block:: cmake
#
#     cs_target_link_libraries(<target> <target_link_libraries arguments>...)
#
#   The arguments go to :command:`target_link_libraries` as they are. A link added after
#   :command:`cs_finalize_target` fails here: the target is finalized with its links (compile profiles, install RPATH,
#   the dependencies between components), so they must come first.
#
#   ``<target>``
#     A target of the project (an alias of one is accepted for the check).
#
#   ``<target_link_libraries arguments>``
#     The other arguments of :command:`target_link_libraries`: scope keywords and libraries.
#
#   :Reads: :prop_tgt:`_CSCMAKE_FINALIZED_LINKS`
function(cs_target_link_libraries target_name)
  cs_debug_message("[cs_target_link_libraries] ${target_name} ${ARGN}")
  set(checked "${target_name}")
  if(TARGET "${target_name}")
    get_target_property(aliased "${target_name}" ALIASED_TARGET)
    if(aliased)
      set(checked "${aliased}")
    endif()
    get_property(finalized TARGET "${checked}" PROPERTY _CSCMAKE_FINALIZED_LINKS SET)
    if(finalized)
      message(
        FATAL_ERROR
        "[cs_target_link_libraries] ${target_name}: links after cs_finalize_target(${target_name}); link it first, "
        "then finalize it"
      )
    endif()
  endif()
  target_link_libraries("${target_name}" ${ARGN})
endfunction()
