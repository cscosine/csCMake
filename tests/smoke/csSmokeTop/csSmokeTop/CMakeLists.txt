project(csSmokeTop LANGUAGES CXX)

cs_add_executable(csSmokeTop)

# both packages bring csSmokeBase (different components) through their find_dependency. PUBLIC:
# find_dependency(csSmokeMidA) in the installed csSmokeTopConfig.cmake; PRIVATE: csSmokeMidB is not propagated
cs_find_package(csSmokeTop PUBLIC csSmokeMidA REQUIRED CONFIG)
cs_find_package(csSmokeTop PRIVATE csSmokeMidB REQUIRED CONFIG)

cs_target_sources(csSmokeTop PRIVATE main.cpp)

cs_target_link_libraries(csSmokeTop PRIVATE csSmokeMidA::csSmokeMidA csSmokeMidB::csSmokeMidB)

cs_install_target(csSmokeTop csSmokeTop DEFAULT)

cs_finalize_target(csSmokeTop)

add_test(NAME csSmokeTopOutput COMMAND csSmokeTop)
set_tests_properties(csSmokeTopOutput PROPERTIES PASS_REGULAR_EXPRESSION
                                                 "mid-a\\(text\\(base-core\\)\\) mid-b\\(base-core\\)")
