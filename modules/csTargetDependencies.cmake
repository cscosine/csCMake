#.rst:
# csTargetDependencies
# --------------------
#
# Dependencies of the targets, resolved by :command:`cs_finalize_project`: the targets of the project each target
# depends on (for the dependencies between the components), and the Visual Studio debugger environment (the folders of
# the DLLs a target needs).
#
# Commands
# ^^^^^^^^

include_guard(GLOBAL)
include(modules/csDebug)
include(modules/csInternal)

# Set out to the target of the build (not imported) that the link item names, alias resolved; empty for anything else
# (an imported target, a library file or name, a generator expression other than $<LINK_ONLY:...>, which CMake writes
# for the private links of static libraries).
function(_cs_link_item_project_target item out)
  set(${out} "" PARENT_SCOPE)
  if(item MATCHES "^\\$<LINK_ONLY:([^$<>]+)>$")
    set(item "${CMAKE_MATCH_1}")
  endif()
  if(NOT TARGET "${item}")
    return()
  endif()
  get_target_property(aliased "${item}" ALIASED_TARGET)
  if(aliased)
    set(item "${aliased}")
  endif()
  get_target_property(imported "${item}" IMPORTED)
  if(NOT imported)
    set(${out} "${item}" PARENT_SCOPE)
  endif()
endfunction()

# Set CSCMAKE_PROJECT_DEPENDENCIES of target_name: the targets of the build (not imported) it links to, directly or
# through other such targets (their LINK_LIBRARIES and INTERFACE_LINK_LIBRARIES), in the order they are found.
#
# Writes:
#
# * target property CSCMAKE_PROJECT_DEPENDENCIES
function(_cs_set_project_dependencies target_name)
  set(dependencies "")
  set(to_visit ${target_name})
  while(to_visit)
    list(POP_FRONT to_visit current)
    get_property(link_libraries TARGET ${current} PROPERTY LINK_LIBRARIES)
    get_property(interface_link_libraries TARGET ${current} PROPERTY INTERFACE_LINK_LIBRARIES)
    foreach(item IN LISTS link_libraries interface_link_libraries)
      _cs_link_item_project_target("${item}" dependency)
      if(dependency AND NOT dependency STREQUAL target_name AND NOT dependency IN_LIST dependencies)
        list(APPEND dependencies ${dependency})
        list(APPEND to_visit ${dependency})
      endif()
    endforeach()
  endwhile()
  cs_debug_message("[cs_finalize_project] ${target_name} depends on the targets: ${dependencies}")
  set_property(TARGET ${target_name} PROPERTY CSCMAKE_PROJECT_DEPENDENCIES "${dependencies}")
endfunction()

# Set the Visual Studio debugger environment of an executable or shared / module library: PATH starts with the folders
# of the DLLs it needs ($<TARGET_RUNTIME_DLL_DIRS>, per configuration, with the configuration CMake selects for each
# imported target), then the PATH of the environment (%PATH%, expanded by Visual Studio). Empty when there are none
# (and always on platforms without DLLs).
#
# Writes:
#
# * target property VS_DEBUGGER_ENVIRONMENT
function(_cs_set_vs_debugger_environment target_name)
  get_target_property(target_type ${target_name} TYPE)
  if(NOT target_type MATCHES "^(EXECUTABLE|SHARED_LIBRARY|MODULE_LIBRARY)$")
    return()
  endif()
  set(dirs "$<TARGET_RUNTIME_DLL_DIRS:${target_name}>")
  set_property(TARGET ${target_name} PROPERTY VS_DEBUGGER_ENVIRONMENT "$<$<BOOL:${dirs}>:PATH=${dirs};%PATH%>")
endfunction()

# Resolve the dependencies of every target of the project, once all of them exist: the targets each one depends on and
# its Visual Studio debugger environment.
function(_cs_finalize_runtime_dependencies)
  cs_get_project_targets(targets)
  foreach(target_name IN LISTS targets)
    _cs_set_project_dependencies(${target_name})
    _cs_set_vs_debugger_environment(${target_name})
  endforeach()
endfunction()

#.rst:
# .. command:: cs_get_target_project_dependencies
#
#   Return the targets of the project (or of nested csCMake projects) a target depends on, resolved by
#   :command:`cs_finalize_project`.
#
#   .. code-block:: cmake
#
#     cs_get_target_project_dependencies(<target> <out-var>)
#
#   ``<target>``
#     A target of the project.
#
#   ``<out-var>``
#     The variable to set, in the scope of the caller.
#
#   :Reads: :prop_tgt:`CSCMAKE_PROJECT_DEPENDENCIES`
function(cs_get_target_project_dependencies target_name output_variable_name)
  # empty when the property is not set
  get_property(values TARGET ${target_name} PROPERTY CSCMAKE_PROJECT_DEPENDENCIES)
  set(${output_variable_name} "${values}" PARENT_SCOPE)
endfunction()

#.rst:
# Target properties
# ^^^^^^^^^^^^^^^^^
#
# .. prop_tgt:: CSCMAKE_PROJECT_DEPENDENCIES
#
#   The targets of the project (or of nested csCMake projects) the target depends on.
