project(csSmokeMidA LANGUAGES CXX)

cs_add_library(csSmokeMidA STATIC)
cs_add_library(csSmokeMidA::csSmokeMidA ALIAS csSmokeMidA)

# PUBLIC: the find_package is propagated to the installed csSmokeMidAConfig.cmake (find_dependency)
cs_find_package(csSmokeMidA PUBLIC csSmokeBase COMPONENTS text REQUIRED CONFIG)

cs_target_sources(csSmokeMidA PRIVATE csSmokeMidA.cpp PRIVATE_INSTALL csSmokeMidA.hpp)

cs_target_link_libraries(csSmokeMidA PUBLIC csSmokeBase::text csSmokeMidA::cscmake_base_include)

cs_install_target(csSmokeMidA csSmokeMidA DEFAULT)

cs_finalize_target(csSmokeMidA)

add_subdirectory(tests)
