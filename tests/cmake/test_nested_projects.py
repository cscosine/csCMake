"""A csCMake project added with add_subdirectory into another csCMake project (one build tree, two packages)."""

from __future__ import annotations

import sys
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
cs_install_target(o_core COMPONENT core DEFAULT)
"""
INNER = """
project(inner VERSION 2.0.0 LANGUAGES NONE)
cs_initialize_project(NAMESPACE inner CXX_STANDARD 17 DEFAULT_CONFIG Debug{extra})
cs_add_library(i_core INTERFACE)
cs_add_library(inner::i_core ALIAS i_core)
cs_install_target(i_core COMPONENT core DEFAULT)
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


# links through aliases only: within outer (o_late links outer::o_base before it exists), to the nested project
# (o_base links inner::i_static privately: $<LINK_ONLY:...> in its export), and from a shared library
ALIASES_OUTER = """
enable_language(CXX)
cs_initialize_project(NAMESPACE outer CXX_STANDARD 17 DEFAULT_CONFIG Debug)
cs_add_library(o_late STATIC late.cpp)
cs_target_link_libraries(o_late PUBLIC outer::o_base)
cs_install_target(o_late COMPONENT late)
add_subdirectory(inner)
cs_add_library(o_base STATIC base.cpp)
cs_add_library(outer::o_base ALIAS o_base)
cs_target_link_libraries(o_base PRIVATE inner::i_static)
cs_install_target(o_base COMPONENT base DEFAULT)
"""
ALIASES_INNER = """
project(inner VERSION 2.0.0 LANGUAGES CXX)
cs_initialize_project(NAMESPACE inner CXX_STANDARD 17 DEFAULT_CONFIG Debug)
cs_add_library(i_static STATIC s.cpp)
cs_add_library(inner::i_static ALIAS i_static)
cs_install_target(i_static COMPONENT stat DEFAULT)
"""


@pytest.mark.skipif(sys.platform == "win32", reason="needs a C++ compiler environment")
def test_links_through_aliases_give_the_component_dependencies(tmp_path: Path) -> None:
    """The aliases are resolved by the dependency walk of the finalization and by CMake's export: late depends on
    base, base finds inner's component stat, the private link is exported as $<LINK_ONLY:inner::i_static>."""
    prefix = tmp_path / "install"
    files = {
        "inner/CMakeLists.txt": ALIASES_INNER,
        "inner/s.cpp": "int s() { return 1; }\n",
        "base.cpp": "int s(); int base() { return s(); }\n",
        "late.cpp": "int base(); int late() { return base(); }\n",
    }
    result = install(tmp_path / "outer", ALIASES_OUTER, prefix, files)
    assert result.returncode == 0, result.output

    config = (prefix / "lib" / "cmake" / "outer" / "outerConfig.cmake").read_text(encoding="utf-8")
    assert 'set(outer_late_DEPENDENCIES "base")' in config
    assert "find_dependency(inner COMPONENTS stat REQUIRED CONFIG)" in config
    base_targets = (prefix / "lib" / "cmake" / "outer" / "targets" / "baseTargets.cmake").read_text(encoding="utf-8")
    assert '"\\$<LINK_ONLY:inner::i_static>"' in base_targets
