cs_add_executable(csSmokeEnvApp)

# found in the workspace given by the environment
cs_find_package(csSmokeEnvApp PUBLIC csSmokeBase COMPONENTS text REQUIRED CONFIG)

cs_target_sources(csSmokeEnvApp PRIVATE main.cpp)

cs_target_link_libraries(csSmokeEnvApp PRIVATE csSmokeBase::text)

cs_install_target(csSmokeEnvApp COMPONENT csSmokeEnvApp DEFAULT)

cs_finalize_target(csSmokeEnvApp)

add_test(NAME csSmokeEnvOutput COMMAND csSmokeEnvApp)
set_tests_properties(csSmokeEnvOutput PROPERTIES PASS_REGULAR_EXPRESSION "env\\(text\\(base-core\\)\\)")
