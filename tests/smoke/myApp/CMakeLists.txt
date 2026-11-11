cmake_minimum_required(VERSION 3.31)
project(myApp VERSION 1.0.0 LANGUAGES CXX)

# found through CMAKE_MODULE_PATH, set by the presets
include(csCMake)

cs_initialize_project(NAMESPACE myApp CXX_STANDARD 20 DEFAULT_CONFIG Debug Release)

add_subdirectory(myApp)
