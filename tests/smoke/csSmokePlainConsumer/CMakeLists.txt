# consumer without csCMake: plain CMake (no include(csCMake)) using an installed csCMake package through find_package.
# The csCMake presets only give the compiler, the generator and CMAKE_PREFIX_PATH (the workspace install folder).
#
# See tests/smoke/README.md.
cmake_minimum_required(VERSION 3.31)
project(csSmokePlainConsumer VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)

find_package(csSmokeShared CONFIG REQUIRED COMPONENTS text)

add_executable(plainConsumer main.cpp)
target_link_libraries(plainConsumer PRIVATE csSmokeShared::sharedText)

# Windows: no RPATH, the DLLs of the package next to the executable
if(WIN32)
  add_custom_command(
    TARGET plainConsumer
    POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different $<TARGET_RUNTIME_DLLS:plainConsumer> $<TARGET_FILE_DIR:plainConsumer>
    COMMAND_EXPAND_LISTS
    COMMENT "Copy the DLLs of plainConsumer next to it"
  )
endif()

# the install step of the workflow presets needs an install rule (the installed executable is not run: the shared
# libraries of other packages are not found from the install folder)
install(TARGETS plainConsumer)

enable_testing()
add_test(NAME plainConsumerOutput COMMAND plainConsumer)
set_tests_properties(plainConsumerOutput PROPERTIES PASS_REGULAR_EXPRESSION "plain\\(shared-text\\(shared-core\\)\\)")
