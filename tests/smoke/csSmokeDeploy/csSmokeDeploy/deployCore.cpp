#include <csSmokeDeploy/deployCore.hpp>
#include <csSmokeShared/sharedText.hpp>

namespace cssmokedeploy {
std::string deploy_message() { return "deploy(" + cssmokeshared::text_message() + ")"; }
} // namespace cssmokedeploy
