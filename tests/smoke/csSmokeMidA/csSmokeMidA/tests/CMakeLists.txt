cs_add_executable(csSmokeMidATest)

cs_target_sources(csSmokeMidATest PRIVATE test_csSmokeMidA.cpp)

cs_target_link_libraries(csSmokeMidATest PRIVATE csSmokeMidA::csSmokeMidA)

add_test(NAME csSmokeMidATest COMMAND csSmokeMidATest)
