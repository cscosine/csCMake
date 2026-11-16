#.rst:
# csFindPackage
# -------------
#
# Dependencies found with :command:`find_package` and propagated to the installed package, and the checks of csCMake on
# every package found.
#
# Checks on the packages found
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
#
# After a package is found, csCMake runs :command:`cs_after_find_dependency`: from :command:`cs_find_package`, and from
# the ``<namespace>Config.cmake`` of a csCMake package after each of its :command:`find_dependency` (so a consumer
# checks the packages its dependencies bring too). It runs, in order:
#
# 1. the checks of every package: the macOS deployment target the package recorded is not newer than the one of the
#    project (:doc:`csMacosDeploymentTarget`);
# 2. the hooks registered for that package name (:command:`cs_add_after_find_hook`): what only that library needs.
#
# A library with special needs gets a hook, in an integration module of csCMake (``modules/integrations/cs<Lib>.cmake``,
# included by ``csCMake.cmake``; e.g. :doc:`csQt`), or in the project itself:
#
# .. code-block:: cmake
#
#   # the check: called with the package name, in the scope of the find (it reads the variables of the package)
#   function(_cs_mylib_after_find package)
#     set_property(GLOBAL PROPERTY _CSCMAKE_MYLIB_CHECKED TRUE)   # optional: e.g. to detect a plain find_package
#     cs_require_macos_deployment_target("${MYLIB_MIN_MACOS}" REASON "MyLib ${MyLib_VERSION}")
#   endfunction()
#   cs_add_after_find_hook(MyLib _cs_mylib_after_find)
#
# Rules of a hook: a function (not a macro), named ``_cs_<lib>_after_find`` in an integration; it reads the variables
# of the package (visible, the caller's scope) and sets nothing in it; it fails with :command:`message` ``(FATAL_ERROR
# ...)`` saying what to change. It runs only when the package is found, and only through csCMake: a plain
# :command:`find_package` runs no hook (an integration that needs it can enforce it at the end of the project, as
# :doc:`csQt` does).
#
# Commands
# ^^^^^^^^
include_guard(GLOBAL)
include(modules/csDebug)
include(modules/csInternal)
include(modules/csMacosDeploymentTarget)

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
#   installed <namespace>Config.cmake; PRIVATE: found for the build only. Then the checks of csCMake on the package
#   (:command:`cs_after_find_dependency`).
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

#.rst:
# .. command:: cs_after_find_dependency
#
#   Run the checks of csCMake on a package just found (`Checks on the packages found`_).
#
#   .. code-block:: cmake
#
#     cs_after_find_dependency(<package>)
#
#   Called by :command:`cs_find_package` and by the ``<namespace>Config.cmake`` of csCMake packages (when the consumer
#   has csCMake); a project calls it only after a :command:`find_package` of its own. Nothing when ``<package>_FOUND``
#   is false.
#
#   :Reads: global property ``_CSCMAKE_AFTER_FIND_HOOKS_<package>``
function(cs_after_find_dependency package)
  if(NOT ${package}_FOUND)
    return()
  endif()
  _cs_check_recorded_macos_deployment_target(${package})
  get_property(hooks GLOBAL PROPERTY _CSCMAKE_AFTER_FIND_HOOKS_${package})
  foreach(hook IN LISTS hooks)
    cmake_language(CALL ${hook} ${package})
  endforeach()
endfunction()

#.rst:
# .. command:: cs_add_after_find_hook
#
#   Register a check for one package: ``<function>(<package>)`` runs each time csCMake finds ``<package>``
#   (`Checks on the packages found`_).
#
#   .. code-block:: cmake
#
#     cs_add_after_find_hook(<package> <function>)
#
#   ``<package>``
#     The package name as given to :command:`find_package` (e.g. ``Qt6``).
#
#   ``<function>``
#     A function taking the package name; the hooks of a package run in the order they are registered.
#
#   :Writes: global property ``_CSCMAKE_AFTER_FIND_HOOKS_<package>``
function(cs_add_after_find_hook package function_name)
  if(NOT COMMAND ${function_name})
    message(FATAL_ERROR "[cs_add_after_find_hook] ${package}: ${function_name} is not a function (define it first)")
  endif()
  set_property(GLOBAL APPEND PROPERTY _CSCMAKE_AFTER_FIND_HOOKS_${package} ${function_name})
endfunction()

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
  # the checks of csCMake on the package found (macOS deployment target, integrations)
  list(GET ARGN 0 package)
  cs_after_find_dependency(${package})

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
#
# Global properties
# ^^^^^^^^^^^^^^^^^
#
# .. prop_gbl:: _CSCMAKE_AFTER_FIND_HOOKS_<package>
#
#   Internal: the hooks of the package, in the order they are registered (:command:`cs_add_after_find_hook`).
