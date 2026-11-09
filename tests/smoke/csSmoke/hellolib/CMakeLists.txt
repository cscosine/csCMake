cs_add_library(hellolib STATIC)
cs_add_library(csSmoke::hellolib ALIAS hellolib)

cs_target_sources(hellolib PRIVATE HelloLib.cpp PRIVATE_INSTALL HelloLib.hpp)

cs_target_link_libraries(hellolib PUBLIC csSmoke::csSmoke_csCMakeBaseInclude)

cs_install_target(hellolib hellolib DEFAULT)

cs_finalize_target(hellolib)

add_subdirectory(tests)
