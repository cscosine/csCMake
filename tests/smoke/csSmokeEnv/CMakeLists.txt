# smoke test: env layout, workspace and csCMake from the environment
#
# * CSCMAKE_WORKSPACE_ROOT and CSCMAKE_ROOT set by run_smoke.py, also used by the includes of the presets
# * presets/layout/env.json (see tests/smoke/README.md)
cmake_minimum_required(VERSION 3.31)
project(csSmokeEnv VERSION 1.0.0 LANGUAGES CXX)

include(csCMake)

cs_initialize_project(
  NAMESPACE csSmokeEnv
  CXX_STANDARD 17
  DEFAULT_CONFIG Debug Release
  DEFAULT_CONFIG_MAPPED RelWithDebInfo
  MAPPED_TO "RelWithDebInfo,Release,"
  CUSTOM_CONFIG Paranoid
  BASED_ON "Debug,Release,"
  POSTFIX "dp"
)

add_subdirectory(csSmokeEnv)
