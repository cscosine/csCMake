project(csSmokeBase LANGUAGES CXX)

# the package root target: base include folder for every component
cs_add_library(csSmokeBase INTERFACE)
cs_add_library(csSmokeBase::csSmokeBase ALIAS csSmokeBase)
cs_target_link_libraries(csSmokeBase INTERFACE csSmokeBase::cscmake_base_include)
cs_install_target(csSmokeBase COMPONENT csSmokeBase)
cs_finalize_target(csSmokeBase)

add_subdirectory(core)
add_subdirectory(text)
