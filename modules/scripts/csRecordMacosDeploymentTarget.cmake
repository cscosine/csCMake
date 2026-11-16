# Record the oldest macOS the binaries of the project run on (CMAKE_OSX_DEPLOYMENT_TARGET) in its installed files:
# <prefix>/share/cscmake/<project>.macos-deployment-target, one line with the version. A consumer that finds the package
# with csCMake (cs_find_package, cs_after_find_dependency) checks it against its own value (csMacosDeploymentTarget).
#
# For a project without csCMake (a csCMake project records under its namespace, in cs_initialize_project). A project
# (e.g. a third-party library built with the csCMake presets) includes it after its project() through
# CMAKE_PROJECT_INCLUDE (a module of CMAKE_MODULE_PATH), set with its deployment target in the
# cscmake-project-setup-macos preset of its csCMakeProjectSetup.json: plain CMake. Once per build, for the top-level
# project only; nothing when the project sets no deployment target (on macOS: a warning).
if(NOT PROJECT_IS_TOP_LEVEL)
  return()
endif()
get_property(_cs_record_done GLOBAL PROPERTY _CSCMAKE_MACOS_DEPLOYMENT_TARGET_RECORDED)
if(_cs_record_done)
  unset(_cs_record_done)
  return()
endif()
unset(_cs_record_done)
set_property(GLOBAL PROPERTY _CSCMAKE_MACOS_DEPLOYMENT_TARGET_RECORDED TRUE)

if(CMAKE_OSX_DEPLOYMENT_TARGET)
  set(_cs_record_file "${CMAKE_BINARY_DIR}/cscmake/${PROJECT_NAME}.macos-deployment-target")
  file(WRITE "${_cs_record_file}" "${CMAKE_OSX_DEPLOYMENT_TARGET}\n")
  install(FILES "${_cs_record_file}" DESTINATION share/cscmake)
  unset(_cs_record_file)
elseif(APPLE)
  message(
    WARNING
    "${PROJECT_NAME}: no CMAKE_OSX_DEPLOYMENT_TARGET, the binaries are built for the macOS of this machine and do not "
    "run on an older one: set CMAKE_OSX_DEPLOYMENT_TARGET in the cscmake-project-setup-macos preset of its "
    "csCMakeProjectSetup.json."
  )
endif()
