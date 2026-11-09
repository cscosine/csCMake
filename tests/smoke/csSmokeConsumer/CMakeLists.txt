# consumer of the installed csSmoke package: proves the generated csSmokeConfig.cmake (find_package + components)
cmake_minimum_required(VERSION 3.31)
project(
  csSmokeConsumer
  VERSION 1.0.0
  LANGUAGES CXX)

include(csCMake)

cs_initialize_project(
  csSmokeConsumer
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

cs_add_executable(consumerapp)

cs_find_package(
  consumerapp
  PRIVATE
  csSmoke
  COMPONENTS
  hellolib
  REQUIRED
  CONFIG)

cs_target_sources(consumerapp PRIVATE main.cpp)

cs_target_link_libraries(consumerapp PRIVATE csSmoke::hellolib)

cs_finalize_target(consumerapp)

add_test(NAME consumerappOutput COMMAND consumerapp)
set_tests_properties(consumerappOutput PROPERTIES PASS_REGULAR_EXPRESSION "hello-lib[\r\n]+hello-consumer")

cs_finalize_project(csSmokeConsumer)
