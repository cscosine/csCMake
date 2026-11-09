# header-only component
project(core LANGUAGES CXX)

cs_add_library(core INTERFACE)
cs_add_library(csSmokeBase::core ALIAS core)

cs_target_sources(core PRIVATE_INSTALL Core.hpp)

cs_target_link_libraries(core INTERFACE csSmokeBase::csSmokeBase)

cs_install_target(core core)

cs_finalize_target(core)

# compile each installed header standalone, with the strict options
cs_target_check_installed_headers(core csSmokeBase::cscmake_compile_options_strict)
