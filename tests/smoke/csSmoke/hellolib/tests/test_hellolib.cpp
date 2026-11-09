#include <hellolib/HelloLib.hpp>

#include <iostream>

int main() {
  if (cssmoke::hello_lib_message() != "hello-lib") {
    std::cerr << "unexpected hello_lib_message(): " << cssmoke::hello_lib_message() << std::endl;
    return 1;
  }
  return 0;
}
