#.rst:
# csCMake
# -------
#
# The entry point of csCMake: a project includes it after :command:`project`, then calls
# :command:`cs_initialize_project`; csCMake finalizes the project at the end of the same ``CMakeLists.txt``.
#
# .. code-block:: cmake
#
#   cmake_minimum_required(VERSION 3.31)
#   project(myApp VERSION 1.0.0 LANGUAGES CXX)
#   include(csCMake)
#   cs_initialize_project(NAMESPACE myApp CXX_STANDARD 20 DEFAULT_CONFIG Debug Release)
#   cs_add_library(core STATIC core.cpp)
#   cs_install_target(core COMPONENT core DEFAULT)
#
# csCMake needs CMake 3.31; its functions and macros run with the 3.31 policies.
#
# The modules: :doc:`csProject`, :doc:`csBuildConfigurations`, :doc:`csTargets`,
# :doc:`csTargetSources`, :doc:`csTargetLinkLibraries`, :doc:`csFindPackage`, :doc:`csBaseInclude`,
# :doc:`csTargetDependencies`, :doc:`csInstall`, :doc:`csPackageConfig`, :doc:`csDeployment`,
# :doc:`csCheckInstalledHeaders`, :doc:`csCompileProfiles`, :doc:`csCompileProfilesShipped`,
# :doc:`csDebug`; integrations: :doc:`csOpenMP`.

include_guard(GLOBAL)

# csCMake needs CMake 3.31 (the csv1 presets use schema version 10); the including project declares its own
# cmake_minimum_required. csCMake's functions and macros run with the 3.31 policies: they record the policy settings in
# effect where they are defined (cmake_policy PUSH / VERSION / POP around the whole file).
if(CMAKE_VERSION VERSION_LESS 3.31)
  message(FATAL_ERROR "csCMake requires CMake 3.31 or newer (found ${CMAKE_VERSION})")
endif()
cmake_policy(PUSH)
cmake_policy(VERSION 3.31)

include(modules/csInternal)
include(modules/csDebug)
include(modules/csProject)
include(modules/csBuildConfigurations)
include(modules/csBaseInclude)
include(modules/csTargets)
include(modules/csFindPackage)
include(modules/csTargetSources)
include(modules/csTargetLinkLibraries)
include(modules/csTargetDependencies)
include(modules/csInstall)
include(modules/csPackageConfig)
include(modules/csDeployment)
include(modules/csCheckInstalledHeaders)
include(modules/csCompileProfiles)
include(modules/csCompileProfilesShipped)
include(modules/integrations/csOpenMP)

# Store the csCMake folder; fail if csCMake is included from two different folders.
#
# Writes:
#
# * global property CSCMAKE_ROOT_DIR: the csCMake folder
function(_cs_set_root_dir path)
  get_property(val GLOBAL PROPERTY CSCMAKE_ROOT_DIR)
  if(val)
    if(NOT val STREQUAL "${path}")
      message(
        FATAL_ERROR
        "[csCMake] csCMake is included from two folders, ${val} and ${path}: one csCMake per build (check "
        "CMAKE_MODULE_PATH and the presets of the projects)"
      )
    endif()
  endif()
  set_property(GLOBAL PROPERTY CSCMAKE_ROOT_DIR ${path})
endfunction()
_cs_set_root_dir(${CMAKE_CURRENT_LIST_DIR})

# Return in path the csCMake folder.
#
# Reads:
#
# * global property CSCMAKE_ROOT_DIR
function(_cs_get_root_dir path)
  get_property(val GLOBAL PROPERTY CSCMAKE_ROOT_DIR)
  set(${path} ${val} PARENT_SCOPE)
endfunction()

cmake_policy(POP)

#.rst:
# Global properties
# ^^^^^^^^^^^^^^^^^
#
# .. prop_gbl:: CSCMAKE_ROOT_DIR
#
#   The csCMake folder (one per build: including csCMake from two folders fails).
