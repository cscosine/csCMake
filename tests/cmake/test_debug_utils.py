"""Debug printers: cs_print_target_properties, cs_print_components, cs_print_state."""

from __future__ import annotations

from pathlib import Path

import pytest

from tests.cmake.cmake_project import REPO_ROOT, configure

pytestmark = pytest.mark.requires("cmake", "ninja")

INIT = """
set(cstest_CSCMAKE_DEBUG ON)
cs_initialize_project(NAMESPACE cstest CXX_STANDARD 17 DEFAULT_CONFIG Debug Release)
"""


PROPERTIES = """
cs_add_library(lib INTERFACE)
set_target_properties(lib PROPERTIES INTERFACE_COMPILE_DEFINITIONS "CSTEST_FLAG=1" EXPORT_NAME exported_lib)
cs_print_target_properties(lib)
cs_finalize_target(lib)
cs_finalize_project()
"""
COMPONENTS = """
cs_add_library(lib_default INTERFACE)
cs_install_target(lib_default comp_default DEFAULT)
cs_add_library(lib_other INTERFACE)
cs_install_target(lib_other comp_other)
cs_print_components()
cs_finalize_target(lib_default)
cs_finalize_target(lib_other)
cs_finalize_project()
"""


def test_print_target_properties_prints_the_set_properties(tmp_path: Path) -> None:
    result = configure(tmp_path, INIT + PROPERTIES)

    assert result.returncode == 0, result.output
    assert "lib INTERFACE_COMPILE_DEFINITIONS = CSTEST_FLAG=1" in result.output
    assert "lib EXPORT_NAME = exported_lib" in result.output
    # <CONFIG> expanded for every configuration: the postfixes set by cs_add_library
    assert "lib DEBUG_POSTFIX = d" in result.output


def test_print_components_lists_the_default_components(tmp_path: Path) -> None:
    result = configure(tmp_path, INIT + COMPONENTS)

    assert result.returncode == 0, result.output
    line = next(x for x in result.output.splitlines() if "[cs_print_components] default components:" in x)
    assert "comp_default" in line
    assert "comp_other" not in line


def test_print_state_shows_the_folder_of_cscmake(tmp_path: Path) -> None:
    result = configure(tmp_path, INIT + "cs_finalize_project()\n")

    assert result.returncode == 0, result.output
    assert f"csCMake path: {REPO_ROOT.as_posix()}\n" in result.output
