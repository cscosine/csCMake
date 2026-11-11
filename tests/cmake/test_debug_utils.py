"""Printers: cs_print_target, cs_print_project (always printed), and the project printed by the lifecycle."""

from __future__ import annotations

from pathlib import Path

import pytest

from tests.cmake.cmake_project import REPO_ROOT, configure

pytestmark = pytest.mark.requires("cmake", "ninja")

INIT = "cs_initialize_project(NAMESPACE cstest CXX_STANDARD 17 DEFAULT_CONFIG Debug Release)\n"
PROJECT = """
cs_add_library(base INTERFACE)
cs_install_target(base COMPONENT comp_base)
cs_finalize_target(base)
cs_add_library(lib INTERFACE)
cs_add_library(cstest::lib ALIAS lib)
set_target_properties(lib PROPERTIES INTERFACE_COMPILE_DEFINITIONS "CSTEST_FLAG=1" EXPORT_NAME exported_lib)
cs_target_sources(lib INTERFACE_INSTALL lib.h)
cs_target_link_libraries(lib INTERFACE base)
cs_target_runtime_environment(lib SET QT_PLUGIN_PATH=/qt)
cs_install_target(lib COMPONENT comp_lib DEFAULT)
cs_finalize_target(lib)
cs_finalize_project()
"""


def _lines(output: str) -> list[str]:
    return [line.removeprefix("-- ") for line in output.splitlines()]


def test_print_target_prints_without_the_debug_switch(tmp_path: Path) -> None:
    """The csCMake view (dependencies resolved after cs_finalize_project), then the CMake properties."""
    result = configure(tmp_path, INIT + PROJECT + "cs_print_target(cstest::lib)\n", {"lib.h": ""})

    assert result.returncode == 0, result.output
    lines = _lines(result.output)
    assert "[cs_print_target] lib: INTERFACE_LIBRARY, project cstest" in lines
    for expected in (
        "  component: comp_lib",
        "  headers to install: lib.h",
        "  run-time variables: QT_PLUGIN_PATH=/qt",
        "  depends on (cs_finalize_project): base",
        "  CMake properties:",
        "    INTERFACE_COMPILE_DEFINITIONS = CSTEST_FLAG=1",
        "    EXPORT_NAME = exported_lib",
        "    DEBUG_POSTFIX = d",  # <CONFIG> expanded for every configuration
    ):
        assert expected in lines, expected


def test_print_target_of_something_that_is_not_a_target(tmp_path: Path) -> None:
    result = configure(tmp_path, INIT + "cs_print_target(nope)\ncs_finalize_project()\n")

    assert result.returncode == 0, result.output
    assert "[cs_print_target] nope is not a target" in _lines(result.output)


def test_print_project_prints_without_the_debug_switch(tmp_path: Path) -> None:
    result = configure(tmp_path, INIT + PROJECT + "cs_print_project()\n", {"lib.h": ""})

    assert result.returncode == 0, result.output
    lines = _lines(result.output)
    header = f"[cs_print_project] project cstest (cstest 1.0.0), csCMake {REPO_ROOT.as_posix()}"
    assert header in lines
    for expected in (
        "  configurations: Debug;Release (CMAKE_BUILD_TYPE: Debug)",
        "  targets: cstest_cscmake_base_include;base;lib",
        "    comp_lib: targets lib",
        "      depends on (cs_finalize_project): comp_base",
    ):
        assert any(line.startswith(expected) for line in lines), expected
    assert any(line.startswith("  components: ") and "(default: cscmake_common;comp_lib)" in line for line in lines)


@pytest.mark.parametrize("debug", [False, True])
def test_the_lifecycle_prints_the_project_with_the_debug_switch_only(tmp_path: Path, debug: bool) -> None:
    switch = "set(cstest_CSCMAKE_DEBUG ON)\n" if debug else ""
    result = configure(tmp_path, switch + INIT + PROJECT, {"lib.h": ""})

    assert result.returncode == 0, result.output
    printed = [line for line in _lines(result.output) if line.startswith("[cs_finalize_project] project cstest")]
    assert len(printed) == (1 if debug else 0)
