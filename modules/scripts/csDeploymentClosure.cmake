# Ship the shared libraries of other packages a deployment needs, check the deployment and write what it needs from the
# system (csDeployment.cmake, Linux). Included by the install rule of the component cs_deploy_<name>, after the binaries
# of the project: runs in the install script, CMAKE_INSTALL_PREFIX is the folder of the deployment.
#
# 1. The closure: file(GET_RUNTIME_DEPENDENCIES) on the build-tree binaries (their build RPATH finds the packages of the
#    workspace before the system folders), without the libraries of the system (nor what they need), the
#    EXCLUDE_REGEXES and the binaries of the project (installed by the rules before); copied unchanged (their RPATH,
#    e.g. $ORIGIN) with their symlink chain to the library folder of the deployment. A library not found, or found
#    twice, fails.
# 2. The check, on the deployed binaries, with no search folder but their own RPATH and the system ones:
#    * not shadowed: every library the deployment ships resolves to its copy in the deployment, never to another one of
#      the same name (e.g. the Qt of the system);
#    * complete: every library they need, but the ones of the system (and what those need), is in the deployment.
# 3. The report: system-requirements.txt in the deployment, the libraries of the system it needs, with their Debian
#    packages (dpkg-query, when there) and the apt install line.
#
# The install script sets no policies: the ones of csCMake here (include() scopes them to this file, and the functions
# keep them where they are called).
cmake_policy(VERSION 3.31)

# The regular expressions of the paths of the libraries of the system (never shipped).
function(_cs_deployment_system_regexes out)
  set(
    ${out}
    "^/lib/"
    "^/lib32/"
    "^/lib64/"
    "^/libx32/"
    "^/usr/lib/"
    "^/usr/lib32/"
    "^/usr/lib64/"
    "^/usr/libx32/"
    PARENT_SCOPE
  )
endfunction()

# Make the deployment name in the configuration config: ship the closure, check the deployment, write the report.
#
# Arguments: NAME, CONFIG, LIBDIR (the library folder of the deployment, relative), BUILD_EXECUTABLES /
# BUILD_LIBRARIES / BUILD_MODULES (the binaries of the project, in the build tree), EXECUTABLES / LIBRARIES / MODULES
# (the same, in the deployment, relative), EXCLUDE_REGEXES (never shipped).
function(_cs_deployment_closure)
  cmake_parse_arguments(
    PARSE_ARGV 0
    arg
    ""
    "NAME;CONFIG;LIBDIR"
    "BUILD_EXECUTABLES;BUILD_LIBRARIES;BUILD_MODULES;EXECUTABLES;LIBRARIES;MODULES;EXCLUDE_REGEXES"
  )
  set(prefix "${CMAKE_INSTALL_PREFIX}")
  _cs_deployment_collect(
    ${arg_NAME} externals
    EXECUTABLES ${arg_BUILD_EXECUTABLES}
    LIBRARIES ${arg_BUILD_LIBRARIES}
    MODULES ${arg_BUILD_MODULES}
    EXCLUDE_REGEXES ${arg_EXCLUDE_REGEXES}
  )
  set(shipped "")
  if(externals)
    file(INSTALL ${externals} DESTINATION "${prefix}/${arg_LIBDIR}" USE_SOURCE_PERMISSIONS FOLLOW_SYMLINK_CHAIN)
    foreach(file IN LISTS externals)
      cmake_path(GET file FILENAME file_name)
      list(APPEND shipped "${prefix}/${arg_LIBDIR}/${file_name}")
    endforeach()
  endif()
  list(LENGTH externals count)
  message(STATUS "[cs_deploy_${arg_NAME}] ${arg_CONFIG}: ${count} libraries of other packages shipped")

  list(TRANSFORM arg_EXECUTABLES PREPEND "${prefix}/")
  list(TRANSFORM arg_LIBRARIES PREPEND "${prefix}/")
  list(TRANSFORM arg_MODULES PREPEND "${prefix}/")
  list(APPEND arg_LIBRARIES ${shipped})
  _cs_deployment_binaries_args("${arg_EXECUTABLES}" "${arg_LIBRARIES}" "${arg_MODULES}" binaries)
  file(REAL_PATH "${prefix}" real_prefix)
  _cs_deployment_check_shadowed(
    ${arg_NAME} "${real_prefix}" "${binaries}" system_libraries
    SHIPPED ${arg_LIBRARIES} ${arg_MODULES}
    EXCLUDE_REGEXES ${arg_EXCLUDE_REGEXES}
  )
  _cs_deployment_check_complete(${arg_NAME} "${real_prefix}" "${binaries}" "${arg_EXCLUDE_REGEXES}")
  message(
    STATUS
    "[cs_deploy_${arg_NAME}] ${arg_CONFIG}: checked, every library resolves in the deployment or the system"
  )
  _cs_deployment_write_report(${arg_NAME} ${arg_CONFIG} "${prefix}" "${system_libraries}")
endfunction()

# Set out to the binaries arguments of file(GET_RUNTIME_DEPENDENCIES): EXECUTABLES, LIBRARIES, MODULES (the empty ones
# left out).
function(_cs_deployment_binaries_args executables libraries modules out)
  set(result "")
  if(executables)
    list(APPEND result EXECUTABLES ${executables})
  endif()
  if(libraries)
    list(APPEND result LIBRARIES ${libraries})
  endif()
  if(modules)
    list(APPEND result MODULES ${modules})
  endif()
  set(${out} "${result}" PARENT_SCOPE)
endfunction()

# Set out to the libraries the binaries (EXECUTABLES, LIBRARIES, MODULES, in the build tree) need, resolved from the
# build tree, but the libraries of the system (and what they need), the EXCLUDE_REGEXES and the binaries of the project;
# fail when one is not found or found twice.
function(_cs_deployment_collect name out)
  cmake_parse_arguments(PARSE_ARGV 2 arg "" "" "EXECUTABLES;LIBRARIES;MODULES;EXCLUDE_REGEXES")
  _cs_deployment_binaries_args("${arg_EXECUTABLES}" "${arg_LIBRARIES}" "${arg_MODULES}" binaries)
  _cs_deployment_system_regexes(system)
  set(excludes ${arg_EXCLUDE_REGEXES})
  file(
    GET_RUNTIME_DEPENDENCIES
    ${binaries}
    RESOLVED_DEPENDENCIES_VAR resolved
    UNRESOLVED_DEPENDENCIES_VAR unresolved
    CONFLICTING_DEPENDENCIES_PREFIX conflict
    PRE_EXCLUDE_REGEXES ${excludes}
    POST_EXCLUDE_REGEXES ${system} ${excludes}
  )
  _cs_deployment_fail_unresolved(
    ${name}
    "${unresolved}"
    "not found from the build tree (a library without the RPATH to find the ones it needs?)"
  )
  if(conflict_FILENAMES)
    set(text "")
    foreach(file_name IN LISTS conflict_FILENAMES)
      list(JOIN conflict_${file_name} ", " paths)
      string(APPEND text "\n  ${file_name}: ${paths}")
    endforeach()
    message(FATAL_ERROR "[cs_deploy_${name}] libraries found in several places:${text}")
  endif()

  set(own "")
  foreach(file IN LISTS arg_LIBRARIES arg_MODULES)
    file(REAL_PATH "${file}" real)
    list(APPEND own "${real}")
  endforeach()
  set(result "")
  foreach(file IN LISTS resolved)
    file(REAL_PATH "${file}" real)
    if(NOT real IN_LIST own)
      list(APPEND result "${file}")
    endif()
  endforeach()
  set(${out} "${result}" PARENT_SCOPE)
endfunction()

# Fail when unresolved (libraries not found) is not empty, with the hint.
function(_cs_deployment_fail_unresolved name unresolved hint)
  if(unresolved)
    list(JOIN unresolved ", " text)
    message(FATAL_ERROR "[cs_deploy_${name}] libraries ${hint}: ${text}")
  endif()
endfunction()

# Fail unless every library the binaries of the deployment in real_prefix need (binaries: the arguments of
# file(GET_RUNTIME_DEPENDENCIES)) is in the deployment, but the libraries of the system and what they need, and the
# excludes.
function(_cs_deployment_check_complete name real_prefix binaries excludes)
  _cs_deployment_system_regexes(system)
  file(
    GET_RUNTIME_DEPENDENCIES
    ${binaries}
    RESOLVED_DEPENDENCIES_VAR resolved
    UNRESOLVED_DEPENDENCIES_VAR unresolved
    CONFLICTING_DEPENDENCIES_PREFIX conflict
    PRE_EXCLUDE_REGEXES ${excludes}
    POST_EXCLUDE_REGEXES ${system} ${excludes}
  )
  _cs_deployment_fail_unresolved(${name} "${unresolved}" "not found from the deployment ${real_prefix} (its RPATH)")
  foreach(file_name IN LISTS conflict_FILENAMES)
    list(APPEND resolved ${conflict_${file_name}})
  endforeach()
  foreach(file IN LISTS resolved)
    file(REAL_PATH "${file}" real)
    cmake_path(IS_PREFIX real_prefix "${real}" NORMALIZE inside)
    if(NOT inside)
      cmake_path(GET file FILENAME file_name)
      message(
        FATAL_ERROR
        "[cs_deploy_${name}] ${file_name} resolves to ${file}, outside the deployment ${real_prefix} and not a library "
        "of the system: not shipped (an absolute RPATH?)"
      )
    endif()
  endforeach()
endfunction()

# Fail when a library the deployment in real_prefix ships (SHIPPED: its libraries) resolves outside it, for a binary of
# the deployment or a library of the system they need (binaries: the arguments of file(GET_RUNTIME_DEPENDENCIES); the
# EXCLUDE_REGEXES ignored). Set out to the libraries of the system they need (and what those need).
function(_cs_deployment_check_shadowed name real_prefix binaries out)
  cmake_parse_arguments(PARSE_ARGV 4 arg "" "" "SHIPPED;EXCLUDE_REGEXES")
  set(excludes ${arg_EXCLUDE_REGEXES})
  set(shipped_names "")
  foreach(file IN LISTS arg_SHIPPED)
    cmake_path(GET file FILENAME file_name)
    list(APPEND shipped_names "${file_name}")
  endforeach()
  file(
    GET_RUNTIME_DEPENDENCIES
    ${binaries}
    RESOLVED_DEPENDENCIES_VAR resolved
    UNRESOLVED_DEPENDENCIES_VAR unresolved
    CONFLICTING_DEPENDENCIES_PREFIX conflict
    PRE_EXCLUDE_REGEXES ${excludes}
    POST_EXCLUDE_REGEXES ${excludes}
  )
  foreach(file_name IN LISTS conflict_FILENAMES)
    list(APPEND resolved ${conflict_${file_name}})
  endforeach()
  _cs_deployment_system_regexes(system)
  set(system_libraries "")
  foreach(file IN LISTS resolved)
    file(REAL_PATH "${file}" real)
    cmake_path(IS_PREFIX real_prefix "${real}" NORMALIZE inside)
    cmake_path(GET file FILENAME file_name)
    if(NOT inside AND file_name IN_LIST shipped_names)
      message(
        FATAL_ERROR
        "[cs_deploy_${name}] ${file_name} resolves to ${file}, outside the deployment ${real_prefix}, which ships it: "
        "a binary does not find the copy of the deployment (its RPATH)"
      )
    endif()
    foreach(regex IN LISTS system)
      if(NOT inside AND file MATCHES "${regex}")
        list(APPEND system_libraries "${file}")
        break()
      endif()
    endforeach()
  endforeach()
  list(REMOVE_DUPLICATES system_libraries)
  set(${out} "${system_libraries}" PARENT_SCOPE)
endfunction()

# Write system-requirements.txt in the deployment in prefix: the libraries of the system it needs (files), each with
# its Debian package, and the apt install line of the packages (without dpkg-query: the libraries only).
function(_cs_deployment_write_report name config prefix files)
  _cs_deployment_packages("${files}" packages)
  set(lines "")
  set(names "")
  foreach(file package IN ZIP_LISTS files packages)
    cmake_path(GET file FILENAME file_name)
    list(APPEND lines "${file_name} ${file} ${package}")
    if(NOT package STREQUAL "-")
      list(APPEND names ${package})
    endif()
  endforeach()
  list(SORT lines)
  list(REMOVE_DUPLICATES names)
  list(SORT names)
  list(JOIN lines "\n" text)
  list(JOIN names " " install)
  set(apt "# Debian packages (dpkg-query not found: unknown)")
  if(names)
    set(apt "apt install ${install}")
  endif()
  file(
    WRITE "${prefix}/system-requirements.txt"
    "# The libraries of the system the deployment ${name} (${config}) needs, not shipped: the machine running it\n"
    "# needs them (the same system release). Install them with:\n"
    "${apt}\n"
    "#\n"
    "# library, path on the build machine, Debian package\n"
    "${text}\n"
  )
endfunction()

# Set out to the Debian package of each file of files (in the same order; - when unknown), from dpkg-query -S: the
# path, its real path, each with and without the leading /usr (merged /usr).
function(_cs_deployment_packages files out)
  find_program(dpkg_query dpkg-query)
  if(dpkg_query AND files)
    set(candidates "")
    foreach(file IN LISTS files)
      file(REAL_PATH "${file}" real)
      foreach(path IN ITEMS "${file}" "${real}")
        string(REGEX REPLACE "^/usr/" "/" without_usr "${path}")
        list(APPEND candidates "${without_usr}" "/usr${without_usr}")
      endforeach()
    endforeach()
    list(REMOVE_DUPLICATES candidates)
    execute_process(COMMAND "${dpkg_query}" -S ${candidates} OUTPUT_VARIABLE output ERROR_QUIET)
    # lines "<package>[:<arch>][, <package>...]: <path>" (and "diversion by ...", skipped)
    string(REGEX MATCHALL "[^\n]+" output_lines "${output}")
    foreach(line IN LISTS output_lines)
      if(NOT line MATCHES "^diversion " AND line MATCHES "^([^:, ]+).*: (/.*)$")
        set("package_of_${CMAKE_MATCH_2}" "${CMAKE_MATCH_1}")
      endif()
    endforeach()
  endif()
  set(result "")
  foreach(file IN LISTS files)
    file(REAL_PATH "${file}" real)
    set(package "-")
    foreach(path IN ITEMS "${file}" "${real}")
      string(REGEX REPLACE "^/usr/" "/" without_usr "${path}")
      foreach(candidate IN ITEMS "${without_usr}" "/usr${without_usr}")
        if(package STREQUAL "-" AND DEFINED "package_of_${candidate}")
          set(package "${package_of_${candidate}}")
        endif()
      endforeach()
    endforeach()
    list(APPEND result "${package}")
  endforeach()
  set(${out} "${result}" PARENT_SCOPE)
endfunction()
