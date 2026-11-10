# smoke test: standalone layout, the workspace inside the project
#
# * <project>/workspace/csCMake, build and install folders in <project>/workspace
# * presets/layout/standalone-short.json (see tests/smoke/README.md)
cmake_minimum_required(VERSION 3.31)
project(
  csSmokeStandalone
  VERSION 1.0.0
  LANGUAGES CXX)

include(csCMake)

cs_initialize_project(
  NAMESPACE csSmokeStandalone
  CXX_STANDARD 17
  DEFAULT_CONFIG Debug Release
  DEFAULT_CONFIG_MAPPED RelWithDebInfo
  MAPPED_TO "RelWithDebInfo,Release,"
  CUSTOM_CONFIG Paranoid
  BASED_ON "Debug,Release,"
  POSTFIX "dp")

add_subdirectory(csSmokeStandalone)

cs_finalize_project()
