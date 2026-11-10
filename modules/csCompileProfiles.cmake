#.rst:
# csCompileProfiles
# -----------------
#
# Compile profiles: named sets of rules. A rule applies compile options, compile definitions, link options, clang-tidy
# and other profiles (``PROFILES``) under conditions on the build configuration, the compiler, its command-line style
# and the platform. Profiles are applied by :command:`cs_finalize_target`: the default profiles of the project
# (``DEFAULT_COMPILE_PROFILES`` of :command:`cs_initialize_project`) and the ones given to
# :command:`cs_target_use_compile_profiles`. Compile options and definitions are ``PRIVATE``: consumers never get them.
# The link options of static and object libraries are ``INTERFACE`` too: link requirements, e.g. the sanitizer runtime.
#
# The profiles shipped with csCMake (``cscmake_*``): :doc:`csCompileProfilesShipped`.
#
# Commands
# ^^^^^^^^

include_guard(GLOBAL)
include(modules/csDebug)
include(modules/csInternal)

#.rst:
# .. command:: cs_add_compile_profile_rule
#
#   Add a rule to a compile profile (created by its first rule).
#
#   .. code-block:: cmake
#
#     cs_add_compile_profile_rule(PROFILE <name>
#       [CONFIGS <config>...]
#       [COMPILERS <CMAKE_CXX_COMPILER_ID>...]
#       [FRONTENDS GNU|MSVC...]
#       [PLATFORMS <CMAKE_SYSTEM_NAME>...]
#       [COMPILE_OPTIONS <option>...]
#       [COMPILE_DEFINITIONS <definition>...]
#       [LINK_OPTIONS <option>...]
#       [PROFILES <profile>...]
#       [CLANG_TIDY])
#
#   A condition not given matches anything; the conditions of the rule apply to the profiles of PROFILES too. CLANG_TIDY
#   runs clang-tidy (checks from the .clang-tidy of the project): mandatory where the rule matches the build, not run by
#   the Visual Studio and Xcode generators (warning).
#
#   ``PROFILE``
#     Name of the profile.
#
#   ``CONFIGS``, ``COMPILERS``, ``FRONTENDS``, ``PLATFORMS``
#     Conditions (FRONTENDS: command-line style, GNU or MSVC).
#
#   ``COMPILE_OPTIONS``, ``COMPILE_DEFINITIONS``
#     Private to the targets.
#
#   ``LINK_OPTIONS``
#     Private, and interface for static and object libraries.
#
#   ``PROFILES``
#     Other profiles applied under the conditions of the rule.
#
#   ``CLANG_TIDY``
#     Run clang-tidy.
#
#   :Writes: :prop_gbl:`CSCMAKE_COMPILE_PROFILES`, :prop_gbl:`CSCMAKE_COMPILE_PROFILE_<profile>_RULES`,
#     :prop_gbl:`_CSCMAKE_COMPILE_PROFILE_RULE_<rule>_<field>`, :prop_gbl:`_CSCMAKE_COMPILE_PROFILE_RULE_COUNT`
function(cs_add_compile_profile_rule)
  set(options CLANG_TIDY)
  set(onevalue PROFILE)
  set(
    multivalue
    CONFIGS
    COMPILERS
    FRONTENDS
    PLATFORMS
    COMPILE_OPTIONS
    COMPILE_DEFINITIONS
    LINK_OPTIONS
    PROFILES
  )
  cmake_parse_arguments(arg "${options}" "${onevalue}" "${multivalue}" ${ARGN})
  if(arg_UNPARSED_ARGUMENTS OR NOT arg_PROFILE)
    message(
      FATAL_ERROR
      "[cs_add_compile_profile_rule] PROFILE <name> is required, unparsed arguments: "
      "${arg_UNPARSED_ARGUMENTS}"
    )
  endif()

  get_property(rule GLOBAL PROPERTY _CSCMAKE_COMPILE_PROFILE_RULE_COUNT)
  if(NOT rule)
    set(rule 0)
  endif()
  math(EXPR rule "${rule} + 1")
  set_property(GLOBAL PROPERTY _CSCMAKE_COMPILE_PROFILE_RULE_COUNT ${rule})

  foreach(field ${multivalue} CLANG_TIDY)
    set_property(GLOBAL PROPERTY _CSCMAKE_COMPILE_PROFILE_RULE_${rule}_${field} "${arg_${field}}")
  endforeach()
  set_property(GLOBAL APPEND PROPERTY CSCMAKE_COMPILE_PROFILE_${arg_PROFILE}_RULES ${rule})
  _cs_add_to_global_property_unique_value(CSCMAKE_COMPILE_PROFILES ${arg_PROFILE})
endfunction()

#.rst:
# .. command:: cs_target_use_compile_profiles
#
#   Use compile profiles for a target, in addition to the default profiles of the project.
#
#   .. code-block:: cmake
#
#     cs_target_use_compile_profiles(<target> <profile>...)
#
#   Applied by :command:`cs_finalize_target`.
#
#   ``<target>``
#     A target of the project (an alias of one is accepted).
#
#   ``<profile>``
#     Compile profiles (:command:`cs_add_compile_profile_rule`), applied after the default ones.
#
#   :Writes: :prop_tgt:`CSCMAKE_COMPILE_PROFILES`
function(cs_target_use_compile_profiles target_name)
  get_target_property(aliased ${target_name} ALIASED_TARGET)
  if(aliased)
    set(target_name ${aliased})
  endif()
  set_property(TARGET ${target_name} APPEND PROPERTY CSCMAKE_COMPILE_PROFILES ${ARGN})
endfunction()

#.rst:
# .. command:: cs_get_target_compile_profiles
#
#   Return the compile profiles of a target: the default profiles of the project, then its own ones.
#
#   .. code-block:: cmake
#
#     cs_get_target_compile_profiles(<target> <out-var>)
#
#   ``<target>``
#     A target of the project.
#
#   ``<out-var>``
#     The variable to set, in the scope of the caller.
#
#   :Reads: :variable:`CSCMAKE_DEFAULT_COMPILE_PROFILES`, :prop_tgt:`CSCMAKE_COMPILE_PROFILES`
function(cs_get_target_compile_profiles target_name profiles_out)
  set(profiles ${CSCMAKE_DEFAULT_COMPILE_PROFILES})
  get_target_property(own ${target_name} CSCMAKE_COMPILE_PROFILES)
  if(own)
    list(APPEND profiles ${own})
  endif()
  list(REMOVE_DUPLICATES profiles)
  set(${profiles_out} "${profiles}" PARENT_SCOPE)
endfunction()

# Apply the compile profiles of target_name (called by cs_finalize_target); INTERFACE libraries are skipped (nothing to
# compile).
function(_cs_apply_compile_profiles target_name)
  get_target_property(type ${target_name} TYPE)
  if(type STREQUAL "INTERFACE_LIBRARY")
    return()
  endif()
  cs_get_target_compile_profiles(${target_name} profiles)
  cs_debug_message("[_cs_apply_compile_profiles] ${target_name}: ${profiles}")
  foreach(profile ${profiles})
    _cs_apply_compile_profile(${target_name} ${profile} "" TRUE "")
  endforeach()
  _cs_apply_clang_tidy(${target_name})
endfunction()

# Apply the rules of profile to target_name under the generator expression condition ("" = always); static_match is
# FALSE when the conditions above cannot match this build, allowed_configs the configurations they allow ("" = any).
#
# Reads:
#
# * global property CSCMAKE_COMPILE_PROFILE_<profile>_RULES, _CSCMAKE_COMPILE_PROFILE_RULE_<rule>_<field>
#
# Writes:
#
# * target property _CSCMAKE_CLANG_TIDY_CONDITIONS: conditions of the rules running clang-tidy
function(
  _cs_apply_compile_profile
  target_name
  profile
  condition
  static_match
  allowed_configs
)
  get_property(defined GLOBAL PROPERTY CSCMAKE_COMPILE_PROFILE_${profile}_RULES SET)
  if(NOT defined)
    message(
      FATAL_ERROR
      "[cs_finalize_target] compile profile ${profile} of ${target_name} is not defined "
      "(cs_add_compile_profile_rule)"
    )
  endif()
  get_property(rules GLOBAL PROPERTY CSCMAKE_COMPILE_PROFILE_${profile}_RULES)
  foreach(rule ${rules})
    _cs_compile_profile_rule_condition(${rule} rule_condition rule_static_match)
    _cs_genex_and("${condition}" "${rule_condition}" rule_condition)
    if(NOT static_match)
      set(rule_static_match FALSE)
    endif()
    get_property(rule_configs GLOBAL PROPERTY _CSCMAKE_COMPILE_PROFILE_RULE_${rule}_CONFIGS)
    _cs_intersect_configs("${allowed_configs}" "${rule_configs}" rule_configs rule_static_match)

    _cs_apply_compile_profile_rule_options(${target_name} ${rule} "${rule_condition}")
    get_property(clang_tidy GLOBAL PROPERTY _CSCMAKE_COMPILE_PROFILE_RULE_${rule}_CLANG_TIDY)
    if(clang_tidy AND rule_static_match)
      _cs_genex_or_term("${rule_condition}" term)
      set_property(TARGET ${target_name} APPEND PROPERTY _CSCMAKE_CLANG_TIDY_CONDITIONS "${term}")
    endif()

    get_property(nested GLOBAL PROPERTY _CSCMAKE_COMPILE_PROFILE_RULE_${rule}_PROFILES)
    foreach(nested_profile ${nested})
      _cs_apply_compile_profile(${target_name} ${nested_profile} "${rule_condition}" ${rule_static_match}
                                "${rule_configs}"
      )
    endforeach()
  endforeach()
endfunction()

# Add the compile options, definitions and link options of rule to target_name under condition; the link options of a
# static or object library are also INTERFACE (link requirements, e.g. the sanitizer runtime).
function(_cs_apply_compile_profile_rule_options target_name rule condition)
  foreach(field COMPILE_OPTIONS COMPILE_DEFINITIONS LINK_OPTIONS)
    get_property(values GLOBAL PROPERTY _CSCMAKE_COMPILE_PROFILE_RULE_${rule}_${field})
    if(NOT values)
      continue()
    endif()
    if(condition)
      set(values "$<${condition}:${values}>")
    endif()
    if(field STREQUAL "COMPILE_OPTIONS")
      target_compile_options(${target_name} PRIVATE "${values}")
    elseif(field STREQUAL "COMPILE_DEFINITIONS")
      target_compile_definitions(${target_name} PRIVATE "${values}")
    else()
      target_link_options(${target_name} PRIVATE "${values}")
      get_target_property(type ${target_name} TYPE)
      if(type STREQUAL "STATIC_LIBRARY" OR type STREQUAL "OBJECT_LIBRARY")
        target_link_options(${target_name} INTERFACE "${values}")
      endif()
    endif()
  endforeach()
endfunction()

# Return in condition_out the generator expression condition of rule ("" = always) and in static_match_out whether its
# compiler, frontend and platform conditions match this build.
function(_cs_compile_profile_rule_condition rule condition_out static_match_out)
  set(terms "")
  set(static_match TRUE)
  # condition field, generator expression, configure-time value
  foreach(
    spec
    "CONFIGS;CONFIG"
    "COMPILERS;CXX_COMPILER_ID;${CMAKE_CXX_COMPILER_ID}"
    "PLATFORMS;PLATFORM_ID;${CMAKE_SYSTEM_NAME}"
  )
    list(GET spec 0 field)
    list(GET spec 1 genex)
    list(LENGTH spec spec_size)
    get_property(values GLOBAL PROPERTY _CSCMAKE_COMPILE_PROFILE_RULE_${rule}_${field})
    if(values)
      list(JOIN values "," joined)
      list(APPEND terms "$<${genex}:${joined}>")
      if(spec_size EQUAL 3)
        list(GET spec 2 current)
        if(NOT current IN_LIST values)
          set(static_match FALSE)
        endif()
      endif()
    endif()
  endforeach()
  get_property(frontends GLOBAL PROPERTY _CSCMAKE_COMPILE_PROFILE_RULE_${rule}_FRONTENDS)
  if(frontends)
    set(frontend_terms "")
    foreach(frontend ${frontends})
      list(APPEND frontend_terms "$<CXX_COMPILER_FRONTEND_VARIANT:${frontend}>")
    endforeach()
    list(JOIN frontend_terms "," frontend_terms)
    list(APPEND terms "$<OR:${frontend_terms}>")
    if(NOT CMAKE_CXX_COMPILER_FRONTEND_VARIANT IN_LIST frontends)
      set(static_match FALSE)
    endif()
  endif()
  _cs_genex_and_list("${terms}" condition)
  set(${condition_out} "${condition}" PARENT_SCOPE)
  set(${static_match_out} ${static_match} PARENT_SCOPE)
endfunction()

# Return in configs_out the configurations allowed by both lists ("" = any); set the caller's static_match_var to FALSE
# when none of them is a configuration of this build.
function(_cs_intersect_configs allowed rule_configs configs_out static_match_var)
  if(NOT allowed)
    set(configs "${rule_configs}")
  elseif(NOT rule_configs)
    set(configs "${allowed}")
  else()
    set(configs "")
    foreach(config ${rule_configs})
      if(config IN_LIST allowed)
        list(APPEND configs ${config})
      endif()
    endforeach()
    if(NOT configs)
      set(${static_match_var} FALSE PARENT_SCOPE)
    endif()
  endif()
  if(configs)
    get_property(multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
    if(multi_config)
      set(build_configs ${CMAKE_CONFIGURATION_TYPES})
    else()
      set(build_configs ${CMAKE_BUILD_TYPE})
    endif()
    set(in_build FALSE)
    foreach(config ${configs})
      if(config IN_LIST build_configs)
        set(in_build TRUE)
      endif()
    endforeach()
    if(NOT in_build)
      set(${static_match_var} FALSE PARENT_SCOPE)
    endif()
  endif()
  set(${configs_out} "${configs}" PARENT_SCOPE)
endfunction()

# Set CXX_CLANG_TIDY of target_name when a rule of its profiles runs clang-tidy in this build (clang-tidy then
# required); the Visual Studio and Xcode generators do not run it (one warning per build).
#
# Reads:
#
# * target property _CSCMAKE_CLANG_TIDY_CONDITIONS
# * cache variable CLANG_TIDY_EXE: the clang-tidy executable (find_program)
#
# Writes:
#
# * target property CXX_CLANG_TIDY
# * global property _CSCMAKE_CLANG_TIDY_GENERATOR_WARNED
function(_cs_apply_clang_tidy target_name)
  get_target_property(terms ${target_name} _CSCMAKE_CLANG_TIDY_CONDITIONS)
  if(NOT terms)
    return()
  endif()
  if(CMAKE_GENERATOR MATCHES "^(Visual Studio|Xcode)")
    get_property(warned GLOBAL PROPERTY _CSCMAKE_CLANG_TIDY_GENERATOR_WARNED)
    if(NOT warned)
      message(WARNING "[csCMake] clang-tidy (compile profiles) is not run with the ${CMAKE_GENERATOR} generator")
      set_property(GLOBAL PROPERTY _CSCMAKE_CLANG_TIDY_GENERATOR_WARNED TRUE)
    endif()
    return()
  endif()
  find_program(CLANG_TIDY_EXE NAMES clang-tidy)
  if(NOT CLANG_TIDY_EXE OR NOT EXISTS "${CLANG_TIDY_EXE}")
    message(
      FATAL_ERROR
      "[cs_finalize_target] clang-tidy is required: the compile profiles of ${target_name} run it in "
      "this build (install it, or set CLANG_TIDY_EXE)"
    )
  endif()
  list(JOIN terms "," joined)
  set_property(TARGET ${target_name} PROPERTY CXX_CLANG_TIDY "$<$<OR:${joined}>:${CLANG_TIDY_EXE}>")
endfunction()

# Return in out the conjunction of the two generator expression conditions ("" = always).
function(_cs_genex_and first_condition second_condition out)
  set(terms "")
  foreach(term "${first_condition}" "${second_condition}")
    if(term)
      list(APPEND terms "${term}")
    endif()
  endforeach()
  _cs_genex_and_list("${terms}" condition)
  set(${out} "${condition}" PARENT_SCOPE)
endfunction()

# Return in out the conjunction of the generator expression conditions of the list terms ("" when empty).
function(_cs_genex_and_list terms out)
  list(LENGTH terms count)
  if(count EQUAL 0)
    set(condition "")
  elseif(count EQUAL 1)
    set(condition "${terms}")
  else()
    list(JOIN terms "," joined)
    set(condition "$<AND:${joined}>")
  endif()
  set(${out} "${condition}" PARENT_SCOPE)
endfunction()

# Return in out the condition as a term of $<OR:...>: "1" for an empty condition (always).
function(_cs_genex_or_term condition out)
  if(condition)
    set(${out} "${condition}" PARENT_SCOPE)
  else()
    set(${out} "1" PARENT_SCOPE)
  endif()
endfunction()

#.rst:
# Variables
# ^^^^^^^^^
#
# .. variable:: CLANG_TIDY_EXE
#
#   Cache variable: the clang-tidy executable (``find_program``), when a compile profile runs clang-tidy.
#
# Target properties
# ^^^^^^^^^^^^^^^^^
#
# .. prop_tgt:: CSCMAKE_COMPILE_PROFILES
#
#   The compile profiles of the target, in addition to the default ones (:command:`cs_target_use_compile_profiles`).
#
# .. prop_tgt:: _CSCMAKE_CLANG_TIDY_CONDITIONS
#
#   Internal: the conditions of the rules running clang-tidy on the target.
#
# Global properties
# ^^^^^^^^^^^^^^^^^
#
# .. prop_gbl:: CSCMAKE_COMPILE_PROFILES
#
#   The compile profiles defined in the build.
#
# .. prop_gbl:: CSCMAKE_COMPILE_PROFILE_<profile>_RULES
#
#   The rules of a profile (rule numbers).
#
# .. prop_gbl:: _CSCMAKE_COMPILE_PROFILE_RULE_<rule>_<field>
#
#   Internal: a field of a rule (``CONFIGS``, ``COMPILE_OPTIONS``, ...).
#
# .. prop_gbl:: _CSCMAKE_COMPILE_PROFILE_RULE_COUNT
#
#   Internal: the number of rules.
#
# .. prop_gbl:: _CSCMAKE_CLANG_TIDY_GENERATOR_WARNED
#
#   Internal: the warning about clang-tidy with the Visual Studio and Xcode generators was printed.
