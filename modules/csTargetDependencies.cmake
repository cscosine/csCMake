#.rst:
# csTargetDependencies
# --------------------
#
# Dependencies of the targets, resolved when the project is finalized: the targets of the project each target
# depends on (for the dependencies between the components), and the run-time environment of the targets (the Visual
# Studio debugger environment: the folders of the DLLs a target needs, and what the project adds with
# :command:`cs_target_runtime_environment`).
#
# Commands
# ^^^^^^^^

include_guard(GLOBAL)
include(modules/csDebug)
include(modules/csInternal)

#.rst:
# .. command:: cs_target_runtime_environment
#
#   Add to the run-time environment of a target what CMake cannot know. Usually not needed:
#   the finalization of the project already gives each executable and shared library the folders of the DLLs of
#   everything it links (imported or not, per configuration), and on Linux and macOS the build tree runs through the
#   RPATH.
#
#   .. code-block:: cmake
#
#     cs_target_runtime_environment(<target>
#       [PATH <folder>...]
#       [SET <name>=<value>...]
#       [DEBUGGER_PATH BEFORE|AFTER|OFF])
#
#   Use it for:
#
#   * libraries loaded at run time (``dlopen`` / ``LoadLibrary``, plugins of the project), DLLs linked by file name
#     instead of a target, tools the program starts: their folders with ``PATH``;
#   * variables the program reads, e.g. the plugin folders of Qt: ``SET QT_PLUGIN_PATH=${QT_ROOT}/plugins``.
#
#   The environment goes to the Visual Studio debugger (:prop_tgt:`VS_DEBUGGER_ENVIRONMENT`): the ``PATH`` folders
#   first, then the folders of the DLLs, then ``%PATH%``; the variables on their own lines. Call it in the project of
#   the target (before its finalization, at the end of the ``CMakeLists.txt`` of :command:`cs_initialize_project`), as
#   many times as needed (each call adds to the previous ones). Generator
#   expressions are allowed, e.g. a folder per configuration:
#
#   .. code-block:: cmake
#
#     cs_target_runtime_environment(app
#       PATH "${MYSDK_ROOT}/bin" "$<$<CONFIG:Debug>:${PLUGINS_DIR}/debug>"
#       SET "QT_PLUGIN_PATH=${QT_ROOT}/plugins" "QML_IMPORT_PATH=${QT_ROOT}/qml")
#
#   A target whose :prop_tgt:`VS_DEBUGGER_ENVIRONMENT` the project writes itself keeps it: its lines come first, and a
#   ``PATH`` line of its own gets the folders merged in, by ``DEBUGGER_PATH``.
#
#   ``<target>``
#     A target of the project (an alias of one is accepted).
#
#   ``PATH``
#     Folders to put first in ``PATH``.
#
#   ``SET``
#     Variables, ``<name>=<value>`` each (``PATH`` itself: use the ``PATH`` keyword). A value may contain ``;``.
#
#   ``DEBUGGER_PATH``
#     Only for a target whose :prop_tgt:`VS_DEBUGGER_ENVIRONMENT` the project writes with a ``PATH`` line of its own:
#     ``BEFORE`` (default) puts the folders (``PATH``, then the DLL folders) before the project's ones, at the start of
#     that line; ``AFTER`` after them, before its ``%PATH%`` (or at its end). ``OFF``: csCMake does not change the
#     debugger environment of the target (nor adds the variables).
#
#   :Writes: :prop_tgt:`CSCMAKE_RUNTIME_DIRS`, :prop_tgt:`CSCMAKE_RUNTIME_ENVIRONMENT`,
#     :prop_tgt:`CSCMAKE_DEBUGGER_PATH`
function(cs_target_runtime_environment target_name)
  cmake_parse_arguments(PARSE_ARGV 1 arg "" "DEBUGGER_PATH" "PATH;SET")
  if(arg_UNPARSED_ARGUMENTS)
    message(
      FATAL_ERROR
      "[cs_target_runtime_environment] ${target_name}: unparsed arguments ${arg_UNPARSED_ARGUMENTS} (PATH <folder>... "
      "SET <name>=<value>... DEBUGGER_PATH BEFORE|AFTER|OFF)"
    )
  endif()
  if(NOT TARGET "${target_name}")
    message(FATAL_ERROR "[cs_target_runtime_environment] ${target_name} is not a target")
  endif()
  get_target_property(aliased ${target_name} ALIASED_TARGET)
  if(aliased)
    set(target_name ${aliased})
  endif()
  get_property(finalized GLOBAL PROPERTY _CSCMAKE_PROJECT_FINALIZED_${CSCMAKE_NAMESPACE})
  if(finalized)
    message(
      FATAL_ERROR
      "[cs_target_runtime_environment] ${target_name}: its project is already finalized (end of the CMakeLists.txt "
      "of its cs_initialize_project)"
    )
  endif()

  if(DEFINED arg_DEBUGGER_PATH)
    if(NOT arg_DEBUGGER_PATH MATCHES "^(BEFORE|AFTER|OFF)$")
      message(
        FATAL_ERROR
        "[cs_target_runtime_environment] ${target_name}: DEBUGGER_PATH is BEFORE, AFTER or OFF, got "
        "${arg_DEBUGGER_PATH}"
      )
    endif()
    set_property(TARGET ${target_name} PROPERTY CSCMAKE_DEBUGGER_PATH ${arg_DEBUGGER_PATH})
  endif()

  set_property(TARGET ${target_name} APPEND PROPERTY CSCMAKE_RUNTIME_DIRS ${arg_PATH})
  foreach(variable IN LISTS arg_SET)
    if(NOT variable MATCHES "^[A-Za-z_][A-Za-z0-9_]*=")
      message(FATAL_ERROR "[cs_target_runtime_environment] ${target_name}: SET takes <name>=<value>, got ${variable}")
    endif()
    if(variable MATCHES "^PATH=")
      message(FATAL_ERROR "[cs_target_runtime_environment] ${target_name}: PATH is given with the PATH keyword")
    endif()
    # one list element per variable: a ";" of the value is written by the generator expression
    string(REPLACE ";" "$<SEMICOLON>" variable "${variable}")
    set_property(TARGET ${target_name} APPEND PROPERTY CSCMAKE_RUNTIME_ENVIRONMENT "${variable}")
  endforeach()
endfunction()

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
  if(dependencies)
    list(JOIN dependencies ", " text)
    message(VERBOSE "${target_name} depends on ${text}")
  endif()
  set_property(TARGET ${target_name} PROPERTY CSCMAKE_PROJECT_DEPENDENCIES "${dependencies}")
endfunction()

# Set the Visual Studio debugger environment of an executable or shared / module library: the lines of the project (its
# own VS_DEBUGGER_ENVIRONMENT), the variables of CSCMAKE_RUNTIME_ENVIRONMENT, and the folders: the ones of
# CSCMAKE_RUNTIME_DIRS (given by the project), then the folders of the DLLs it needs ($<TARGET_RUNTIME_DLL_DIRS>, per
# configuration, with the configuration CMake selects for each imported target); none on platforms without DLLs unless
# CSCMAKE_RUNTIME_DIRS is set. Where they go, by the target property CSCMAKE_DEBUGGER_PATH (BEFORE when not set):
#
# * a VS_DEBUGGER_ENVIRONMENT of the project without a PATH line, or none: a line PATH=<folders>;%PATH% after its lines
#   (%PATH%: the environment, expanded by Visual Studio), whatever the mode except OFF;
# * a PATH line of the project: BEFORE puts the folders at its start, AFTER before its %PATH% (or at its end);
# * OFF: VS_DEBUGGER_ENVIRONMENT is not changed (the variables are not added either).
#
# Reads:
#
# * target property CSCMAKE_RUNTIME_DIRS, CSCMAKE_RUNTIME_ENVIRONMENT, CSCMAKE_DEBUGGER_PATH, VS_DEBUGGER_ENVIRONMENT
#
# Writes:
#
# * target property VS_DEBUGGER_ENVIRONMENT
function(_cs_set_vs_debugger_environment target_name)
  get_target_property(target_type ${target_name} TYPE)
  if(NOT target_type MATCHES "^(EXECUTABLE|SHARED_LIBRARY|MODULE_LIBRARY)$")
    return()
  endif()
  _cs_debugger_path_mode(${target_name} mode)
  if(mode STREQUAL "OFF")
    return()
  endif()

  get_property(runtime_dirs TARGET ${target_name} PROPERTY CSCMAKE_RUNTIME_DIRS)
  set(dirs "$<TARGET_RUNTIME_DLL_DIRS:${target_name}>")
  if(runtime_dirs)
    list(JOIN runtime_dirs ";" runtime_dirs)
    set(dirs "${runtime_dirs};${dirs}")
  endif()

  get_property(environment TARGET ${target_name} PROPERTY VS_DEBUGGER_ENVIRONMENT)
  # the variables of cs_target_runtime_environment, one line each after the lines of the project
  get_property(variables TARGET ${target_name} PROPERTY CSCMAKE_RUNTIME_ENVIRONMENT)
  foreach(variable IN LISTS variables)
    if(NOT "${environment}" STREQUAL "")
      string(APPEND environment "\n")
    endif()
    string(APPEND environment "${variable}")
  endforeach()

  _cs_add_debugger_path("${environment}" ${mode} "${dirs}" environment)
  set_property(TARGET ${target_name} PROPERTY VS_DEBUGGER_ENVIRONMENT "${environment}")
  message(DEBUG "${target_name}: Visual Studio debugger environment ${environment}")
endfunction()

# Set mode_out to the CSCMAKE_DEBUGGER_PATH of target_name (BEFORE when not set); fail on another value than BEFORE,
# AFTER, OFF (the property can be set without cs_target_runtime_environment).
#
# Reads:
#
# * target property CSCMAKE_DEBUGGER_PATH
function(_cs_debugger_path_mode target_name mode_out)
  # not if(NOT mode): OFF is a value, and false for if()
  get_property(mode TARGET ${target_name} PROPERTY CSCMAKE_DEBUGGER_PATH)
  if("${mode}" STREQUAL "")
    set(mode BEFORE)
  endif()
  if(NOT mode MATCHES "^(BEFORE|AFTER|OFF)$")
    message(FATAL_ERROR "[csCMake] ${target_name}: CSCMAKE_DEBUGGER_PATH is BEFORE, AFTER or OFF, got ${mode}")
  endif()
  set(${mode_out} ${mode} PARENT_SCOPE)
endfunction()

# Set environment_out to environment (debugger environment lines) with the folders dirs on PATH: merged into its PATH
# line (mode BEFORE: at the start of the line, AFTER: before its %PATH%, or at its end), else a line
# PATH=<dirs>;%PATH% after its lines. Nothing added when dirs evaluates to nothing.
function(_cs_add_debugger_path environment mode dirs environment_out)
  set(has_dirs "$<BOOL:${dirs}>")
  if(environment MATCHES "(^|\n)PATH=")
    if(mode STREQUAL "BEFORE")
      string(REGEX REPLACE "(^|\n)PATH=" "\\1PATH=$<${has_dirs}:${dirs};>" environment "${environment}")
    elseif(environment MATCHES "(^|\n)PATH=[^\n]*%PATH%")
      string(
        REGEX REPLACE "(^|\n)(PATH=[^\n]*)%PATH%"
        "\\1\\2$<${has_dirs}:${dirs};>%PATH%"
        environment
        "${environment}"
      )
    else()
      string(REGEX REPLACE "(^|\n)(PATH=[^\n]*)" "\\1\\2$<${has_dirs}:;${dirs}>" environment "${environment}")
    endif()
  else()
    # a line of its own, after the other lines (one variable per line, as Visual Studio shows them)
    set(path_line "$<${has_dirs}:PATH=${dirs};%PATH%>")
    if(NOT "${environment}" STREQUAL "")
      set(path_line "$<${has_dirs}:\n>${path_line}")
    endif()
    string(APPEND environment "${path_line}")
  endif()
  set(${environment_out} "${environment}" PARENT_SCOPE)
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

# Return the targets of the project (or of nested csCMake projects) a target depends on, resolved when the project is
# finalized.
#
# Reads:
#
# * target property CSCMAKE_PROJECT_DEPENDENCIES
function(_cs_get_target_project_dependencies target_name output_variable_name)
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
#
# .. prop_tgt:: CSCMAKE_DEBUGGER_PATH
#
#   ``BEFORE``, ``AFTER`` or ``OFF``: the ``DEBUGGER_PATH`` of :command:`cs_target_runtime_environment` (``BEFORE`` when
#   not set).
#
# .. prop_tgt:: CSCMAKE_RUNTIME_DIRS
#
#   Folders the target needs first in ``PATH`` at run time (generator expressions allowed): the ``PATH`` of
#   :command:`cs_target_runtime_environment`.
#
# .. prop_tgt:: CSCMAKE_RUNTIME_ENVIRONMENT
#
#   Variables of the run-time environment of the target, ``<name>=<value>`` each: the ``SET`` of
#   :command:`cs_target_runtime_environment`.
