"""cs_target_link_libraries: drop-in for target_link_libraries that resolves the aliases of project targets."""

from __future__ import annotations

from pathlib import Path

import pytest

from tests.cmake.cmake_project import configure

pytestmark = pytest.mark.requires("cmake", "ninja")

BODY = """
cs_initialize_project(NAMESPACE cstest CXX_STANDARD 17 DEFAULT_CONFIG Debug)
cs_add_library(a INTERFACE)
cs_add_library(cstest::a ALIAS a)
cs_add_library(b INTERFACE)
add_library(ext INTERFACE IMPORTED)

# the same links, with cs_target_link_libraries and with target_link_libraries
cs_add_library(with_cs INTERFACE)
cs_target_link_libraries(with_cs INTERFACE cstest::a INTERFACE b ext not_a_target)
add_library(with_cmake INTERFACE)
target_link_libraries(with_cmake INTERFACE a INTERFACE b ext not_a_target)

get_target_property(links with_cs INTERFACE_LINK_LIBRARIES)
cstest_report(with_cs "${links}")
get_target_property(links with_cmake INTERFACE_LINK_LIBRARIES)
cstest_report(with_cmake "${links}")
"""


def test_scope_keywords_kept_in_place_and_aliases_resolved(tmp_path: Path) -> None:
    """Keywords are passed through where they are (also when repeated), project aliases become the real target,
    imported targets and non-targets are passed unchanged: the result equals target_link_libraries."""
    result = configure(tmp_path, BODY)

    assert result.returncode == 0, result.output
    assert result.report_list("with_cs") == ["a", "b", "ext", "not_a_target"]
    assert result.report_list("with_cs") == result.report_list("with_cmake")
