#include <hellolib/HelloLib.hpp>

#include <iostream>

namespace cssmoke {

std::string hello_lib_message() { return "hello-lib"; }

void hello_lib() { std::cout << hello_lib_message() << std::endl; }

} // namespace cssmoke
