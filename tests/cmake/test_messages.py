"""What csCMake says at the VERBOSE and DEBUG log levels, command by command."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

from tests.cmake.cmake_project import configure

pytestmark = pytest.mark.requires("cmake", "ninja")

INIT = "cs_initialize_project(NAMESPACE cstest CXX_STANDARD 17 DEFAULT_CONFIG Debug)\n"
VERBOSE = ["--log-level=VERBOSE"]
DEBUG = ["--log-level=DEBUG"]


def _lines(output: str) -> list[str]:
    return [line.removeprefix("-- ").strip() for line in output.splitlines()]


def test_find_package_says_what_it_found(tmp_path: Path) -> None:
    """Found: the version and the folder of the package; not found: said too."""
    files = {
        "fake/FakeConfig.cmake": "",
        "fake/FakeConfigVersion.cmake": "set(PACKAGE_VERSION 2.1)\nset(PACKAGE_VERSION_COMPATIBLE TRUE)\n",
    }
    body = (
        INIT
        + "cs_add_library(lib INTERFACE)\n"
        + 'cs_find_package(lib PUBLIC Fake CONFIG REQUIRED PATHS "${CMAKE_CURRENT_SOURCE_DIR}/fake" NO_DEFAULT_PATH)\n'
        + "cs_find_package(lib PRIVATE NotAPackage QUIET)\n"
    )
    result = configure(tmp_path, body, files, args=VERBOSE)

    assert result.returncode == 0, result.output
    lines = _lines(result.output)
    fake = (tmp_path / "fake").as_posix()
    assert any(
        line.startswith("cstest: lib finds Fake CONFIG REQUIRED PATHS")
        and line.endswith(f"(PUBLIC: its consumers too): found 2.1 in {fake}")
        for line in lines
    ), lines
    assert "cstest: lib finds NotAPackage QUIET (PRIVATE): not found" in lines


def test_runtime_environment_says_what_it_adds(tmp_path: Path) -> None:
    body = (
        INIT
        + "cs_add_library(lib INTERFACE)\ncs_target_runtime_environment(lib PATH /a /b SET X=1 DEBUGGER_PATH AFTER)\n"
    )
    result = configure(tmp_path, body, args=VERBOSE)

    assert result.returncode == 0, result.output
    assert "cstest: lib run-time environment: PATH /a, /b; SET X=1; DEBUGGER_PATH AFTER" in _lines(result.output)


def test_a_nested_project_says_where_its_configurations_come_from(tmp_path: Path) -> None:
    inner = "project(inner VERSION 1.0.0 LANGUAGES NONE)\n" + INIT.replace("cstest", "inner")
    result = configure(tmp_path, INIT + "add_subdirectory(inner)\n", {"inner/CMakeLists.txt": inner}, args=VERBOSE)

    assert result.returncode == 0, result.output
    expected = (
        "inner: nested project: the configurations of the build come from the first csCMake project (Debug); "
        "the ones of inner are checked against them"
    )
    assert expected in _lines(result.output)


@pytest.mark.skipif(sys.platform == "win32", reason="needs a C++ compiler environment")
def test_compile_profiles_say_which_rules_apply(tmp_path: Path) -> None:
    """Each rule when defined (DEBUG), the profiles a target asks for (VERBOSE), each rule applied to it (DEBUG), with
    the rules for another platform marked."""
    body = (
        "enable_language(CXX)\n"
        + INIT.replace("Debug", "Debug DEFAULT_COMPILE_PROFILES NONE")
        + "cs_add_compile_profile_rule(PROFILE p COMPILE_OPTIONS -Wa CONFIGS Debug)\n"
        + "cs_add_compile_profile_rule(PROFILE p COMPILE_DEFINITIONS X=1 PLATFORMS NotThisOne)\n"
        + "cs_add_library(lib STATIC lib.cpp)\n"
        + "cs_target_use_compile_profiles(lib p)\n"
    )
    result = configure(tmp_path, body, {"lib.cpp": "int lib() { return 0; }\n"}, args=DEBUG)

    assert result.returncode == 0, result.output
    lines = _lines(result.output)
    assert any(
        line.startswith("compile profile p: rule ") and "COMPILE_OPTIONS -Wa; CONFIGS Debug" in line for line in lines
    )
    assert "cstest: lib uses the compile profiles p" in lines
    assert "lib: compile profiles p" in lines
    assert any(line.startswith("p rule ") and line.endswith(": COMPILE_OPTIONS -Wa; CONFIGS Debug") for line in lines)
    assert any(
        line.startswith("p rule ")
        and line.endswith("(not for this compiler or platform): COMPILE_DEFINITIONS X=1; PLATFORMS NotThisOne")
        for line in lines
    ), lines


@pytest.mark.skipif(sys.platform == "win32", reason="needs a C++ compiler environment")
def test_the_installed_headers_check_says_how_many_headers(tmp_path: Path) -> None:
    body = (
        "enable_language(CXX)\n"
        + INIT
        + "cs_add_library(lib INTERFACE)\n"
        + "cs_target_sources(lib INTERFACE_INSTALL a.h b.h)\n"
        + "cs_target_check_installed_headers(lib)\n"
    )
    result = configure(tmp_path, body, {"a.h": "", "b.h": ""}, args=VERBOSE)

    assert result.returncode == 0, result.output
    assert "cstest: lib_installed_headers compiles each of the 2 installed headers of lib" in _lines(result.output)
