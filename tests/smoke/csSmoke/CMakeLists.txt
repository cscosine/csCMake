# smoke test project for csCMake: a static library, an executable linking it, tests, install and export
cmake_minimum_required(VERSION 3.31)
project(
  csSmoke
  VERSION 1.0.0
  LANGUAGES CXX)

include(csCMake)

# the four configurations the csv1 presets build: Debug, Release, RelWithDebInfo and the custom Paranoid
cs_initialize_project(
  csSmoke
  CXX_STANDARD
  17
  DEFAULT_CONFIG
  Debug
  DEFAULT_CONFIG
  Release
  DEFAULT_CONFIG_MAPPED
  RelWithDebInfo
  MAPPED_TO
  "RelWithDebInfo,Release,"
  CUSTOM_CONFIG
  Paranoid
  BASED_ON
  "Debug,Release,"
  POSTFIX
  "dp")

add_subdirectory(hellolib)
add_subdirectory(helloapp)

cs_finalize_project(csSmoke)
