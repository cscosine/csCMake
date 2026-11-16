#.rst:
# csCMakeSetup
# ------------
#
# The part of csCMake that a project uses before its first :command:`project`: what CMake fixes when it sets up the
# compilers. A project includes it before :command:`project` (:doc:`csCMake` comes after):
#
# .. code-block:: cmake
#
#   cmake_minimum_required(VERSION 3.31)
#   include(csCMakeSetup)
#   cs_macos_deployment_target(14.4)
#   project(myApp VERSION 1.0.0 LANGUAGES CXX)
#   include(csCMake)
#   cs_initialize_project(NAMESPACE myApp CXX_STANDARD 20 DEFAULT_CONFIG Debug Release)
#
# Commands
# ^^^^^^^^

include_guard(GLOBAL)

if(CMAKE_VERSION VERSION_LESS 3.31)
  message(FATAL_ERROR "csCMake requires CMake 3.31 or newer (found ${CMAKE_VERSION})")
endif()
cmake_policy(PUSH)
cmake_policy(VERSION 3.31)

#.rst:
# .. command:: cs_macos_deployment_target
#
#   The oldest macOS the binaries of the project run on: ``CMAKE_OSX_DEPLOYMENT_TARGET``, set for the project without
#   naming the variable.
#
#   .. code-block:: cmake
#
#     cs_macos_deployment_target(<version>)
#
#   Before the first :command:`project` of the top-level ``CMakeLists.txt``: CMake uses the value when it sets up the
#   compilers, in :command:`project`, so a call after it fails the configure. ``<version>`` is the minimum of the
#   project, at least the value of the packages it uses (e.g. ``14.4`` with Qt 6.12): the packages found are checked
#   against it (:doc:`csMacosDeploymentTarget`), and :command:`cs_initialize_project` records it in the installed
#   package.
#
#   The build may raise it, never lower it: a value given to the build (``-DCMAKE_OSX_DEPLOYMENT_TARGET``, a preset,
#   the ``MACOSX_DEPLOYMENT_TARGET`` environment variable) of ``<version>`` or newer is used; an older one fails the
#   configure. Nothing on a host that is not macOS.
#
#   In a project added with :command:`add_subdirectory` to another one, the build has the value of the top-level
#   project already: the call checks it is ``<version>`` or newer (else it fails, with the value to raise to).
#
#   :Writes: cache :variable:`CMAKE_OSX_DEPLOYMENT_TARGET`, cache ``_CSCMAKE_MACOS_DEPLOYMENT_TARGET_DECLARED``
function(cs_macos_deployment_target version)
  if(NOT version MATCHES "^[0-9]+(\\.[0-9]+)*$")
    message(FATAL_ERROR "[cs_macos_deployment_target] ${version}: a macOS version is expected, e.g. 14.4")
  endif()
  # PROJECT_NAME: set by project() in this scope or a parent one (not cached, as CMAKE_PROJECT_NAME is: a re-configure
  # has it before project())
  if(DEFINED PROJECT_NAME)
    if(CMAKE_CURRENT_SOURCE_DIR STREQUAL CMAKE_SOURCE_DIR)
      message(
        FATAL_ERROR
        "[cs_macos_deployment_target] call it before project(): CMake uses the deployment target when project() sets "
        "up the compilers (include(csCMakeSetup), cs_macos_deployment_target(${version}), then project(...))"
      )
    endif()
    # a nested project: the value of the build is the one of the top-level project
    if(CMAKE_OSX_DEPLOYMENT_TARGET AND CMAKE_OSX_DEPLOYMENT_TARGET VERSION_LESS version)
      message(
        FATAL_ERROR
        "[cs_macos_deployment_target] the project in ${CMAKE_CURRENT_SOURCE_DIR} needs macOS ${version} or newer, the "
        "build is for macOS ${CMAKE_OSX_DEPLOYMENT_TARGET}: raise cs_macos_deployment_target of the top-level project "
        "to ${version} or more"
      )
    endif()
    return()
  endif()
  if(NOT CMAKE_HOST_APPLE)
    return()
  endif()

  # the value given to the build: the cache (-D, a preset; not the value of an earlier call, which the call replaces),
  # else the environment
  set(given "")
  if(CMAKE_OSX_DEPLOYMENT_TARGET AND NOT CMAKE_OSX_DEPLOYMENT_TARGET STREQUAL _CSCMAKE_MACOS_DEPLOYMENT_TARGET_DECLARED)
    set(given "${CMAKE_OSX_DEPLOYMENT_TARGET}")
  elseif(NOT "$ENV{MACOSX_DEPLOYMENT_TARGET}" STREQUAL "")
    set(given "$ENV{MACOSX_DEPLOYMENT_TARGET}")
  endif()
  if(given AND given VERSION_LESS version)
    message(
      FATAL_ERROR
      "[cs_macos_deployment_target] the project needs macOS ${version} or newer, the build is given macOS ${given} "
      "(-DCMAKE_OSX_DEPLOYMENT_TARGET, a preset or MACOSX_DEPLOYMENT_TARGET): remove it or raise it to ${version} or "
      "more"
    )
  endif()
  if(given)
    set(value "${given}")
  else()
    set(value "${version}")
  endif()
  set(CMAKE_OSX_DEPLOYMENT_TARGET "${value}" CACHE STRING "Oldest macOS the binaries run on" FORCE)
  set(_CSCMAKE_MACOS_DEPLOYMENT_TARGET_DECLARED "${value}" CACHE INTERNAL "")
endfunction()

#.rst:
# Variables
# ^^^^^^^^^
#
# .. variable:: _CSCMAKE_MACOS_DEPLOYMENT_TARGET_DECLARED
#
#   Internal (cache): the value :command:`cs_macos_deployment_target` set at the last configure, so that a changed call
#   replaces it (it is not a value given to the build).

cmake_policy(POP)
