# Windows: export every symbol of the DLL (no export macros in the sources)
set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)

# the shared libraries of another package: shipped by the deployments (Linux)
cs_find_package(csSmokeDeploy PRIVATE csSmokeShared REQUIRED CONFIG)

# a shared library of the project, using the other package
cs_add_library(deployCore SHARED)
cs_target_sources(deployCore PRIVATE deployCore.cpp PRIVATE_INSTALL deployCore.hpp)
cs_target_link_libraries(deployCore PUBLIC csSmokeDeploy::cscmake_base_include PRIVATE csSmokeShared::sharedText)
cs_install_target(deployCore COMPONENT core DEFAULT)

# the application, installed and deployed
cs_add_executable(csSmokeDeployApp)
cs_target_sources(csSmokeDeployApp PRIVATE main.cpp)
cs_target_link_libraries(csSmokeDeployApp PRIVATE deployCore)
cs_install_target(csSmokeDeployApp COMPONENT app)

# a sample: deployed, not installed
cs_add_executable(csSmokeDeploySample)
cs_target_sources(csSmokeDeploySample PRIVATE sample.cpp)
cs_target_link_libraries(csSmokeDeploySample PRIVATE deployCore)

# two deployments sharing deployCore and the libraries of csSmokeShared: each folder has its own copies
cs_deployment(app TARGETS csSmokeDeployApp FILES data/readme.txt DESTINATION share/csSmokeDeploy)
cs_deployment(sample TARGETS csSmokeDeploySample CONFIGS Release RelWithDebInfo)
