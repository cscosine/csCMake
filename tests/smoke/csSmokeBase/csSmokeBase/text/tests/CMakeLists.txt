cs_add_executable(textTest)

cs_target_sources(textTest PRIVATE test_text.cpp)

cs_target_link_libraries(textTest PRIVATE csSmokeBase::text)

cs_finalize_target(textTest)

add_test(NAME textTest COMMAND textTest)
