cs_add_executable(hellolibTest)

cs_target_sources(hellolibTest PRIVATE test_hellolib.cpp)

cs_target_link_libraries(hellolibTest PRIVATE csSmoke::hellolib)

cs_finalize_target(hellolibTest)

add_test(NAME hellolibTest COMMAND hellolibTest)
