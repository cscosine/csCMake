# shared libraries smoke test: two shared libraries (one using the other) and an application, installed; the installed
# application must run from the install folder (install RPATH of cs_finalize_target on Linux and macOS, DLLs next to it
# on Windows).
#
# See tests/smoke/README.md.
cmake_minimum_required(VERSION 3.31)
project(csSmokeShared VERSION 1.0.0 LANGUAGES CXX)

include(csCMake)

cs_initialize_project(
  NAMESPACE csSmokeShared
  CXX_STANDARD 17
  DEFAULT_CONFIG Debug Release
  DEFAULT_CONFIG_MAPPED RelWithDebInfo
  MAPPED_TO "RelWithDebInfo,Release,"
  CUSTOM_CONFIG Paranoid
  BASED_ON "Debug,Release,"
  POSTFIX "dp"
)

add_subdirectory(csSmokeShared)

cs_finalize_project()
