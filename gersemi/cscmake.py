"""gersemi extension: the signatures of the csCMake commands, so that gersemi lays out their keyword arguments.

Used by csCMake (``.gersemirc``) and by the projects using csCMake (``extensions: [<csCMake>/gersemi/cscmake.py]``, see
``docs/user/formatting.md``). A new or changed public ``cs_*`` command updates its entry here.
"""

_TARGET_SCOPES = ["PUBLIC", "PRIVATE", "INTERFACE"]

command_definitions = {
    "cs_initialize_project": {
        "one_value_keywords": [
            "NAMESPACE",
            "CXX_STANDARD",
            "DEFAULT_CONFIG_MAPPED",
            "MAPPED_TO",
            "CUSTOM_CONFIG",
            "BASED_ON",
            "POSTFIX",
            "INSTALL_RPATH",
            "VERSION_COMPATIBILITY",
        ],
        "multi_value_keywords": ["DEFAULT_CONFIG", "DEFAULT_COMPILE_PROFILES"],
    },
    "cs_finalize_project": {},
    "cs_add_library": {
        "front_positional_arguments": ["name"],
        "options": [
            "STATIC",
            "SHARED",
            "MODULE",
            "OBJECT",
            "INTERFACE",
            "IMPORTED",
            "ALIAS",
            "GLOBAL",
            "EXCLUDE_FROM_ALL",
        ],
    },
    "cs_add_executable": {
        "front_positional_arguments": ["name"],
        "options": ["WIN32", "MACOSX_BUNDLE", "EXCLUDE_FROM_ALL", "IMPORTED", "ALIAS", "GLOBAL"],
    },
    "cs_target_sources": {
        "front_positional_arguments": ["target"],
        "multi_value_keywords": [
            *_TARGET_SCOPES,
            "PRIVATE_INSTALL",
            "PUBLIC_INSTALL",
            "INTERFACE_INSTALL",
            "PRIVATE_INSTALL_ABSOLUTE_PATH",
            "PUBLIC_INSTALL_ABSOLUTE_PATH",
            "INTERFACE_INSTALL_ABSOLUTE_PATH",
        ],
    },
    "cs_target_link_libraries": {
        "front_positional_arguments": ["target"],
        "multi_value_keywords": _TARGET_SCOPES,
    },
    "cs_find_package": {
        "front_positional_arguments": ["target", "propagation", "package"],
        "options": ["EXACT", "QUIET", "REQUIRED", "CONFIG", "MODULE", "NO_MODULE", "GLOBAL", "NO_POLICY_SCOPE"],
        "multi_value_keywords": ["COMPONENTS", "OPTIONAL_COMPONENTS"],
    },
    "cs_install_target": {
        "front_positional_arguments": ["target"],
        "options": ["DEFAULT"],
        "one_value_keywords": ["COMPONENT"],
    },
    "cs_finalize_target": {"front_positional_arguments": ["target"]},
    "cs_target_check_installed_headers": {
        "front_positional_arguments": ["target"],
        "multi_value_keywords": ["COMPILE_PROFILES"],
    },
    "cs_target_use_openmp": {"front_positional_arguments": ["target", "scope"]},
    "cs_add_compile_profile_rule": {
        "options": ["CLANG_TIDY"],
        "one_value_keywords": ["PROFILE"],
        "multi_value_keywords": [
            "CONFIGS",
            "COMPILERS",
            "FRONTENDS",
            "PLATFORMS",
            "COMPILE_OPTIONS",
            "COMPILE_DEFINITIONS",
            "LINK_OPTIONS",
            "PROFILES",
        ],
    },
    "cs_target_use_compile_profiles": {"front_positional_arguments": ["target"]},
    "cs_target_runtime_environment": {
        "front_positional_arguments": ["target"],
        "one_value_keywords": ["DEBUGGER_PATH"],
        "multi_value_keywords": ["PATH", "SET"],
    },
}
