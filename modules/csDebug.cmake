#.rst:
# csDebug
# -------
#
# What csCMake says, and two commands to inspect what it did, for when a target, a link or a package does not behave as
# expected: :command:`cs_print_target` and :command:`cs_print_project`.
#
# csCMake writes its messages with CMake's log levels: ``VERBOSE`` what it does, one line per thing (the project, each
# target, package, component, the finalization); ``DEBUG`` the details (arguments, configuration mapping, run-time
# environment, the whole project at the finalization). They are shown with ``cmake --log-level=VERBOSE`` (or
# ``DEBUG``) for the whole build, or with :variable:`CMAKE_MESSAGE_LOG_LEVEL` set in a folder or in a ``block()``
# around some calls (``--log-level`` wins over it). Each command adds the namespace of the project and its own name to
# :variable:`CMAKE_MESSAGE_CONTEXT` (``--log-context`` prints ``[myLib.cs_add_library]``), and indents its sub-steps.
#
# Commands
# ^^^^^^^^

include_guard(GLOBAL)

# Set out to TRUE when the messages of level (VERBOSE, DEBUG, ...) are shown in the current scope (--log-level, or
# CMAKE_MESSAGE_LOG_LEVEL): the work done only for a message is skipped otherwise.
function(_cs_log_level_at_least level out)
  cmake_language(GET_MESSAGE_LOG_LEVEL current)
  set(
    levels
    ERROR
    WARNING
    NOTICE
    STATUS
    VERBOSE
    DEBUG
    TRACE
  )
  list(FIND levels "${level}" wanted)
  list(FIND levels "${current}" shown)
  if(shown GREATER_EQUAL wanted)
    set(${out} TRUE PARENT_SCOPE)
  else()
    set(${out} FALSE PARENT_SCOPE)
  endif()
endfunction()

# Add the namespace of the project (once) and command to the message context of the calling function
# (CMAKE_MESSAGE_CONTEXT, printed by --log-context; restored when the function returns). A macro: it sets the variable
# of the caller, so only for functions (in a macro it would reach the scope of the project).
macro(_cs_message_context command)
  if(NOT "${CSCMAKE_NAMESPACE}" STREQUAL "" AND NOT "${CSCMAKE_NAMESPACE}" IN_LIST CMAKE_MESSAGE_CONTEXT)
    list(APPEND CMAKE_MESSAGE_CONTEXT "${CSCMAKE_NAMESPACE}")
  endif()
  list(APPEND CMAKE_MESSAGE_CONTEXT ${command})
endmacro()

#.rst:
# .. command:: cs_print_target
#
#   Print what csCMake knows about a target, then its CMake properties: when a target does not build, link, install or
#   run as expected.
#
#   .. code-block:: cmake
#
#     cs_print_target(<target>)
#
#   Always printed (``STATUS`` messages), wherever it is called: the csCMake view (type, component, headers to
#   install, the packages it finds for its consumers, compile profiles, run-time environment, the targets of the
#   project it depends on, resolved when the project is finalized), then every CMake property set on it (each
#   ``<CONFIG>`` property for every configuration of the build, ``<LANG>`` as CXX). Called in a project not finalized
#   yet, it prints at the end of the ``CMakeLists.txt`` of :command:`cs_initialize_project`, after the finalization:
#   the target as built, wherever the call is.
#
#   ``<target>``
#     A target (an alias of one is accepted).
function(cs_print_target target_name)
  _cs_print_after_finalize(deferred cs_print_target "${target_name}")
  if(deferred)
    return()
  endif()
  if(NOT TARGET "${target_name}")
    message(STATUS "[cs_print_target] ${target_name} is not a target")
    return()
  endif()
  get_target_property(aliased "${target_name}" ALIASED_TARGET)
  if(aliased)
    set(target_name "${aliased}")
  endif()
  _cs_print_target_cscmake_view(${target_name})
  _cs_print_target_properties(${target_name})
endfunction()

#.rst:
# .. command:: cs_print_project
#
#   Print what csCMake knows about the project: when the configurations, the search paths, the targets or the
#   components are not the expected ones.
#
#   .. code-block:: cmake
#
#     cs_print_project()
#
#   Always printed (``STATUS`` messages): the namespace and version, the folder of csCMake, the configurations (postfix,
#   C++ flags, MSVC runtime of each), the search paths and the install prefix, the targets of the project, the
#   components (their targets, the packages they find, the components they depend on, resolved when the project is
#   finalized). Called in a project not finalized yet, it prints after the finalization, as :command:`cs_print_target`.
#   With the ``DEBUG`` log level, the finalization prints the same.
function(cs_print_project)
  _cs_print_after_finalize(deferred cs_print_project)
  if(deferred)
    return()
  endif()
  _cs_print_project(STATUS "cs_print_project")
endfunction()

# Defer the call command(args) to the end of the CMakeLists.txt of the current project (after its finalization, deferred
# earlier by cs_initialize_project) when the project is not finalized yet; deferred_out is TRUE then.
#
# Reads:
#
# * variable CSCMAKE_NAMESPACE, CSCMAKE_SOURCE_DIR
# * global property _CSCMAKE_PROJECT_FINALIZED_<namespace>
function(_cs_print_after_finalize deferred_out command)
  set(${deferred_out} FALSE PARENT_SCOPE)
  if("${CSCMAKE_NAMESPACE}" STREQUAL "")
    return()
  endif()
  get_property(finalized GLOBAL PROPERTY _CSCMAKE_PROJECT_FINALIZED_${CSCMAKE_NAMESPACE})
  if(finalized)
    return()
  endif()
  set(arguments "")
  foreach(argument IN LISTS ARGN)
    string(APPEND arguments " [==[${argument}]==]")
  endforeach()
  cmake_language(EVAL CODE "cmake_language(DEFER DIRECTORY [==[${CSCMAKE_SOURCE_DIR}]==] CALL ${command}${arguments})")
  set(${deferred_out} TRUE PARENT_SCOPE)
endfunction()

# Print the csCMake view of target_name (see cs_print_target).
function(_cs_print_target_cscmake_view target_name)
  get_target_property(type ${target_name} TYPE)
  get_property(namespace TARGET ${target_name} PROPERTY CSCMAKE_NAMESPACE)
  message(STATUS "[cs_print_target] ${target_name}: ${type}, project ${namespace}")
  foreach(
    entry
    "component|CSCMAKE_COMPONENT"
    "headers to install|CSCMAKE_SOURCES_TO_INSTALL"
    "headers to install (absolute paths)|CSCMAKE_SOURCES_TO_INSTALL_ABSOLUTE"
    "packages found for its consumers|CSCMAKE_FIND_PACKAGES"
    "compile profiles (own)|CSCMAKE_COMPILE_PROFILES"
    "run-time PATH folders|CSCMAKE_RUNTIME_DIRS"
    "run-time variables|CSCMAKE_RUNTIME_ENVIRONMENT"
    "depends on|CSCMAKE_PROJECT_DEPENDENCIES"
  )
    string(REPLACE "|" ";" entry "${entry}")
    list(GET entry 0 label)
    list(GET entry 1 property)
    get_property(value TARGET ${target_name} PROPERTY ${property})
    if(NOT "${value}" STREQUAL "")
      message(STATUS "  ${label}: ${value}")
    endif()
  endforeach()
  _cs_get_target_compile_profiles(${target_name} profiles)
  message(STATUS "  compile profiles (with the defaults): ${profiles}")
endfunction()

# Print every CMake property set on target_name (cmake --help-property-list), each <CONFIG> property for every
# configuration of the build, <LANG> as CXX.
function(_cs_print_target_properties target_name)
  # every property that cmake supports, as a CMake list
  execute_process(COMMAND ${CMAKE_COMMAND} --help-property-list OUTPUT_VARIABLE property_list)
  string(REGEX REPLACE ";" "\\\;" property_list "${property_list}")
  string(REGEX REPLACE "\n" ";" property_list "${property_list}")

  # LOCATION* properties cannot be read any more
  list(FILTER property_list EXCLUDE REGEX "^LOCATION$|^LOCATION_|_LOCATION$")

  # expand the placeholders
  cs_get_build_configurations(configs_list)
  set(expanded_list "")
  foreach(prop ${property_list})
    string(REPLACE "<LANG>" "CXX" prop "${prop}")
    if(prop MATCHES "<CONFIG>")
      foreach(config ${configs_list})
        string(TOUPPER "${config}" config_ucase)
        string(REPLACE "<CONFIG>" "${config_ucase}" prop_of_config "${prop}")
        list(APPEND expanded_list "${prop_of_config}")
      endforeach()
    else()
      list(APPEND expanded_list "${prop}")
    endif()
  endforeach()
  list(REMOVE_DUPLICATES expanded_list)

  message(STATUS "  CMake properties:")
  foreach(prop ${expanded_list})
    get_property(is_set TARGET ${target_name} PROPERTY ${prop} SET)
    if(is_set)
      get_target_property(propval ${target_name} ${prop})
      message(STATUS "    ${prop} = ${propval}")
    endif()
  endforeach()
endfunction()

# Print the csCMake view of the project (see cs_print_project) at level (STATUS, DEBUG, ...), with header in the first
# line.
function(_cs_print_project level header)
  _cs_get_root_dir(cscmake_root)
  message(
    ${level}
    "[${header}] project ${CSCMAKE_NAMESPACE} (${PROJECT_NAME} ${PROJECT_VERSION}), csCMake ${cscmake_root}"
  )
  _cs_print_project_configurations(${level})
  message(${level} "  CMAKE_PREFIX_PATH: ${CMAKE_PREFIX_PATH}")
  message(${level} "  CMAKE_MODULE_PATH: ${CMAKE_MODULE_PATH}")
  message(${level} "  CMAKE_INSTALL_PREFIX: ${CMAKE_INSTALL_PREFIX}")
  cs_get_project_targets(targets)
  message(${level} "  targets: ${targets}")
  _cs_get_components(components)
  _cs_get_default_components(default_components)
  message(${level} "  components: ${components} (default: ${default_components})")
  foreach(component IN LISTS components)
    _cs_get_component_targets(${component} component_targets)
    _cs_get_component_find_packages(${component} packages)
    _cs_get_component_dependencies_sorted(${component} dependencies)
    message(${level} "    ${component}: targets ${component_targets}")
    message(${level} "      finds: ${packages}")
    message(${level} "      depends on: ${dependencies}")
  endforeach()
endfunction()

# Print at level the configurations of the build: the generator's, then for each its postfix, C++ flags and MSVC
# runtime.
function(_cs_print_project_configurations level)
  cs_get_build_configurations(configs)
  get_property(multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
  if(multi_config)
    message(${level} "  configurations: ${configs} (CMAKE_CONFIGURATION_TYPES: ${CMAKE_CONFIGURATION_TYPES})")
  else()
    message(${level} "  configurations: ${configs} (CMAKE_BUILD_TYPE: ${CMAKE_BUILD_TYPE})")
  endif()
  foreach(config IN LISTS configs)
    string(TOUPPER "${config}" config_ucase)
    message(
      ${level}
      "    ${config}: postfix '${CSCMAKE_${config_ucase}_POSTFIX}', C++ flags '${CMAKE_CXX_FLAGS_${config_ucase}}', "
      "MSVC runtime ${CSCMAKE_MSVC_RUNTIME_LIBRARY_${config_ucase}}"
    )
  endforeach()
endfunction()
