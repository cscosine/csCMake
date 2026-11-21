#include <csSmokeShared/sharedCore.hpp>
#include <csSmokeShared/sharedText.hpp>

namespace cssmokeshared {
std::string text_message() { return "shared-text(" + core_message() + ")"; }
} // namespace cssmokeshared
