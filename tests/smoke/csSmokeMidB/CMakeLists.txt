# chained-projects smoke test: package depending on csSmokeBase
#
# Flat layout, the simplest way to use csCMake:
#
# * a single project() named like the package (= namespace = folder name, needed by find_package)
# * no subproject: the library folder has no project() call
#
# See tests/smoke/README.md.
cmake_minimum_required(VERSION 3.31)
project(csSmokeMidB VERSION 1.0.0 LANGUAGES CXX)

include(csCMake)

cs_initialize_project(
  NAMESPACE csSmokeMidB
  CXX_STANDARD 17
  DEFAULT_CONFIG Debug Release
  DEFAULT_CONFIG_MAPPED RelWithDebInfo
  MAPPED_TO "RelWithDebInfo,Release,"
  CUSTOM_CONFIG Paranoid
  BASED_ON "Debug,Release,"
  POSTFIX "dp"
)

add_subdirectory(csSmokeMidB)

cs_finalize_project()
