cs_add_executable(csSmokeMidBTest)

cs_target_sources(csSmokeMidBTest PRIVATE test_csSmokeMidB.cpp)

cs_target_link_libraries(csSmokeMidBTest PRIVATE csSmokeMidB::csSmokeMidB)

cs_finalize_target(csSmokeMidBTest)

add_test(NAME csSmokeMidBTest COMMAND csSmokeMidBTest)
