#.rst:
# csDeployment
# ------------
#
# Deployments: folders that run on a machine without the build, the workspace or the packages of the dependencies. A
# deployment is declared with :command:`cs_deployment`, independently of the installed package: it can ship targets the
# package does not install (e.g. samples), and a project can declare several. The normal install makes it too, in its
# own folder next to the installed package (:variable:`CSCMAKE_DEPLOY_DIR`), in the configurations it lists; its build
# target ``cs_deploy_<name>`` makes it alone, on an existing build tree.
#
# A deployment is run time only: executables, shared and module libraries, and the files the project lists. Never
# headers, static or import libraries, CMake package files or PDB files.
#
# Layout of the folder of a deployment, the one of the installed package (``CMAKE_INSTALL_BINDIR``,
# ``CMAKE_INSTALL_LIBDIR``): executables in ``bin/``, shared and module libraries in ``lib/`` (``bin/`` on Windows),
# where the install RPATH of :command:`cs_add_executable` / :command:`cs_add_library` finds them. The shared libraries
# of other packages the deployment needs (e.g. OpenCV, Qt) go to ``lib/`` too, unchanged: their own RPATH (``$ORIGIN``)
# finds each other there. Linux only (native builds): on the other systems, a deployment has the binaries of the
# project only, with a warning.
#
# Commands
# ^^^^^^^^

include_guard(GLOBAL)
include(modules/csDebug)
include(modules/csInternal)
include(modules/csTargetDependencies)

include(GNUInstallDirs)

#.rst:
# .. command:: cs_deployment
#
#   Declare a deployment of the project, or add to it.
#
#   .. code-block:: cmake
#
#     cs_deployment(<name>
#       [TARGETS <target>...]
#       [FILES <file>...] [DIRECTORY <folder>...] [DESTINATION <folder>]
#       [CONFIGS <config>...]
#       [EXCLUDE_REGEXES <regex>...])
#
#   The first call with a name creates the deployment, the next ones (in any folder of the project) add to it. Its
#   content goes to the install component ``cs_deploy_<name>``, not in the install prefix: the deployment is made in
#   its own folder, ``<CSCMAKE_DEPLOY_DIR>/<name>-<config>`` (:variable:`CSCMAKE_DEPLOY_DIR`), emptied first:
#
#   * by the normal install (``cmake --install``, the ``install`` target), in the configurations of the deployment
#     (in another configuration: skipped, with a message); a deployment that fails fails the install. Not with
#     :variable:`CSCMAKE_DEPLOY_ON_INSTALL` ``OFF``;
#   * by the build target ``cs_deploy_<name>``, which also builds what the deployment ships; built in a configuration
#     the deployment does not list, it fails.
#
#   .. code-block:: shell
#
#     cmake --build --preset <build preset of a configuration> --target cs_deploy_<name>
#
#   Then the deployment gets the shared libraries of other packages its binaries need (Linux), found from their build
#   tree: their build RPATH finds the packages of the workspace before the ones of the system. Not shipped: the
#   libraries of the system (in ``/lib``, ``/usr/lib``, ...) and what they need, and ``EXCLUDE_REGEXES``. Then the
#   deployment is checked, its binaries scanned again with their own RPATH and the system folders only: every library
#   they need is in the deployment or a library of the system, and every library it ships resolves to its copy, never
#   to a library of the system of the same name. Last, ``system-requirements.txt`` in the deployment lists the
#   libraries of the system it needs, with their Debian packages and the ``apt install`` line: the machine running the
#   deployment needs them (the same system release).
#
#   At the end of the top folder of the build, ``cs-deployments.json`` in the top build folder lists the deployments
#   of the build: their projects, build targets, configurations, targets and folders.
#
#   A mistake fails, at configure time or when the deployment is built: a deployment without targets (a typo in the
#   name), a target that is not an executable or a shared or module library of the project, a configuration the
#   project does not have, a setting given twice with different values, a file or folder that does not exist, the build
#   target built in a configuration the deployment does not list, a library not found or found in two places, a
#   deployed binary that does not find a library in the deployment or the system, or finds a library of the system
#   instead of the copy of the deployment.
#
#   Nothing of a deployment is in the install prefix, nor CMake package files: the deployments of the workspace are not
#   found by :command:`find_package`.
#
#   ``<name>``
#     The name of the deployment: a letter, then letters, digits and ``_``. Unique in the build (two projects of the
#     same build cannot declare the same name).
#
#   ``TARGETS``
#     Executables and shared or module libraries of the project (created with :command:`cs_add_executable` /
#     :command:`cs_add_library`, before or after this call), with the shared and module libraries of the build they
#     depend on (:prop_tgt:`CSCMAKE_PROJECT_DEPENDENCIES`). A deployment needs at least one target.
#
#   ``FILES``, ``DIRECTORY``
#     Files and folders to ship (data, configuration files, licences), relative to the current source folder or
#     absolute; a folder as with :command:`install(DIRECTORY) <install>`: ``data`` ships the folder, ``data/`` its
#     content. They need ``DESTINATION``.
#
#   ``DESTINATION``
#     The folder of ``FILES`` and ``DIRECTORY`` in the deployment, relative (e.g. ``share/demo``), without ``..``.
#
#   ``CONFIGS``
#     The configurations the deployment is made in, among the ones of the project (default ``Release``). Given once:
#     another call may repeat the same list only.
#
#   ``EXCLUDE_REGEXES``
#     Regular expressions of the libraries never shipped, matched on their names and paths (e.g. ``^libGL\\.so``: a
#     library the machines running the deployment have); the check ignores them too. Given once, as ``CONFIGS``.
#
#   :Reads: :variable:`CSCMAKE_NAMESPACE`, :variable:`CSCMAKE_DEPLOY_DIR`, :variable:`CSCMAKE_DEPLOY_ON_INSTALL`
#   :Writes: :prop_gbl:`CSCMAKE_<namespace>_DEPLOYMENTS`, :prop_gbl:`CSCMAKE_DEPLOYMENT_<name>_NAMESPACE`,
#     :prop_gbl:`CSCMAKE_DEPLOYMENT_<name>_TARGETS`, :prop_gbl:`CSCMAKE_DEPLOYMENT_<name>_CONFIGS`,
#     :prop_gbl:`CSCMAKE_DEPLOYMENT_<name>_EXCLUDE_REGEXES`
function(cs_deployment name)
  _cs_message_context(cs_deployment)
  cmake_parse_arguments(PARSE_ARGV 1 arg "" "DESTINATION" "TARGETS;FILES;DIRECTORY;CONFIGS;EXCLUDE_REGEXES")
  if(arg_UNPARSED_ARGUMENTS OR arg_KEYWORDS_MISSING_VALUES)
    message(
      FATAL_ERROR
      "[cs_deployment] ${name}: unexpected or empty arguments ${arg_UNPARSED_ARGUMENTS} ${arg_KEYWORDS_MISSING_VALUES} "
      "(cs_deployment(<name> [TARGETS <target>...] [FILES <file>...] [DIRECTORY <folder>...] [DESTINATION <folder>] "
      "[CONFIGS <config>...] [EXCLUDE_REGEXES <regex>...]))"
    )
  endif()
  _cs_deployment_check_call(${name})
  _cs_deployment_register(${name})

  foreach(target_name IN LISTS arg_TARGETS)
    _cs_add_to_global_property_unique_value(CSCMAKE_DEPLOYMENT_${name}_TARGETS ${target_name})
  endforeach()
  if(DEFINED arg_CONFIGS)
    _cs_deployment_check_configs(${name} "${arg_CONFIGS}")
    _cs_deployment_set_setting(${name} CONFIGS CSCMAKE_DEPLOYMENT_${name}_CONFIGS "${arg_CONFIGS}")
  endif()
  if(DEFINED arg_EXCLUDE_REGEXES)
    _cs_deployment_set_setting(
      ${name}
      EXCLUDE_REGEXES
      CSCMAKE_DEPLOYMENT_${name}_EXCLUDE_REGEXES
      "${arg_EXCLUDE_REGEXES}"
    )
  endif()
  if(DEFINED arg_FILES OR DEFINED arg_DIRECTORY OR DEFINED arg_DESTINATION)
    _cs_deployment_install_files(${name} "${arg_DESTINATION}" "${arg_FILES}" "${arg_DIRECTORY}")
  endif()
endfunction()

# Fail unless cs_deployment(name ...) is called in a csCMake project not yet finalized, with a valid name not used by
# another project of the build.
#
# Reads:
#
# * variable CSCMAKE_NAMESPACE
# * global property _CSCMAKE_PROJECT_FINALIZED_<namespace>, CSCMAKE_DEPLOYMENT_<name>_NAMESPACE
function(_cs_deployment_check_call name)
  if(NOT CSCMAKE_NAMESPACE)
    message(FATAL_ERROR "[cs_deployment] ${name}: call cs_initialize_project(NAMESPACE ...) before")
  endif()
  get_property(finalized GLOBAL PROPERTY _CSCMAKE_PROJECT_FINALIZED_${CSCMAKE_NAMESPACE})
  if(finalized)
    message(
      FATAL_ERROR
      "[cs_deployment] ${name}: the project ${CSCMAKE_NAMESPACE} is already finalized (end of the CMakeLists.txt of "
      "its cs_initialize_project)"
    )
  endif()
  if(NOT name MATCHES "^[A-Za-z][A-Za-z0-9_]*$")
    message(FATAL_ERROR "[cs_deployment] '${name}': a deployment name is a letter, then letters, digits and _")
  endif()
  get_property(owner GLOBAL PROPERTY CSCMAKE_DEPLOYMENT_${name}_NAMESPACE)
  if(owner AND NOT owner STREQUAL CSCMAKE_NAMESPACE)
    message(
      FATAL_ERROR
      "[cs_deployment] ${name}: already a deployment of the project ${owner} (the names of the deployments are unique "
      "in a build)"
    )
  endif()
endfunction()

# Record the deployment name in the project (first call only) and, at its first deployment in the build, defer the
# writing of cs-deployments.json to the end of the top folder of the build.
#
# Reads:
#
# * variable CSCMAKE_NAMESPACE
#
# Writes:
#
# * global property CSCMAKE_<namespace>_DEPLOYMENTS, CSCMAKE_DEPLOYMENT_<name>_NAMESPACE
function(_cs_deployment_register name)
  get_property(owner GLOBAL PROPERTY CSCMAKE_DEPLOYMENT_${name}_NAMESPACE)
  if(owner)
    return()
  endif()
  set_property(GLOBAL PROPERTY CSCMAKE_DEPLOYMENT_${name}_NAMESPACE ${CSCMAKE_NAMESPACE})
  set_property(GLOBAL APPEND PROPERTY CSCMAKE_${CSCMAKE_NAMESPACE}_DEPLOYMENTS ${name})
  get_property(deferred GLOBAL PROPERTY _CSCMAKE_DEPLOYMENTS_FILE_DEFERRED)
  if(NOT deferred)
    set_property(GLOBAL PROPERTY _CSCMAKE_DEPLOYMENTS_FILE_DEFERRED TRUE)
    cmake_language(DEFER DIRECTORY "${CMAKE_SOURCE_DIR}" CALL _cs_write_deployments_file)
  endif()
  message(VERBOSE "${CSCMAKE_NAMESPACE}: deployment ${name}")
endfunction()

# Set the global property of the setting keyword (CONFIGS, EXCLUDE_REGEXES) of the deployment name to
# values: a second call may repeat the same values only.
function(_cs_deployment_set_setting name keyword property values)
  get_property(previous_set GLOBAL PROPERTY ${property} SET)
  get_property(previous GLOBAL PROPERTY ${property})
  if(previous_set AND NOT "${previous}" STREQUAL "${values}")
    message(
      FATAL_ERROR
      "[cs_deployment] ${name}: ${keyword} ${values}, but already ${keyword} ${previous} (given once per deployment)"
    )
  endif()
  set_property(GLOBAL PROPERTY ${property} "${values}")
endfunction()

# Fail unless every configuration of configs is a configuration of the project (once each).
function(_cs_deployment_check_configs name configs)
  cs_get_build_configurations(project_configs)
  set(seen "")
  foreach(config IN LISTS configs)
    if(NOT config IN_LIST project_configs)
      message(
        FATAL_ERROR
        "[cs_deployment] ${name}: ${config} is not a configuration of the project (${project_configs})"
      )
    endif()
    if(config IN_LIST seen)
      message(FATAL_ERROR "[cs_deployment] ${name}: configuration ${config} given twice")
    endif()
    list(APPEND seen ${config})
  endforeach()
endfunction()

# Add the install rules of files and folders to the component of the deployment name, under destination (relative,
# without ..); relative paths are relative to the current source folder, and must exist (unless generator expressions).
function(_cs_deployment_install_files name destination files directories)
  if("${destination}" STREQUAL "" OR (NOT files AND NOT directories))
    message(FATAL_ERROR "[cs_deployment] ${name}: FILES and DIRECTORY go with DESTINATION, and DESTINATION with them")
  endif()
  cmake_path(SET destination NORMALIZE "${destination}")
  if(IS_ABSOLUTE "${destination}" OR destination MATCHES "(^|/)\\.\\.(/|$)")
    message(
      FATAL_ERROR
      "[cs_deployment] ${name}: DESTINATION ${destination} is a folder of the deployment: relative, without .."
    )
  endif()
  _cs_deployment_absolute_paths(${name} "${files}" FILES absolute_files)
  _cs_deployment_absolute_paths(${name} "${directories}" DIRECTORY absolute_directories)
  if(absolute_files)
    install(FILES ${absolute_files} DESTINATION "${destination}" COMPONENT cs_deploy_${name} EXCLUDE_FROM_ALL)
  endif()
  if(absolute_directories)
    install(DIRECTORY ${absolute_directories} DESTINATION "${destination}" COMPONENT cs_deploy_${name} EXCLUDE_FROM_ALL)
  endif()
endfunction()

# Set out to the paths of the keyword made absolute (from the current source folder; a trailing / kept): files (FILES)
# or folders (DIRECTORY); fail when one does not exist or is of the other kind. Paths with generator
# expressions are kept as given.
function(_cs_deployment_absolute_paths name paths keyword out)
  set(result "")
  foreach(path IN LISTS paths)
    if(path MATCHES "\\$<")
      list(APPEND result "${path}")
      continue()
    endif()
    set(trailing "")
    if(path MATCHES "/$")
      set(trailing "/")
    endif()
    cmake_path(ABSOLUTE_PATH path BASE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" NORMALIZE OUTPUT_VARIABLE absolute)
    string(REGEX REPLACE "/$" "" absolute "${absolute}")
    if(NOT keyword STREQUAL "FILES" AND NOT IS_DIRECTORY "${absolute}")
      message(FATAL_ERROR "[cs_deployment] ${name}: ${keyword} ${path} is not a folder (${absolute})")
    elseif(keyword STREQUAL "FILES" AND (NOT EXISTS "${absolute}" OR IS_DIRECTORY "${absolute}"))
      message(FATAL_ERROR "[cs_deployment] ${name}: FILES ${path} is not a file (${absolute})")
    endif()
    list(APPEND result "${absolute}${trailing}")
  endforeach()
  set(${out} "${result}" PARENT_SCOPE)
endfunction()

# Finalize the deployments of the project (from _cs_finalize_project, after the dependencies of the targets): check
# their targets and configurations, add the install rules of the targets and the build targets cs_deploy_<name>.
#
# Reads:
#
# * global property CSCMAKE_<namespace>_DEPLOYMENTS
function(_cs_finalize_deployments namespace)
  get_property(names GLOBAL PROPERTY CSCMAKE_${namespace}_DEPLOYMENTS)
  foreach(name IN LISTS names)
    _cs_finalize_deployment(${namespace} ${name})
  endforeach()
endfunction()

# Finalize the deployment name of the project namespace: its targets, configurations, folder, install rules and build
# target.
#
# Reads:
#
# * variable CSCMAKE_DEPLOY_DIR
# * global property CSCMAKE_DEPLOYMENT_<name>_TARGETS, CSCMAKE_DEPLOYMENT_<name>_CONFIGS
#
# Writes:
#
# * global property CSCMAKE_DEPLOYMENT_<name>_CONFIGS, CSCMAKE_DEPLOYMENT_<name>_DIR, _CSCMAKE_DEPLOYMENTS
function(_cs_finalize_deployment namespace name)
  get_property(targets GLOBAL PROPERTY CSCMAKE_DEPLOYMENT_${name}_TARGETS)
  if(NOT targets)
    message(
      FATAL_ERROR
      "[cs_deployment] ${name}: no TARGETS (a deployment ships at least one target; a typo in the name of the "
      "deployment?)"
    )
  endif()
  set(runtime_targets "")
  foreach(target_name IN LISTS targets)
    _cs_deployment_check_target(${namespace} ${name} ${target_name} real_name)
    _cs_list_add_unique_value(runtime_targets ${real_name})
    _cs_get_target_project_dependencies(${real_name} dependencies)
    foreach(dependency IN LISTS dependencies)
      get_target_property(type ${dependency} TYPE)
      if(type MATCHES "^(SHARED_LIBRARY|MODULE_LIBRARY)$")
        _cs_list_add_unique_value(runtime_targets ${dependency})
      endif()
    endforeach()
  endforeach()

  get_property(configs_set GLOBAL PROPERTY CSCMAKE_DEPLOYMENT_${name}_CONFIGS SET)
  if(NOT configs_set)
    _cs_deployment_check_configs(${name} Release)
    _cs_deployment_set_setting(${name} CONFIGS CSCMAKE_DEPLOYMENT_${name}_CONFIGS Release)
  endif()
  get_property(configs GLOBAL PROPERTY CSCMAKE_DEPLOYMENT_${name}_CONFIGS)

  set(deploy_dir "${CMAKE_BINARY_DIR}/deploy")
  if(CSCMAKE_DEPLOY_DIR)
    cmake_path(
      ABSOLUTE_PATH CSCMAKE_DEPLOY_DIR
      BASE_DIRECTORY "${CMAKE_BINARY_DIR}"
      NORMALIZE
      OUTPUT_VARIABLE deploy_dir
    )
    string(REGEX REPLACE "/$" "" deploy_dir "${deploy_dir}")
  endif()
  set_property(GLOBAL PROPERTY CSCMAKE_DEPLOYMENT_${name}_DIR "${deploy_dir}")
  set_property(GLOBAL APPEND PROPERTY _CSCMAKE_DEPLOYMENTS ${name})

  _cs_deployment_install_targets(${name} "${runtime_targets}")
  _cs_deployment_add_closure(${name} "${runtime_targets}")
  _cs_deployment_add_build_target(${name} "${configs}" "${deploy_dir}" "${runtime_targets}")
  _cs_deployment_add_install_rule(${name} "${configs}" "${deploy_dir}")
  list(JOIN runtime_targets ", " text)
  message(VERBOSE "${namespace}: deployment ${name} (${configs}): ${text} -> ${deploy_dir}/${name}-<config>")
endfunction()

# Fail unless target_name is an executable or a shared or module library of the project namespace (an alias resolved,
# set in real_name_out), not a macOS bundle.
#
# Reads:
#
# * target property CSCMAKE_NAMESPACE
function(_cs_deployment_check_target namespace name target_name real_name_out)
  if(NOT TARGET ${target_name})
    message(FATAL_ERROR "[cs_deployment] ${name}: ${target_name} is not a target")
  endif()
  get_target_property(aliased ${target_name} ALIASED_TARGET)
  if(aliased)
    set(target_name ${aliased})
  endif()
  get_target_property(target_namespace ${target_name} CSCMAKE_NAMESPACE)
  if(NOT target_namespace STREQUAL namespace)
    message(
      FATAL_ERROR
      "[cs_deployment] ${name}: ${target_name} is not a target of the project ${namespace} (cs_add_executable / "
      "cs_add_library of the project)"
    )
  endif()
  get_target_property(type ${target_name} TYPE)
  if(NOT type MATCHES "^(EXECUTABLE|SHARED_LIBRARY|MODULE_LIBRARY)$")
    message(
      FATAL_ERROR
      "[cs_deployment] ${name}: ${target_name} is a ${type}: a deployment ships executables and shared or module "
      "libraries (a static library is in the executables that link it)"
    )
  endif()
  get_target_property(bundle ${target_name} MACOSX_BUNDLE)
  if(bundle)
    message(FATAL_ERROR "[cs_deployment] ${name}: ${target_name} is a macOS bundle (MACOSX_BUNDLE): not supported")
  endif()
  set(${real_name_out} ${target_name} PARENT_SCOPE)
endfunction()

# Install the targets in the component of the deployment name: executables and DLLs in CMAKE_INSTALL_BINDIR, shared and
# module libraries in CMAKE_INSTALL_LIBDIR (no namelink); the import libraries go to a component never installed.
function(_cs_deployment_install_targets name targets)
  install(
    TARGETS ${targets}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR} COMPONENT cs_deploy_${name} EXCLUDE_FROM_ALL
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT cs_deploy_${name} NAMELINK_SKIP EXCLUDE_FROM_ALL
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT cs_not_deployed EXCLUDE_FROM_ALL
  )
endfunction()

# Add the install rule shipping the libraries of other packages the targets of the deployment name need, then checking
# the deployment (modules/scripts/csDeploymentClosure.cmake), after the targets, in the component of the deployment.
# Linux only (native builds): elsewhere, a warning.
#
# Reads:
#
# * global property CSCMAKE_DEPLOYMENT_<name>_EXCLUDE_REGEXES
function(_cs_deployment_add_closure name targets)
  if(NOT CMAKE_SYSTEM_NAME STREQUAL "Linux" OR CMAKE_CROSSCOMPILING)
    message(
      WARNING
      "[cs_deployment] ${name}: the libraries of other packages are shipped on Linux only, in native builds: the "
      "deployment has the binaries of the project only"
    )
    return()
  endif()
  set(call "_cs_deployment_closure(NAME ${name} CONFIG $<CONFIG> LIBDIR [==[${CMAKE_INSTALL_LIBDIR}]==]")
  foreach(target_name IN LISTS targets)
    get_target_property(type ${target_name} TYPE)
    if(type STREQUAL "EXECUTABLE")
      string(APPEND call " BUILD_EXECUTABLES [==[$<TARGET_FILE:${target_name}>]==]")
      string(APPEND call " EXECUTABLES [==[${CMAKE_INSTALL_BINDIR}/$<TARGET_FILE_NAME:${target_name}>]==]")
    elseif(type STREQUAL "SHARED_LIBRARY")
      string(APPEND call " BUILD_LIBRARIES [==[$<TARGET_FILE:${target_name}>]==]")
      string(APPEND call " LIBRARIES [==[${CMAKE_INSTALL_LIBDIR}/$<TARGET_FILE_NAME:${target_name}>]==]")
    else()
      string(APPEND call " BUILD_MODULES [==[$<TARGET_FILE:${target_name}>]==]")
      string(APPEND call " MODULES [==[${CMAKE_INSTALL_LIBDIR}/$<TARGET_FILE_NAME:${target_name}>]==]")
    endif()
  endforeach()
  get_property(excludes GLOBAL PROPERTY CSCMAKE_DEPLOYMENT_${name}_EXCLUDE_REGEXES)
  foreach(regex IN LISTS excludes)
    string(APPEND call " EXCLUDE_REGEXES [==[${regex}]==]")
  endforeach()
  _cs_get_root_dir(cscmake_root)
  install(
    CODE "include([==[${cscmake_root}/modules/scripts/csDeploymentClosure.cmake]==])\n${call})"
    COMPONENT cs_deploy_${name}
    EXCLUDE_FROM_ALL
  )
endfunction()

# Set out to the command making the deployment name in the configuration $<CONFIG>
# (modules/scripts/csDeploymentRun.cmake): check the configuration (unlisted: FAIL or SKIP), empty
# <deploy_dir>/<name>-<config> and install the component of the deployment there.
function(
  _cs_deployment_command
  name
  configs
  deploy_dir
  unlisted
  out
)
  _cs_get_root_dir(cscmake_root)
  list(JOIN configs "," configs_text)
  set(
    ${out}
    "${CMAKE_COMMAND}"
    "-Dname=${name}"
    "-Dconfig=$<CONFIG>"
    "-Dconfigs=${configs_text}"
    "-Dunlisted=${unlisted}"
    "-Dbuild_dir=${CMAKE_BINARY_DIR}"
    "-Dcomponent=cs_deploy_${name}"
    "-Dout_dir=${deploy_dir}/${name}-$<CONFIG>"
    -P
    "${cscmake_root}/modules/scripts/csDeploymentRun.cmake"
    PARENT_SCOPE
  )
endfunction()

# Add the build target cs_deploy_<name>: build the targets, then make the deployment; fails in a configuration the
# deployment does not list.
function(_cs_deployment_add_build_target name configs deploy_dir targets)
  _cs_deployment_command(${name} "${configs}" "${deploy_dir}" FAIL command)
  add_custom_target(
    cs_deploy_${name}
    COMMAND ${command}
    COMMENT "Deployment ${name} ($<CONFIG>)"
    USES_TERMINAL
    VERBATIM
  )
  add_dependencies(cs_deploy_${name} ${targets})
endfunction()

# Make the deployment name with the normal install (install(CODE), in the component of the normal install rules), in
# the configurations it lists (skipped in the others); a failure fails the install. Not with CSCMAKE_DEPLOY_ON_INSTALL
# OFF.
#
# Reads:
#
# * variable CSCMAKE_DEPLOY_ON_INSTALL
function(_cs_deployment_add_install_rule name configs deploy_dir)
  if(DEFINED CSCMAKE_DEPLOY_ON_INSTALL AND NOT CSCMAKE_DEPLOY_ON_INSTALL)
    return()
  endif()
  _cs_deployment_command(${name} "${configs}" "${deploy_dir}" SKIP command)
  set(arguments "")
  foreach(argument IN LISTS command)
    string(APPEND arguments " [==[${argument}]==]")
  endforeach()
  install(CODE "execute_process(COMMAND${arguments} COMMAND_ERROR_IS_FATAL ANY)")
endfunction()

# Write cs-deployments.json in the top build folder, at the end of its top folder (every csCMake project of the build is
# finalized): the configurations of the build, and for each deployment its project, build target, configurations,
# targets and folders.
#
# Reads:
#
# * global property _CSCMAKE_DEPLOYMENTS, CSCMAKE_DEPLOYMENT_<name>_NAMESPACE, CSCMAKE_DEPLOYMENT_<name>_TARGETS,
#   CSCMAKE_DEPLOYMENT_<name>_CONFIGS, CSCMAKE_DEPLOYMENT_<name>_DIR
function(_cs_write_deployments_file)
  get_property(multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
  if(multi_config)
    set(build_configs ${CMAKE_CONFIGURATION_TYPES})
  else()
    set(build_configs ${CMAKE_BUILD_TYPE})
  endif()
  _cs_json_string_array("${build_configs}" build_configs_json)
  set(json "{}")
  string(JSON json SET "${json}" version 1)
  string(JSON json SET "${json}" build_dir "\"${CMAKE_BINARY_DIR}\"")
  string(JSON json SET "${json}" build_configs "${build_configs_json}")
  string(JSON json SET "${json}" deployments "[]")
  get_property(names GLOBAL PROPERTY _CSCMAKE_DEPLOYMENTS)
  set(index 0)
  foreach(name IN LISTS names)
    _cs_deployment_json(${name} entry)
    string(JSON json SET "${json}" deployments ${index} "${entry}")
    math(EXPR index "${index} + 1")
  endforeach()
  file(WRITE "${CMAKE_BINARY_DIR}/cs-deployments.json" "${json}\n")
endfunction()

# Set out to the JSON object of the deployment name, for cs-deployments.json.
#
# Reads:
#
# * global property CSCMAKE_DEPLOYMENT_<name>_NAMESPACE, CSCMAKE_DEPLOYMENT_<name>_TARGETS,
#   CSCMAKE_DEPLOYMENT_<name>_CONFIGS, CSCMAKE_DEPLOYMENT_<name>_DIR
function(_cs_deployment_json name out)
  get_property(namespace GLOBAL PROPERTY CSCMAKE_DEPLOYMENT_${name}_NAMESPACE)
  get_property(targets GLOBAL PROPERTY CSCMAKE_DEPLOYMENT_${name}_TARGETS)
  get_property(configs GLOBAL PROPERTY CSCMAKE_DEPLOYMENT_${name}_CONFIGS)
  get_property(deploy_dir GLOBAL PROPERTY CSCMAKE_DEPLOYMENT_${name}_DIR)
  _cs_json_string_array("${targets}" targets_json)
  _cs_json_string_array("${configs}" configs_json)
  set(folders "{}")
  foreach(config IN LISTS configs)
    string(JSON folders SET "${folders}" ${config} "\"${deploy_dir}/${name}-${config}\"")
  endforeach()
  set(entry "{}")
  string(JSON entry SET "${entry}" name "\"${name}\"")
  string(JSON entry SET "${entry}" project "\"${namespace}\"")
  string(JSON entry SET "${entry}" build_target "\"cs_deploy_${name}\"")
  string(JSON entry SET "${entry}" configs "${configs_json}")
  string(JSON entry SET "${entry}" targets "${targets_json}")
  string(JSON entry SET "${entry}" folders "${folders}")
  set(${out} "${entry}" PARENT_SCOPE)
endfunction()

# Set out to the JSON array of the strings of the list values (names and paths: no character to escape).
function(_cs_json_string_array values out)
  set(array "[]")
  set(index 0)
  foreach(value IN LISTS values)
    string(JSON array SET "${array}" ${index} "\"${value}\"")
    math(EXPR index "${index} + 1")
  endforeach()
  set(${out} "${array}" PARENT_SCOPE)
endfunction()

#.rst:
# Variables
# ^^^^^^^^^
#
# .. variable:: CSCMAKE_DEPLOY_DIR
#
#   The folder of the deployments: each one goes to ``<CSCMAKE_DEPLOY_DIR>/<name>-<config>``. Default
#   ``<top build folder>/deploy``; a relative path is relative to the top build folder. Read when the project is
#   finalized: set it with ``-D`` (the project setup presets set it to the ``deploy/`` folder of the workspace), or in
#   the project before the end of the ``CMakeLists.txt`` of :command:`cs_initialize_project`. Fixed at configure time:
#   ``cmake --install --prefix`` does not change it.
#
# .. variable:: CSCMAKE_DEPLOY_ON_INSTALL
#
#   ``OFF``: the normal install does not make the deployments (e.g. a quicker install while iterating); the build
#   targets ``cs_deploy_<name>`` still do. Default ``ON``. Read when the project is finalized.
#
# Global properties
# ^^^^^^^^^^^^^^^^^
#
# .. prop_gbl:: CSCMAKE_<namespace>_DEPLOYMENTS
#
#   The deployments of the project, in the order of their first :command:`cs_deployment`.
#
# .. prop_gbl:: CSCMAKE_DEPLOYMENT_<name>_NAMESPACE
#
#   The namespace of the project of the deployment.
#
# .. prop_gbl:: CSCMAKE_DEPLOYMENT_<name>_TARGETS
#
#   The ``TARGETS`` of the deployment, as given.
#
# .. prop_gbl:: CSCMAKE_DEPLOYMENT_<name>_CONFIGS
#
#   The configurations of the deployment (``Release`` when not given, set when the project is finalized).
#
# .. prop_gbl:: CSCMAKE_DEPLOYMENT_<name>_EXCLUDE_REGEXES
#
#   The ``EXCLUDE_REGEXES`` of the deployment.
#
# .. prop_gbl:: CSCMAKE_DEPLOYMENT_<name>_DIR
#
#   The folder of the deployments of the project of the deployment (:variable:`CSCMAKE_DEPLOY_DIR`, made absolute),
#   set when the project is finalized.
#
# .. prop_gbl:: _CSCMAKE_DEPLOYMENTS
#
#   Internal: the finalized deployments of the build, for ``cs-deployments.json``.
#
# .. prop_gbl:: _CSCMAKE_DEPLOYMENTS_FILE_DEFERRED
#
#   Internal: the writing of ``cs-deployments.json`` is deferred to the end of the top folder of the build.
