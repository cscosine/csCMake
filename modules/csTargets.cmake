#.rst:
# csTargets
# ---------
#
# The targets of the project: :command:`cs_add_library` / :command:`cs_add_executable` register them; at the end of
# the ``CMakeLists.txt`` of :command:`cs_initialize_project`, csCMake finalizes them (compile profiles) with the
# project.
#
# Commands
# ^^^^^^^^

include_guard(GLOBAL)
include(modules/csDebug)
include(modules/csInternal)

#.rst:
# .. command:: cs_add_library
#
#   Add a library to the project, like :command:`add_library`.
#
#   .. code-block:: cmake
#
#     cs_add_library(<target> <add_library arguments>...)
#
#   The library gets the output name postfix of each configuration, the MSVC runtime library of the project, its compile
#   profiles (:prop_tgt:`CSCMAKE_COMPILE_PROFILES`, from :variable:`CSCMAKE_DEFAULT_COMPILE_PROFILES`) and its install
#   RPATH, and is registered in the project: finalized with it at the end of the ``CMakeLists.txt`` of
#   :command:`cs_initialize_project`. An ALIAS is created as with :command:`add_library` and not registered.
#
#   Install RPATH (Linux, macOS): an executable or a shared or module library finds, once installed, the shared
#   libraries installed in the ``lib/`` of its package, wherever the install folder is moved. Not set when
#   :variable:`CMAKE_INSTALL_RPATH` gives the target an :prop_tgt:`INSTALL_RPATH`, or when
#   :variable:`CSCMAKE_INSTALL_RPATH` is ``OFF``; an :prop_tgt:`INSTALL_RPATH` the project sets on the target
#   afterwards replaces it.
#
#   ``<target>``
#     The name of the library.
#
#   ``<add_library arguments>``
#     The other arguments of :command:`add_library`: the type (``STATIC``, ``SHARED``, ``INTERFACE``, ``OBJECT``, ...),
#     the sources, or ``ALIAS <target>``.
#
#   :Reads: :variable:`CSCMAKE_DEFAULT_COMPILE_PROFILES`, :variable:`CSCMAKE_INSTALL_RPATH`
#   :Writes: :prop_tgt:`CSCMAKE_COMPILE_PROFILES`, :prop_tgt:`INSTALL_RPATH`
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
#   As :command:`cs_add_library`: output name postfixes, MSVC runtime library, compile profiles, install RPATH,
#   registered in the project.
#
#   ``<target>``
#     The name of the executable.
#
#   ``<add_executable arguments>``
#     The other arguments of :command:`add_executable`: the sources, or ``ALIAS <target>``.
#
#   :Reads: :variable:`CSCMAKE_DEFAULT_COMPILE_PROFILES`, :variable:`CSCMAKE_INSTALL_RPATH`
#   :Writes: :prop_tgt:`CSCMAKE_COMPILE_PROFILES`, :prop_tgt:`INSTALL_RPATH`
function(cs_add_executable target_name)
  add_executable("${target_name}" ${ARGN})
  _cs_add_target_to_project_targets(${target_name})
endfunction()

# Register target_name in the project (unless it is an ALIAS): output name postfix of each configuration, MSVC runtime
# library, namespace; the values of the folder variables of the target (compile profiles, install RPATH) are taken now,
# as CMake does with CMAKE_<X> -> <X>, so that the finalization at the end of the project reads target properties only.
# Fails if cs_initialize_project was not called.
#
# Reads:
#
# * variable CSCMAKE_<CONFIG>_POSTFIX
# * variable CSCMAKE_MSVC_RUNTIME_LIBRARY_GENERATOR_EXPRESSION
# * variable CSCMAKE_DEFAULT_COMPILE_PROFILES
#
# Writes:
#
# * target property <CONFIG>_POSTFIX, MSVC_RUNTIME_LIBRARY, CSCMAKE_COMPILE_PROFILES
# * target property CSCMAKE_NAMESPACE: the namespace of the project of the target
# * global property CSCMAKE_<namespace>_PROJECT_TARGETS: the targets of the project
function(_cs_add_target_to_project_targets target_name)
  # aliases are not targets of their own
  get_target_property(target_name_alias ${target_name} ALIASED_TARGET)
  if(target_name_alias)
    return()
  endif()
  if(NOT CSCMAKE_NAMESPACE)
    message(
      FATAL_ERROR
      "[cs_add_library / cs_add_executable] ${target_name}: call cs_initialize_project(NAMESPACE ...) before adding "
      "targets"
    )
  endif()

  # output name postfix of every configuration (d = Debug, rd = RelWithDebInfo, ...)
  cs_get_build_configurations(configs_list)
  foreach(config IN LISTS configs_list)
    string(TOUPPER "${config}" config)
    set_target_properties(${target_name} PROPERTIES ${config}_POSTFIX "${CSCMAKE_${config}_POSTFIX}")
  endforeach()

  # the MSVC runtime of every configuration
  set_target_properties(
    ${target_name}
    PROPERTIES MSVC_RUNTIME_LIBRARY "${CSCMAKE_MSVC_RUNTIME_LIBRARY_GENERATOR_EXPRESSION}"
  )

  # the csCMake project of the target (its namespace): used for the links between projects of the same build
  set_property(TARGET ${target_name} PROPERTY CSCMAKE_NAMESPACE ${CSCMAKE_NAMESPACE})
  _cs_add_to_global_property_unique_value(CSCMAKE_${CSCMAKE_NAMESPACE}_PROJECT_TARGETS ${target_name})

  # the default compile profiles of the folder first, then the ones of cs_target_use_compile_profiles
  set_property(TARGET ${target_name} PROPERTY CSCMAKE_COMPILE_PROFILES ${CSCMAKE_DEFAULT_COMPILE_PROFILES})
  _cs_set_install_rpath(${target_name})
endfunction()

# Finalize target_name with its project (_cs_finalize_project): apply its compile profiles; links added afterwards
# with cs_target_link_libraries fail.
#
# Writes:
#
# * target property _CSCMAKE_FINALIZED
function(_cs_finalize_target target_name)
  _cs_apply_compile_profiles(${target_name})
  set_property(TARGET ${target_name} PROPERTY _CSCMAKE_FINALIZED TRUE)
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
#   ``<out-var>``
#     The variable to set, in the scope of the caller.
#
#   :Reads: :prop_gbl:`CSCMAKE_<namespace>_PROJECT_TARGETS`
function(cs_get_project_targets output_variable_name)
  # empty when the property is not set
  get_property(list_values GLOBAL PROPERTY CSCMAKE_${CSCMAKE_NAMESPACE}_PROJECT_TARGETS)
  set(${output_variable_name} "${list_values}" PARENT_SCOPE)
endfunction()

#.rst:
# Target properties
# ^^^^^^^^^^^^^^^^^
#
# .. prop_tgt:: CSCMAKE_NAMESPACE
#
#   The namespace of the project of the target.
#
# .. prop_tgt:: _CSCMAKE_FINALIZED
#
#   Internal: set when the project of the target is finalized (end of the ``CMakeLists.txt`` of
#   :command:`cs_initialize_project`).
#
# Global properties
# ^^^^^^^^^^^^^^^^^
#
# .. prop_gbl:: CSCMAKE_<namespace>_PROJECT_TARGETS
#
#   The targets of the project: :command:`cs_add_library`, :command:`cs_add_executable`, the default target.
