#.rst:
# csMacosDeploymentTarget
# -----------------------
#
# The oldest macOS the binaries run on, ``CMAKE_OSX_DEPLOYMENT_TARGET``: csCMake sets no value, each project declares
# its own before its first :command:`project` (a csCMake project: :command:`cs_macos_deployment_target` of
# :doc:`csCMakeSetup`; a project without csCMake: its preset, see the user guide). csCMake records it in the installed
# package (``<prefix>/share/cscmake/<namespace>.macos-deployment-target``, named as the package, by
# :command:`cs_initialize_project`) and checks
# the packages found (:command:`cs_after_find_dependency`): a package built for a newer macOS than the project fails the
# configure (its binaries would not start on the older macOS). An older one is fine.
#
# Commands
# ^^^^^^^^
include_guard(GLOBAL)
include(modules/csDebug)

#.rst:
# .. command:: cs_require_macos_deployment_target
#
#   Fail unless the project builds for ``<version>`` of macOS or newer.
#
#   .. code-block:: cmake
#
#     cs_require_macos_deployment_target(<version> [REASON <text>])
#
#   Nothing when ``<version>`` is empty or the project sets no ``CMAKE_OSX_DEPLOYMENT_TARGET`` (then the binaries are
#   built for the macOS of the machine). ``REASON``: what needs ``<version>``, in the message.
function(cs_require_macos_deployment_target version)
  cmake_parse_arguments(PARSE_ARGV 1 arg "" "REASON" "")
  if("${version}" STREQUAL "" OR NOT CMAKE_OSX_DEPLOYMENT_TARGET)
    return()
  endif()
  if(CMAKE_OSX_DEPLOYMENT_TARGET VERSION_LESS version)
    set(reason "${arg_REASON}")
    if(NOT reason)
      set(reason "the project")
    endif()
    message(
      FATAL_ERROR
      "[csCMake] ${reason} needs macOS ${version} or newer, the project builds for macOS "
      "${CMAKE_OSX_DEPLOYMENT_TARGET} (CMAKE_OSX_DEPLOYMENT_TARGET). Raise it to ${version} or more in "
      "cscmake-project-setup-macos (CMakePresets.json of the project)."
    )
  endif()
endfunction()

# Record the macOS deployment target of the csCMake project namespace in its installed package
# (cs_initialize_project): <prefix>/share/cscmake/<namespace>.macos-deployment-target, one line with the version, named
# as the package the consumers find; also for a project added with add_subdirectory. Nothing when the project sets no
# deployment target (on macOS: a warning, once per build).
#
# Writes:
#
# * global property _CSCMAKE_MACOS_DEPLOYMENT_TARGET_RECORDED_<namespace>, _CSCMAKE_MACOS_DEPLOYMENT_TARGET_WARNED
function(_cs_record_macos_deployment_target namespace)
  get_property(done GLOBAL PROPERTY _CSCMAKE_MACOS_DEPLOYMENT_TARGET_RECORDED_${namespace})
  if(done)
    return()
  endif()
  set_property(GLOBAL PROPERTY _CSCMAKE_MACOS_DEPLOYMENT_TARGET_RECORDED_${namespace} TRUE)
  if(CMAKE_OSX_DEPLOYMENT_TARGET)
    set(file "${CMAKE_BINARY_DIR}/cscmake/${namespace}.macos-deployment-target")
    file(WRITE "${file}" "${CMAKE_OSX_DEPLOYMENT_TARGET}\n")
    install(FILES "${file}" DESTINATION share/cscmake)
    return()
  endif()
  get_property(warned GLOBAL PROPERTY _CSCMAKE_MACOS_DEPLOYMENT_TARGET_WARNED)
  if(APPLE AND NOT warned)
    set_property(GLOBAL PROPERTY _CSCMAKE_MACOS_DEPLOYMENT_TARGET_WARNED TRUE)
    message(
      WARNING
      "${namespace}: no macOS deployment target, the binaries are built for the macOS of this machine and do not run "
      "on an older one: cs_macos_deployment_target(<version>) before project() (include(csCMakeSetup))"
    )
  endif()
endfunction()

# Check the macOS deployment target recorded by the package found (cs_after_find_dependency): not newer than the one of
# the project. Nothing (VERBOSE message) when the package has no record.
function(_cs_check_recorded_macos_deployment_target package)
  _cs_get_recorded_macos_deployment_target(${package} recorded)
  if(recorded)
    cs_require_macos_deployment_target("${recorded}" REASON "${package} (built for macOS ${recorded})")
  else()
    message(VERBOSE "${package}: no recorded macOS deployment target, not checked")
  endif()
endfunction()

# Return in out_var the macOS deployment target recorded by the package found (csRecordMacosDeploymentTarget), or "":
# share/cscmake/<package>.macos-deployment-target (name compared case-insensitively: the project name of a third-party
# library may differ in case from its package name) in <package>_DIR or one of its parent folders, up to 4 levels (the
# install prefix of lib/cmake/<package>).
#
# Reads:
#
# * variable <package>_DIR (set by find_package)
function(_cs_get_recorded_macos_deployment_target package out_var)
  set(${out_var} "" PARENT_SCOPE)
  set(dir "${${package}_DIR}")
  if(NOT dir OR NOT IS_DIRECTORY "${dir}")
    return()
  endif()
  string(TOLOWER "${package}.macos-deployment-target" wanted)
  foreach(level RANGE 4)
    file(GLOB files "${dir}/share/cscmake/*.macos-deployment-target")
    foreach(file IN LISTS files)
      get_filename_component(name "${file}" NAME)
      string(TOLOWER "${name}" name)
      if(name STREQUAL wanted)
        file(STRINGS "${file}" value LIMIT_COUNT 1)
        string(STRIP "${value}" value)
        set(${out_var} "${value}" PARENT_SCOPE)
        return()
      endif()
    endforeach()
    get_filename_component(parent "${dir}" DIRECTORY)
    if(parent STREQUAL dir)
      break()
    endif()
    set(dir "${parent}")
  endforeach()
endfunction()

#.rst:
# Global properties
# ^^^^^^^^^^^^^^^^^
#
# .. prop_gbl:: _CSCMAKE_MACOS_DEPLOYMENT_TARGET_RECORDED
#
#   Internal: ``TRUE`` once the deployment target of the top-level project without csCMake is recorded (the
#   ``modules/scripts/csRecordMacosDeploymentTarget.cmake`` script, included after :command:`project` through
#   ``CMAKE_PROJECT_INCLUDE``).
#
# .. prop_gbl:: _CSCMAKE_MACOS_DEPLOYMENT_TARGET_RECORDED_<namespace>
#
#   Internal: ``TRUE`` once the deployment target of the csCMake project ``<namespace>`` is recorded
#   (:command:`cs_initialize_project`).
#
# .. prop_gbl:: _CSCMAKE_MACOS_DEPLOYMENT_TARGET_WARNED
#
#   Internal: ``TRUE`` once the warning for a project without deployment target is shown.
