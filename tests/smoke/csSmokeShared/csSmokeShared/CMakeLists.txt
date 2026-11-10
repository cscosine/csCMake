# Windows: export every symbol of the DLLs (no export macros in the sources)
set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)

# a shared library
cs_add_library(sharedCore SHARED)
cs_target_sources(
  sharedCore
  PRIVATE sharedCore.cpp
  PRIVATE_INSTALL sharedCore.hpp)
cs_target_link_libraries(sharedCore PUBLIC csSmokeShared::cscmake_base_include)
cs_install_target(sharedCore core DEFAULT)
cs_finalize_target(sharedCore)

# a shared library using the other one: installed next to it (lib/ on Linux and macOS, bin/ on Windows)
cs_add_library(sharedText SHARED)
cs_target_sources(
  sharedText
  PRIVATE sharedText.cpp
  PRIVATE_INSTALL sharedText.hpp)
cs_target_link_libraries(sharedText PUBLIC sharedCore)
cs_install_target(sharedText text DEFAULT)
cs_finalize_target(sharedText)

# the application: run from the build folder (ctest) and from the install folder (run_smoke.py)
cs_add_executable(csSmokeSharedApp)
cs_target_sources(csSmokeSharedApp PRIVATE main.cpp)
cs_target_link_libraries(csSmokeSharedApp PRIVATE sharedText)
cs_install_target(csSmokeSharedApp app)
cs_finalize_target(csSmokeSharedApp)

add_test(NAME csSmokeSharedAppOutput COMMAND csSmokeSharedApp)
set_tests_properties(csSmokeSharedAppOutput PROPERTIES PASS_REGULAR_EXPRESSION "shared-text\\(shared-core\\)")
