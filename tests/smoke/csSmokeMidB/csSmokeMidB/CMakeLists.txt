# no project() call here: the library folder belongs to the top project csSmokeMidB
cs_add_library(csSmokeMidB STATIC)
cs_add_library(csSmokeMidB::csSmokeMidB ALIAS csSmokeMidB)

# PUBLIC: the find_package is propagated to the installed csSmokeMidBConfig.cmake (find_dependency)
cs_find_package(
  csSmokeMidB
  PUBLIC
  csSmokeBase
  COMPONENTS
  core
  REQUIRED
  CONFIG)

cs_target_sources(csSmokeMidB PRIVATE csSmokeMidB.cpp PRIVATE_INSTALL csSmokeMidB.hpp)

cs_target_link_libraries(csSmokeMidB PUBLIC csSmokeBase::core csSmokeMidB::csSmokeMidB_csCMakeBaseInclude
                         csSmokeMidB::csSmokeMidB_csCMakeCompileOptionsDefault)

cs_install_target(csSmokeMidB csSmokeMidB DEFAULT)

cs_finalize_target(csSmokeMidB)

add_subdirectory(tests)
