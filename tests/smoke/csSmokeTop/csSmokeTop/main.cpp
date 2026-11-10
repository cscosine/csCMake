#include <csSmokeMidA/csSmokeMidA.hpp>
#include <csSmokeMidB/csSmokeMidB.hpp>

#include <iostream>

int main() {
  std::cout << cssmokemida::message() << " " << cssmokemidb::message() << std::endl;
  return 0;
}
