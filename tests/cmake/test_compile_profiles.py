"""Compile profiles: rules with conditions, applied by cs_finalize_target (csCompileProfiles.cmake)."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

from tests.cmake.cmake_project import configure

# the targets compile: a C++ compiler on PATH (not set up on Windows for these tests; covered by the smoke tests)
pytestmark = [
    pytest.mark.requires("cmake", "ninja"),
    pytest.mark.skipif(sys.platform == "win32", reason="needs a C++ compiler environment"),
]

INIT = """
enable_language(CXX)
cs_initialize_project(NAMESPACE cstest CXX_STANDARD 17 DEFAULT_CONFIG Debug Release{defaults})
"""
FILES = {"lib.cpp": "int lib() { return 0; }\n"}


def _body(rules: str, use: str = "", defaults: str = "") -> str:
    return (
        INIT.format(defaults=defaults)
        + rules
        + """
cs_add_library(lib STATIC lib.cpp)
"""
        + use
        + """
cs_finalize_target(lib)
foreach(property COMPILE_OPTIONS COMPILE_DEFINITIONS LINK_OPTIONS INTERFACE_LINK_OPTIONS CXX_CLANG_TIDY)
  get_target_property(value lib ${property})
  cstest_report(${property} "${value}")
endforeach()
cs_finalize_project()
"""
    )


def test_rule_conditions_become_generator_expressions(tmp_path: Path) -> None:
    rules = """
cs_add_compile_profile_rule(PROFILE p CONFIGS Debug COMPILERS GNU Clang COMPILE_OPTIONS -Wa -Wb)
cs_add_compile_profile_rule(PROFILE p PLATFORMS Linux COMPILE_DEFINITIONS X=1)
"""
    result = configure(
        tmp_path, _body(rules, "cs_target_use_compile_profiles(lib p)\n", " DEFAULT_COMPILE_PROFILES NONE"), FILES
    )

    assert result.returncode == 0, result.output
    assert result.reports["COMPILE_OPTIONS"] == "$<$<AND:$<CONFIG:Debug>,$<CXX_COMPILER_ID:GNU,Clang>>:-Wa;-Wb>"
    assert result.reports["COMPILE_DEFINITIONS"] == "$<$<PLATFORM_ID:Linux>:X=1>"


def test_nested_profiles_combine_the_conditions(tmp_path: Path) -> None:
    rules = """
cs_add_compile_profile_rule(PROFILE inner COMPILERS GNU COMPILE_OPTIONS -Winner)
cs_add_compile_profile_rule(PROFILE outer CONFIGS Release PROFILES inner)
"""
    result = configure(
        tmp_path, _body(rules, "cs_target_use_compile_profiles(lib outer)\n", " DEFAULT_COMPILE_PROFILES NONE"), FILES
    )

    assert result.returncode == 0, result.output
    assert result.reports["COMPILE_OPTIONS"] == "$<$<AND:$<CONFIG:Release>,$<CXX_COMPILER_ID:GNU>>:-Winner>"


@pytest.mark.parametrize(
    ("defaults", "expected"),
    [("", "$<$<CXX_COMPILER_ID:MSVC>:/MP;/Zc:__cplusplus>"), (" DEFAULT_COMPILE_PROFILES NONE", "value-NOTFOUND")],
)
def test_default_profiles(tmp_path: Path, defaults: str, expected: str) -> None:
    result = configure(tmp_path, _body("", defaults=defaults), FILES)

    assert result.returncode == 0, result.output
    assert result.reports["COMPILE_OPTIONS"] == expected


def test_a_folder_sets_its_own_default_profiles(tmp_path: Path) -> None:
    rules = """
cs_add_compile_profile_rule(PROFILE strict COMPILE_OPTIONS -Wstrict)
cs_add_compile_profile_rule(PROFILE loose COMPILE_OPTIONS -Wloose)
"""
    body = (
        INIT.format(defaults=" DEFAULT_COMPILE_PROFILES strict")
        + rules
        + """
cs_add_library(lib STATIC lib.cpp)
cs_finalize_target(lib)
add_subdirectory(tests)
get_target_property(value lib COMPILE_OPTIONS)
cstest_report(LIB "${value}")
get_target_property(value test_lib COMPILE_OPTIONS)
cstest_report(TEST "${value}")
cs_finalize_project()
"""
    )
    tests = """
set(CSCMAKE_DEFAULT_COMPILE_PROFILES loose)
cs_add_library(test_lib STATIC ../lib.cpp)
cs_finalize_target(test_lib)
"""
    result = configure(tmp_path, body, {**FILES, "tests/CMakeLists.txt": tests})

    assert result.returncode == 0, result.output
    assert result.reports["LIB"] == "-Wstrict"
    assert result.reports["TEST"] == "-Wloose"


def test_link_options_of_a_static_library_are_also_interface(tmp_path: Path) -> None:
    rules = "cs_add_compile_profile_rule(PROFILE p LINK_OPTIONS -fsanitize=undefined)\n"
    result = configure(
        tmp_path, _body(rules, "cs_target_use_compile_profiles(lib p)\n", " DEFAULT_COMPILE_PROFILES NONE"), FILES
    )

    assert result.returncode == 0, result.output
    assert result.reports["LINK_OPTIONS"] == "-fsanitize=undefined"
    assert result.reports["INTERFACE_LINK_OPTIONS"] == "-fsanitize=undefined"


@pytest.mark.parametrize(
    ("profile", "mode"), [("cscmake_hardening_fast", "FAST"), ("cscmake_hardening_debug", "DEBUG")]
)
def test_hardening_levels(tmp_path: Path, profile: str, mode: str) -> None:
    result = configure(
        tmp_path, _body("", f"cs_target_use_compile_profiles(lib {profile})\n", " DEFAULT_COMPILE_PROFILES NONE"), FILES
    )

    assert result.returncode == 0, result.output
    assert result.reports["COMPILE_DEFINITIONS"] == (
        "$<$<OR:$<CXX_COMPILER_FRONTEND_VARIANT:GNU>>:_GLIBCXX_ASSERTIONS;"
        f"_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_{mode}>"
    )


def test_unknown_profile(tmp_path: Path) -> None:
    result = configure(tmp_path, _body("", "cs_target_use_compile_profiles(lib nope)\n"), FILES)

    assert result.returncode != 0
    assert "compile profile nope of lib is not defined" in " ".join(result.output.split())


@pytest.mark.parametrize(
    ("configs", "required"), [("", True), (" CONFIGS Release", False)], ids=["matching", "not-in-build"]
)
def test_clang_tidy_is_mandatory_where_the_rule_matches(tmp_path: Path, configs: str, required: bool) -> None:
    """The build is Debug: a clang-tidy rule for Release does not need clang-tidy (and does not set it)."""
    rules = f"cs_add_compile_profile_rule(PROFILE tidy{configs} CLANG_TIDY)\n"
    result = configure(
        tmp_path,
        _body(rules, "cs_target_use_compile_profiles(lib tidy)\n"),
        FILES,
        args=["-DCLANG_TIDY_EXE=/nonexistent/clang-tidy"],
    )

    if required:
        assert result.returncode != 0
        assert "clang-tidy is required" in " ".join(result.output.split())
    else:
        assert result.returncode == 0, result.output
        assert result.reports["CXX_CLANG_TIDY"] == "value-NOTFOUND"
