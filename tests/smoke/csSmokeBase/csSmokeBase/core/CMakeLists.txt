# header-only component
project(core LANGUAGES CXX)

cs_add_library(core INTERFACE)
cs_add_library(csSmokeBase::core ALIAS core)

cs_target_sources(core PRIVATE_INSTALL Core.hpp)

cs_target_link_libraries(core INTERFACE csSmokeBase::csSmokeBase)

cs_install_target(core COMPONENT core)

# compile each installed header standalone, with the strict options
cs_target_check_installed_headers(core COMPILE_PROFILES cscmake_strict_warnings)
