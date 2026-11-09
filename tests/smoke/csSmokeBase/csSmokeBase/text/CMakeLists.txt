# static component depending on the core component of the same package
project(text LANGUAGES CXX)

cs_add_library(text STATIC)
cs_add_library(csSmokeBase::text ALIAS text)

cs_target_sources(text PRIVATE Text.cpp PRIVATE_INSTALL Text.hpp)

cs_target_link_libraries(text PUBLIC csSmokeBase::core csSmokeBase::cscmake_compile_options)

cs_install_target(text text)

cs_finalize_target(text)

add_subdirectory(tests)
