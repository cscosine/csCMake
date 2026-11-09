# chained-projects smoke test: package depending on csSmokeBase
#
# "Sol" layout:
#
# * a "<package>Sol" top project
# * the package in a subproject named like the package
# * the namespace (= package name = folder name, needed by find_package) differs from the top project name
#
# See tests/smoke/README.md.
cmake_minimum_required(VERSION 3.31)
project(
  csSmokeMidASol
  VERSION 1.0.0
  LANGUAGES CXX)

include(csCMake)

cs_initialize_project(
  NAMESPACE csSmokeMidA
  CXX_STANDARD 17
  DEFAULT_CONFIG Debug Release
  DEFAULT_CONFIG_MAPPED RelWithDebInfo
  MAPPED_TO "RelWithDebInfo,Release,"
  CUSTOM_CONFIG Paranoid
  BASED_ON "Debug,Release,"
  POSTFIX "dp")

add_subdirectory(csSmokeMidA)

cs_finalize_project()
