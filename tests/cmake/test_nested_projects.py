"""A csCMake project added with add_subdirectory into another csCMake project (one build tree, two packages)."""

from __future__ import annotations

from pathlib import Path

import pytest

from tests.cmake.cmake_project import configure, install

pytestmark = pytest.mark.requires("cmake", "ninja")

# outer links a target of the nested inner project; both have a component named core (and cscmake_common)
OUTER = """
cs_initialize_project(NAMESPACE outer CXX_STANDARD 17 DEFAULT_CONFIG Debug Release)
add_subdirectory(inner)
cs_add_library(o_core INTERFACE)
cs_target_link_libraries(o_core INTERFACE inner::i_core)
cs_install_target(o_core core DEFAULT)
cs_finalize_target(o_core)
cs_finalize_project()
"""
INNER = """
project(inner VERSION 2.0.0 LANGUAGES NONE)
cs_initialize_project(NAMESPACE inner CXX_STANDARD 17 DEFAULT_CONFIG Debug{extra})
cs_add_library(i_core INTERFACE)
cs_add_library(inner::i_core ALIAS i_core)
cs_install_target(i_core core DEFAULT)
cs_finalize_target(i_core)
cs_finalize_project()
"""


def _text(output: str) -> str:
    return " ".join(output.split())


def test_nested_project_installs_two_packages(tmp_path: Path) -> None:
    """Each project installs its own package; outer's Config finds inner (link between the two projects)."""
    prefix = tmp_path / "install"
    result = install(tmp_path / "outer", OUTER, prefix, {"inner/CMakeLists.txt": INNER.format(extra="")})
    assert result.returncode == 0, result.output

    consumer = """
find_package(outer REQUIRED CONFIG)
foreach(t outer::o_core inner::i_core outer::cscmake_base_include inner::cscmake_base_include)
  if(TARGET ${t})
    cstest_report(${t} found)
  endif()
endforeach()
cstest_report(inner_found "${inner_FOUND}")
"""
    found = configure(tmp_path / "consumer", consumer, args=[f"-DCMAKE_PREFIX_PATH={prefix.as_posix()}"])

    assert found.returncode == 0, found.output
    for target in ("outer::o_core", "inner::i_core", "outer::cscmake_base_include"):
        assert found.reports.get(target) == "found", target
    # only the components outer needs: inner's core (i_core does not use inner's default targets)
    assert "inner::cscmake_base_include" not in found.reports
    assert (prefix / "lib" / "cmake" / "outer" / "outerConfig.cmake").is_file()
    assert (prefix / "lib" / "cmake" / "inner" / "innerConfig.cmake").is_file()


def test_nested_project_configuration_not_in_the_build(tmp_path: Path) -> None:
    files = {"inner/CMakeLists.txt": INNER.format(extra=' CUSTOM_CONFIG Paranoid BASED_ON Debug POSTFIX "dp"')}
    result = configure(tmp_path, OUTER, files)

    assert result.returncode != 0
    assert "configuration Paranoid of inner is not a configuration of the build" in _text(result.output)
