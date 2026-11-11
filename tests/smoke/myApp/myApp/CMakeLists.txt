cs_add_library(core STATIC)
cs_target_sources(core PRIVATE core/Greeting.cpp PRIVATE_INSTALL core/Greeting.hpp)
cs_target_link_libraries(core PUBLIC myApp::cscmake_base_include)
cs_install_target(core COMPONENT core DEFAULT)

cs_add_executable(myApp main.cpp)
cs_target_link_libraries(myApp PRIVATE core)
cs_install_target(myApp COMPONENT app)

add_test(NAME myAppGreets COMMAND myApp)
set_tests_properties(myAppGreets PROPERTIES PASS_REGULAR_EXPRESSION "Hello from myApp")
