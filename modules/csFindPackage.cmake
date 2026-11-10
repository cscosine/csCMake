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
  cs_debug_message("[cs_find_package] target ${target_name} find ${ARGN} with mode ${propagate_mode}")

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

# Print the PUBLIC :command:`find_package` arguments of a target (debug messages).
function(_cs_print_target_find_packages target_name)
  set(packages "")
  _cs_get_target_find_packages("${target_name}" packages)
  list(LENGTH packages count)
  if(count GREATER 0)
    cs_debug_message("_cs_print_target_find_packages ${target_name}: ${packages}")
  else()
    cs_debug_message("_cs_print_target_find_packages ${target_name} empty")
  endif()
endfunction()

# Record the find_package arguments ARGN of target_name when propagate_mode is PUBLIC; fail if it is neither PUBLIC nor
# PRIVATE.
#
# Writes:
#
# * target property CSCMAKE_FIND_PACKAGES
function(_cs_add_find_package_args_to_target target_name propagate_mode)
  list(JOIN ARGN " " joined_argn)
  cs_debug_message("[_cs_add_find_package_args_to_target] target ${target_name} arguments ${joined_argn}")

  if(NOT propagate_mode MATCHES "^(PUBLIC|PRIVATE)$")
    message(FATAL_ERROR "[cs_find_package] ${target_name}: the mode is PUBLIC or PRIVATE, got ${propagate_mode}")
  endif()
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
