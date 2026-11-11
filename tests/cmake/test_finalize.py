"""The project is finalized at the end of the CMakeLists.txt of cs_initialize_project, with its targets."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

from tests.cmake.cmake_project import after_finalize, configure

pytestmark = pytest.mark.requires("cmake", "ninja")

INIT = "cs_initialize_project(NAMESPACE cstest CXX_STANDARD 17 DEFAULT_CONFIG Debug)\n"


@pytest.mark.skipif(sys.platform == "win32", reason="needs a C++ compiler environment")
def test_the_targets_are_finalized_at_the_end_of_the_project(tmp_path: Path) -> None:
    """A compile profile defined and used after the target is created still applies: the profiles are applied at the
    end, and not before."""
    body = (
        "enable_language(CXX)\n"
        + INIT.replace("Debug", "Debug DEFAULT_COMPILE_PROFILES NONE")
        + """
cs_add_library(lib STATIC lib.cpp)
cs_add_compile_profile_rule(PROFILE late COMPILE_OPTIONS -Wlate)
cs_target_use_compile_profiles(lib late)
get_target_property(value lib COMPILE_OPTIONS)
cstest_report(before "${value}")
"""
        + after_finalize('get_target_property(value lib COMPILE_OPTIONS)\ncstest_report(after "${value}")\n')
    )
    result = configure(tmp_path, body, {"lib.cpp": "int lib() { return 0; }\n"})

    assert result.returncode == 0, result.output
    assert result.reports["before"] == "value-NOTFOUND"
    assert result.reports["after"] == "$<$<COMPILE_LANGUAGE:CXX>:-Wlate>"


def test_a_nested_project_is_finalized_before_the_outer_one_continues(tmp_path: Path) -> None:
    body = (
        INIT
        + """
add_subdirectory(inner)
get_property(inner GLOBAL PROPERTY _CSCMAKE_PROJECT_FINALIZED_inner)
get_property(outer GLOBAL PROPERTY _CSCMAKE_PROJECT_FINALIZED_cstest)
cstest_report(inner "${inner}")
cstest_report(outer "${outer}")
"""
    )
    inner = """project(inner VERSION 1.0.0 LANGUAGES NONE)
cs_initialize_project(NAMESPACE inner CXX_STANDARD 17 DEFAULT_CONFIG Debug)
cs_add_library(inner_lib INTERFACE)
"""
    result = configure(tmp_path, body, {"inner/CMakeLists.txt": inner})

    assert result.returncode == 0, result.output
    assert result.reports["inner"] == "TRUE"
    assert result.reports["outer"] == ""


def test_the_folder_variables_are_the_ones_where_the_target_is_created(tmp_path: Path) -> None:
    """The finalization runs in the folder of the project: what a subfolder sets was taken by its targets."""
    body = (
        INIT
        + "add_subdirectory(sub)\n"
        + after_finalize(
            'get_target_property(value sub_lib CSCMAKE_COMPILE_PROFILES)\ncstest_report(profiles "${value}")\n'
        )
    )
    sub = "set(CSCMAKE_DEFAULT_COMPILE_PROFILES cscmake_warnings)\ncs_add_library(sub_lib INTERFACE)\n"
    result = configure(tmp_path, body, {"sub/CMakeLists.txt": sub})

    assert result.returncode == 0, result.output
    assert result.reports["profiles"] == "cscmake_warnings"
