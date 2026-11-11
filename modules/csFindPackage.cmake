#.rst:
# csFindPackage
# -------------
#
# Dependencies found with :command:`find_package` and propagated to the installed package.
#
# Commands
# ^^^^^^^^
include_guard(GLOBAL)
include(modules/csDebug)
include(modules/csInternal)

#.rst:
# .. command:: cs_find_package
#
#   Find a package for a target, like :command:`find_package`, and propagate it to the installed package if PUBLIC.
#
#   .. code-block:: cmake
#
#     cs_find_package(<target> PUBLIC|PRIVATE <find_package arguments>...)
#
#   A macro: the variables of :command:`find_package` are visible to the caller. PUBLIC: the same
#   :command:`find_package` arguments become a :command:`find_dependency` of the component of the target in the
#   installed <namespace>Config.cmake; PRIVATE: found for the build only.
#
#   ``<target>``
#     A target of the project.
#
#   ``PUBLIC``, ``PRIVATE``
#     ``PUBLIC``: propagated to the installed package (:command:`find_dependency` when the component of the target is
#     loaded); ``PRIVATE``: for the build only.
#
#   ``<find_package arguments>``
#     The arguments of :command:`find_package`: the package name, then ``COMPONENTS``, ``REQUIRED``, ``CONFIG``, ...
#
#   :Writes: :prop_tgt:`CSCMAKE_FIND_PACKAGES`
macro(cs_find_package target_name propagate_mode)
  # the mode is checked before find_package runs
  _cs_check_find_package_mode("${target_name}" "${propagate_mode}")
  # this has to be a macro, because some find_package out variable needs to be visible to the caller
  find_package(${ARGN})
  _cs_add_find_package_args_to_target("${target_name}" "${propagate_mode}" "${ARGN}")
endmacro()

# Return the PUBLIC :command:`find_package` arguments of a target (:command:`cs_find_package`).
#
# Reads:
#
# * target property CSCMAKE_FIND_PACKAGES
function(_cs_get_target_find_packages target_name output_variable_name)
  # empty when the property is not set
  get_property(list_values TARGET ${target_name} PROPERTY CSCMAKE_FIND_PACKAGES)
  set(${output_variable_name} "${list_values}" PARENT_SCOPE)
endfunction()

# Fail unless propagate_mode is PUBLIC or PRIVATE (cs_find_package, before find_package runs).
function(_cs_check_find_package_mode target_name propagate_mode)
  if(NOT propagate_mode MATCHES "^(PUBLIC|PRIVATE)$")
    message(FATAL_ERROR "[cs_find_package] ${target_name}: the mode is PUBLIC or PRIVATE, got ${propagate_mode}")
  endif()
endfunction()

# Report (VERBOSE) the find_package of target_name (cs_find_package, called after find_package in the scope of the
# caller): the arguments, the mode, and the result: version and folder when found.
#
# Reads:
#
# * variable <package>_FOUND, <package>_VERSION, <package>_DIR (set by find_package)
function(_cs_report_found_package target_name propagate_mode package)
  _cs_log_level_at_least(VERBOSE shown)
  if(NOT shown)
    return()
  endif()
  list(JOIN ARGN " " arguments)
  if(propagate_mode STREQUAL "PUBLIC")
    set(text "${CSCMAKE_NAMESPACE}: ${target_name} finds ${package} ${arguments} (PUBLIC: its consumers too)")
  else()
    set(text "${CSCMAKE_NAMESPACE}: ${target_name} finds ${package} ${arguments} (PRIVATE)")
  endif()
  if(${package}_FOUND)
    string(APPEND text ": found")
    if(NOT "${${package}_VERSION}" STREQUAL "")
      string(APPEND text " ${${package}_VERSION}")
    endif()
    if(${package}_DIR)
      string(APPEND text " in ${${package}_DIR}")
    endif()
  else()
    string(APPEND text ": not found")
  endif()
  message(VERBOSE "${text}")
endfunction()

# Record the find_package arguments ARGN of target_name when propagate_mode is PUBLIC.
#
# Writes:
#
# * target property CSCMAKE_FIND_PACKAGES
function(_cs_add_find_package_args_to_target target_name propagate_mode)
  _cs_message_context(cs_find_package)
  list(JOIN ARGN " " joined_argn)
  _cs_report_found_package(${target_name} ${propagate_mode} ${ARGN})

  if(propagate_mode STREQUAL "PUBLIC")
    _cs_add_to_target_property_unique_value("${target_name}" CSCMAKE_FIND_PACKAGES "${joined_argn}")
  endif()
endfunction()

#.rst:
# Target properties
# ^^^^^^^^^^^^^^^^^
#
# .. prop_tgt:: CSCMAKE_FIND_PACKAGES
#
#   The ``PUBLIC`` :command:`find_package` arguments of the target (:command:`cs_find_package`), one ``;``-escaped entry
#   per call.
