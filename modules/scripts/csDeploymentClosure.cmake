# Ship the shared libraries of other packages a deployment needs, check the deployment and, on Linux, write what it
# needs from the system (csDeployment.cmake; Linux, Windows, macOS). Included by the install rule of the component
# cs_deploy_<name>, after the binaries and the plugins of the project: runs in the install script, CMAKE_INSTALL_PREFIX
# is the folder of the deployment.
#
# 1. The closure: file(GET_RUNTIME_DEPENDENCIES) on the build-tree binaries, without the libraries of the system (nor
#    what they need), the EXCLUDE_REGEXES and the binaries of the project (installed by the rules before). Linux and
#    macOS: found through the build RPATH of the binaries (the packages of the workspace before the system folders);
#    Windows: in the folder of each DLL, then in the DIRECTORIES (the folders of the DLLs of the targets, and the
#    DIRECTORIES of the deployment). Copied unchanged (their RPATH, e.g. $ORIGIN, @loader_path) with their symlink chain
#    to the library folder of the deployment (bin/ on Windows, next to the executables); a macOS framework: its folder,
#    without its headers. A library not found, or found twice, fails.
# 2. The check, on the deployed binaries, with no search folder but their own RPATH and the system ones (Windows: the
#    folder of the executables too, where Windows looks for the DLLs of a plugin):
#    * not shadowed: every library the deployment ships resolves to its copy in the deployment, never to another one of
#      the same name (e.g. the Qt of the system); never a debug C runtime of MSVC (not redistributable);
#    * complete: every library they need, but the ones of the system (and what those need), is in the deployment.
# 3. Linux: the report, system-requirements.txt in the deployment, the libraries of the system it needs, with their
#    Debian packages (dpkg-query, when there) and the apt install line.
#
# The install script sets no policies: the ones of csCMake here (include() scopes them to this file, and the functions
# keep them where they are called).
cmake_policy(VERSION 3.31)

# Set pre_out to the regular expressions of the names of the libraries of the system (matched on the name in the
# depending file: lowercase on Windows) and post_out to the ones of their paths, on platform (Linux, Windows, Darwin):
# never shipped, nor what they need. macOS: by name too (the libraries of the system are not files, in the shared cache
# of dyld).
function(_cs_deployment_system_regexes platform pre_out post_out)
  if(platform STREQUAL "Windows")
    set(pre "^api-ms-" "^ext-ms-")
    set(post "^[A-Za-z]:[/\\\\][Ww][Ii][Nn][Dd][Oo][Ww][Ss][/\\\\]")
  elseif(platform STREQUAL "Darwin")
    set(pre "^/usr/lib/" "^/System/" "^/Library/Apple/")
    set(post ${pre})
  else()
    set(pre "")
    set(
      post
      "^/lib/"
      "^/lib32/"
      "^/lib64/"
      "^/libx32/"
      "^/usr/lib/"
      "^/usr/lib32/"
      "^/usr/lib64/"
      "^/usr/libx32/"
    )
  endif()
  set(${pre_out} "${pre}" PARENT_SCOPE)
  set(${post_out} "${post}" PARENT_SCOPE)
endfunction()

# Make the deployment name in the configuration config: ship the closure, check the deployment, write the report.
#
# Arguments: NAME, CONFIG, PLATFORM (Linux, Windows, Darwin), LIBDIR (the folder of the shipped libraries in the
# deployment, relative: bin on Windows), BUILD_EXECUTABLES / BUILD_LIBRARIES / BUILD_MODULES (the binaries of the
# project, in the build tree), EXECUTABLES / LIBRARIES / MODULES (the same, in the deployment, relative), BINDIR (the
# folder of the executables, relative), DIRECTORIES (Windows: the folders of the DLLs), EXCLUDE_REGEXES (never shipped).
function(_cs_deployment_closure)
  cmake_parse_arguments(
    PARSE_ARGV 0
    arg
    ""
    "NAME;CONFIG;PLATFORM;LIBDIR;BINDIR"
    "BUILD_EXECUTABLES;BUILD_LIBRARIES;BUILD_MODULES;EXECUTABLES;LIBRARIES;MODULES;DIRECTORIES;EXCLUDE_REGEXES"
  )
  set(prefix "${CMAKE_INSTALL_PREFIX}")
  _cs_deployment_collect(
    ${arg_NAME} externals
    PLATFORM ${arg_PLATFORM}
    EXECUTABLES ${arg_BUILD_EXECUTABLES}
    LIBRARIES ${arg_BUILD_LIBRARIES}
    MODULES ${arg_BUILD_MODULES}
    DIRECTORIES ${arg_DIRECTORIES}
    EXCLUDE_REGEXES ${arg_EXCLUDE_REGEXES}
  )
  _cs_deployment_ship("${prefix}/${arg_LIBDIR}" "${externals}" shipped)
  list(LENGTH externals count)
  message(STATUS "[cs_deploy_${arg_NAME}] ${arg_CONFIG}: ${count} libraries of other packages shipped")

  list(TRANSFORM arg_EXECUTABLES PREPEND "${prefix}/")
  list(TRANSFORM arg_LIBRARIES PREPEND "${prefix}/")
  list(TRANSFORM arg_MODULES PREPEND "${prefix}/")
  list(APPEND arg_LIBRARIES ${shipped})
  _cs_deployment_binaries_args("${arg_EXECUTABLES}" "${arg_LIBRARIES}" "${arg_MODULES}" binaries)
  # Windows: the DLLs of a plugin (in its own folder) are found in the folder of the executable
  set(search "")
  if(arg_PLATFORM STREQUAL "Windows")
    set(search DIRECTORIES "${prefix}/${arg_BINDIR}")
  endif()
  file(REAL_PATH "${prefix}" real_prefix)
  _cs_deployment_check_shadowed(
    ${arg_NAME} "${real_prefix}" "${binaries};${search}" system_libraries
    PLATFORM ${arg_PLATFORM}
    SHIPPED ${arg_LIBRARIES} ${arg_MODULES}
    EXCLUDE_REGEXES ${arg_EXCLUDE_REGEXES}
  )
  _cs_deployment_check_complete(
    ${arg_NAME} "${real_prefix}" "${binaries};${search}"
    PLATFORM ${arg_PLATFORM}
    EXCLUDE_REGEXES ${arg_EXCLUDE_REGEXES}
  )
  message(
    STATUS
    "[cs_deploy_${arg_NAME}] ${arg_CONFIG}: checked, every library resolves in the deployment or the system"
  )
  if(arg_PLATFORM STREQUAL "Linux")
    _cs_deployment_write_report(${arg_NAME} ${arg_CONFIG} "${prefix}" "${system_libraries}")
  endif()
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

# Copy the libraries files to the folder destination, as they are, with their symlink chain; a library of a macOS
# framework: the folder of the framework, without its headers. Set out to the shipped libraries (their files in
# destination).
function(_cs_deployment_ship destination files out)
  set(result "")
  set(frameworks "")
  foreach(file IN LISTS files)
    if(file MATCHES "^(.*/([^/]+\\.framework))/(.*)$")
      set(framework "${CMAKE_MATCH_1}")
      list(APPEND result "${destination}/${CMAKE_MATCH_2}/${CMAKE_MATCH_3}")
      if(NOT framework IN_LIST frameworks)
        list(APPEND frameworks "${framework}")
        file(INSTALL "${framework}" DESTINATION "${destination}" USE_SOURCE_PERMISSIONS PATTERN "Headers" EXCLUDE)
      endif()
    else()
      cmake_path(GET file FILENAME file_name)
      list(APPEND result "${destination}/${file_name}")
      file(INSTALL "${file}" DESTINATION "${destination}" USE_SOURCE_PERMISSIONS FOLLOW_SYMLINK_CHAIN)
    endif()
  endforeach()
  set(${out} "${result}" PARENT_SCOPE)
endfunction()

# Set out to the libraries the binaries (EXECUTABLES, LIBRARIES, MODULES, in the build tree) need, resolved from the
# build tree (Windows: and the DIRECTORIES), but the libraries of the system of PLATFORM (and what they need), the
# EXCLUDE_REGEXES and the binaries of the project; fail when one is not found or found twice.
function(_cs_deployment_collect name out)
  cmake_parse_arguments(PARSE_ARGV 2 arg "" "PLATFORM" "EXECUTABLES;LIBRARIES;MODULES;DIRECTORIES;EXCLUDE_REGEXES")
  _cs_deployment_binaries_args("${arg_EXECUTABLES}" "${arg_LIBRARIES}" "${arg_MODULES}" binaries)
  _cs_deployment_system_regexes(${arg_PLATFORM} system_pre system_post)
  set(excludes ${arg_EXCLUDE_REGEXES})
  set(search "")
  if(arg_DIRECTORIES)
    set(search DIRECTORIES ${arg_DIRECTORIES})
  endif()
  file(
    GET_RUNTIME_DEPENDENCIES
    ${binaries}
    ${search}
    RESOLVED_DEPENDENCIES_VAR resolved
    UNRESOLVED_DEPENDENCIES_VAR unresolved
    CONFLICTING_DEPENDENCIES_PREFIX conflict
    PRE_EXCLUDE_REGEXES ${system_pre} ${excludes}
    POST_EXCLUDE_REGEXES ${system_post} ${excludes}
  )
  _cs_deployment_fail_unresolved(
    ${name}
    "${unresolved}"
    "not found from the build tree (Linux, macOS: a library without the RPATH to find the ones it needs? Windows: "
    "cs_deployment DIRECTORIES?)"
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

# Fail when unresolved (libraries not found) is not empty, with the hint (its parts joined).
function(_cs_deployment_fail_unresolved name unresolved hint)
  if(unresolved)
    list(JOIN unresolved ", " text)
    string(CONCAT hint ${hint} ${ARGN})
    message(FATAL_ERROR "[cs_deploy_${name}] libraries ${hint}: ${text}")
  endif()
endfunction()

# Set out to whether file is in the deployment in real_prefix (its real path; Windows: ignoring the case).
function(_cs_deployment_inside real_prefix file platform out)
  file(REAL_PATH "${file}" real)
  if(platform STREQUAL "Windows")
    string(TOLOWER "${real}" real)
    string(TOLOWER "${real_prefix}" real_prefix)
  endif()
  cmake_path(IS_PREFIX real_prefix "${real}" NORMALIZE inside)
  set(${out} ${inside} PARENT_SCOPE)
endfunction()

# Fail unless every library the binaries of the deployment in real_prefix need (binaries: the arguments of
# file(GET_RUNTIME_DEPENDENCIES)) is in the deployment, but the libraries of the system of PLATFORM and what they need,
# and the EXCLUDE_REGEXES.
function(_cs_deployment_check_complete name real_prefix binaries)
  cmake_parse_arguments(PARSE_ARGV 3 arg "" "PLATFORM" "EXCLUDE_REGEXES")
  _cs_deployment_system_regexes(${arg_PLATFORM} system_pre system_post)
  file(
    GET_RUNTIME_DEPENDENCIES
    ${binaries}
    RESOLVED_DEPENDENCIES_VAR resolved
    UNRESOLVED_DEPENDENCIES_VAR unresolved
    CONFLICTING_DEPENDENCIES_PREFIX conflict
    PRE_EXCLUDE_REGEXES ${system_pre} ${arg_EXCLUDE_REGEXES}
    POST_EXCLUDE_REGEXES ${system_post} ${arg_EXCLUDE_REGEXES}
  )
  _cs_deployment_fail_unresolved(${name} "${unresolved}" "not found from the deployment ${real_prefix} (its RPATH)")
  foreach(file_name IN LISTS conflict_FILENAMES)
    list(APPEND resolved ${conflict_${file_name}})
  endforeach()
  foreach(file IN LISTS resolved)
    _cs_deployment_inside("${real_prefix}" "${file}" ${arg_PLATFORM} inside)
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
# EXCLUDE_REGEXES ignored), or when one is a debug C runtime of MSVC. Set out to the libraries of the system of PLATFORM
# they need (and what those need; macOS: none, excluded by name).
function(_cs_deployment_check_shadowed name real_prefix binaries out)
  cmake_parse_arguments(PARSE_ARGV 4 arg "" "PLATFORM" "SHIPPED;EXCLUDE_REGEXES")
  set(shipped_names "")
  foreach(file IN LISTS arg_SHIPPED)
    cmake_path(GET file FILENAME file_name)
    string(TOLOWER "${file_name}" file_name)
    list(APPEND shipped_names "${file_name}")
  endforeach()
  # macOS: the libraries of the system are not files, excluded by name; Linux and Windows: looked into
  _cs_deployment_system_regexes(${arg_PLATFORM} system_pre system_post)
  file(
    GET_RUNTIME_DEPENDENCIES
    ${binaries}
    RESOLVED_DEPENDENCIES_VAR resolved
    UNRESOLVED_DEPENDENCIES_VAR unresolved
    CONFLICTING_DEPENDENCIES_PREFIX conflict
    PRE_EXCLUDE_REGEXES ${system_pre} ${arg_EXCLUDE_REGEXES}
    POST_EXCLUDE_REGEXES ${arg_EXCLUDE_REGEXES}
  )
  foreach(file_name IN LISTS conflict_FILENAMES)
    list(APPEND resolved ${conflict_${file_name}})
  endforeach()
  set(system_libraries "")
  foreach(file IN LISTS resolved)
    _cs_deployment_inside("${real_prefix}" "${file}" ${arg_PLATFORM} inside)
    cmake_path(GET file FILENAME file_name)
    string(TOLOWER "${file_name}" lower_name)
    # e.g. vcruntime140d.dll, vcruntime140_1d.dll, msvcp140d.dll, msvcp140d_atomic_wait.dll, ucrtbased.dll
    if(lower_name MATCHES "^((vcruntime|msvcp|concrt|vccorlib|vcomp)[0-9]+(_[0-9])?d(_[0-9a-z_]+)?|ucrtbased)\\.dll$")
      message(
        FATAL_ERROR
        "[cs_deploy_${name}] ${file_name}: a debug C runtime of MSVC, not redistributable (a configuration using the "
        "debug runtime library, e.g. Debug: deploy a release configuration, e.g. Release or RelWithDebInfo)"
      )
    endif()
    if(NOT inside AND lower_name IN_LIST shipped_names)
      message(
        FATAL_ERROR
        "[cs_deploy_${name}] ${file_name} resolves to ${file}, outside the deployment ${real_prefix}, which ships it: "
        "a binary does not find the copy of the deployment (its RPATH)"
      )
    endif()
    foreach(regex IN LISTS system_post)
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
