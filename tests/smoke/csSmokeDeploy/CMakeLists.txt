# deployments smoke test: an application using its own shared library and the shared libraries of another package
# (csSmokeShared), a sample deployed but not installed, a data file; two deployments, made by the install of the
# workflow presets. run_smoke.py checks their folders and, on Linux, runs them with an empty environment after the
# install folder is moved away.
#
# See tests/smoke/README.md.
cmake_minimum_required(VERSION 3.31)
project(csSmokeDeploy VERSION 1.0.0 LANGUAGES CXX)

include(csCMake)

cs_initialize_project(
  NAMESPACE csSmokeDeploy
  CXX_STANDARD 17
  DEFAULT_CONFIG Debug Release
  DEFAULT_CONFIG_MAPPED RelWithDebInfo
  MAPPED_TO "RelWithDebInfo,Release,"
  CUSTOM_CONFIG Paranoid
  BASED_ON "Debug,Release,"
  POSTFIX "dp"
)

add_subdirectory(csSmokeDeploy)
