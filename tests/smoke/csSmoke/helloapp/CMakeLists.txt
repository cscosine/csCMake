cs_add_executable(helloapp)

cs_target_sources(helloapp PRIVATE main.cpp)

cs_target_link_libraries(helloapp PRIVATE csSmoke::hellolib)

cs_install_target(helloapp helloapp)

cs_finalize_target(helloapp)

# the application prints the library line first, then its own
add_test(NAME helloappOutput COMMAND helloapp)
set_tests_properties(helloappOutput PROPERTIES PASS_REGULAR_EXPRESSION "hello-lib[\r\n]+hello-app")
