# chained-projects smoke test: base package, with components depending on each other
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
  csSmokeBaseSol
  VERSION 1.0.0
  LANGUAGES CXX)

include(csCMake)

# Paranoid: undefined behavior sanitizer, standard library checks, clang-tidy with Clang on Linux (.clang-tidy)
cs_add_compile_profile_rule(
  PROFILE csSmokeBase_paranoid
  CONFIGS Paranoid
  PROFILES cscmake_sanitize_undefined cscmake_hardening)
cs_add_compile_profile_rule(
  PROFILE csSmokeBase_paranoid
  CONFIGS Paranoid
  COMPILERS Clang
  PLATFORMS Linux
  PROFILES cscmake_clang_tidy)

cs_initialize_project(
  NAMESPACE csSmokeBase
  CXX_STANDARD 17
  DEFAULT_CONFIG Debug Release
  DEFAULT_CONFIG_MAPPED RelWithDebInfo
  MAPPED_TO "RelWithDebInfo,Release,"
  CUSTOM_CONFIG Paranoid
  BASED_ON "Debug,Release,"
  POSTFIX "dp"
  DEFAULT_COMPILE_PROFILES cscmake_default csSmokeBase_paranoid)

add_subdirectory(csSmokeBase)

cs_finalize_project()
