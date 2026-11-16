cmake_minimum_required(VERSION 3.31)

# found through CMAKE_MODULE_PATH, set by the presets: before project(), the oldest macOS the binaries run on
include(csCMakeSetup)
cs_macos_deployment_target(14.4)

project(myApp VERSION 1.0.0 LANGUAGES CXX)

include(csCMake)

cs_initialize_project(NAMESPACE myApp CXX_STANDARD 20 DEFAULT_CONFIG Debug Release)

add_subdirectory(myApp)
