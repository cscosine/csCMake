#.rst:
# csDebug
# -------
#
# Debug messages and printers of csCMake: :command:`cs_debug_message` (shown with
# :variable:`<project>_CSCMAKE_DEBUG`), and two commands to inspect what csCMake did, for when a target, a link or a
# package does not behave as expected: :command:`cs_print_target` and :command:`cs_print_project`.
#
# Commands
# ^^^^^^^^

include_guard(GLOBAL)

#.rst:
# .. command:: cs_debug_message
#
#   Print a debug message of csCMake.
#
#   .. code-block:: cmake
#
#     cs_debug_message(<text>...)
#
#   The arguments are concatenated like message() does (also when they contain ";") and printed as a STATUS message when
#   the debug messages of the current project are enabled.
#
#   ``<text>``
#     The message, its arguments concatenated as :command:`message` does.
#
#   :Reads: :variable:`_cscmake_debug_option`, :variable:`<project>_CSCMAKE_DEBUG`
function(cs_debug_message)
  if(NOT _cscmake_debug_option OR NOT ${_cscmake_debug_option})
    return()
  endif()
  # ARGV<n> one by one: ARGN would split the arguments containing ";"
  set(text "")
  set(index 0)
  while(index LESS ARGC)
    string(APPEND text "${ARGV${index}}")
    math(EXPR index "${index} + 1")
  endwhile()
  message(STATUS "${text}")
endfunction()

# Set out to TRUE when the debug messages of the current project are on (<project>_CSCMAKE_DEBUG).
#
# Reads:
#
# * variable _cscmake_debug_option, <project>_CSCMAKE_DEBUG
function(_cs_debug_enabled out)
  if(_cscmake_debug_option AND ${_cscmake_debug_option})
    set(${out} TRUE PARENT_SCOPE)
  else()
    set(${out} FALSE PARENT_SCOPE)
  endif()
endfunction()

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
#   project it depends on, resolved by :command:`cs_finalize_project`), then every CMake property set on it (each
#   ``<CONFIG>`` property for every configuration of the build, ``<LANG>`` as CXX). Call it after the target is
#   complete, e.g. at the end of the CMakeLists.txt of the project (after :command:`cs_finalize_project` for the
#   dependencies).
#
#   ``<target>``
#     A target (an alias of one is accepted).
function(cs_print_target target_name)
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
#   components (their targets, the packages they find, the components they depend on, resolved by
#   :command:`cs_finalize_project`). With :variable:`<project>_CSCMAKE_DEBUG`, :command:`cs_initialize_project` and
#   :command:`cs_finalize_project` print the same.
function(cs_print_project)
  _cs_print_project("cs_print_project")
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
    "depends on (cs_finalize_project)|CSCMAKE_PROJECT_DEPENDENCIES"
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

# Print the csCMake view of the project (see cs_print_project), with header in the first line.
function(_cs_print_project header)
  _cs_get_root_dir(cscmake_root)
  message(
    STATUS
    "[${header}] project ${CSCMAKE_NAMESPACE} (${PROJECT_NAME} ${PROJECT_VERSION}), csCMake ${cscmake_root}"
  )
  _cs_print_project_configurations()
  message(STATUS "  CMAKE_PREFIX_PATH: ${CMAKE_PREFIX_PATH}")
  message(STATUS "  CMAKE_MODULE_PATH: ${CMAKE_MODULE_PATH}")
  message(STATUS "  CMAKE_INSTALL_PREFIX: ${CMAKE_INSTALL_PREFIX}")
  cs_get_project_targets(targets)
  message(STATUS "  targets: ${targets}")
  _cs_get_components(components)
  _cs_get_default_components(default_components)
  message(STATUS "  components: ${components} (default: ${default_components})")
  foreach(component IN LISTS components)
    _cs_get_component_targets(${component} component_targets)
    _cs_get_component_find_packages(${component} packages)
    _cs_get_component_dependencies_sorted(${component} dependencies)
    message(STATUS "    ${component}: targets ${component_targets}")
    message(STATUS "      finds: ${packages}")
    message(STATUS "      depends on (cs_finalize_project): ${dependencies}")
  endforeach()
endfunction()

# Print the configurations of the build: the generator's, then for each its postfix, C++ flags and MSVC runtime.
function(_cs_print_project_configurations)
  cs_get_build_configurations(configs)
  get_property(multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
  if(multi_config)
    message(STATUS "  configurations: ${configs} (CMAKE_CONFIGURATION_TYPES: ${CMAKE_CONFIGURATION_TYPES})")
  else()
    message(STATUS "  configurations: ${configs} (CMAKE_BUILD_TYPE: ${CMAKE_BUILD_TYPE})")
  endif()
  foreach(config IN LISTS configs)
    string(TOUPPER "${config}" config_ucase)
    message(
      STATUS
      "    ${config}: postfix '${CSCMAKE_${config_ucase}_POSTFIX}', C++ flags '${CMAKE_CXX_FLAGS_${config_ucase}}', "
      "MSVC runtime ${CSCMAKE_MSVC_RUNTIME_LIBRARY_${config_ucase}}"
    )
  endforeach()
endfunction()
