"""cs_target_link_libraries: target_link_libraries, failing for links after the project is finalized."""

from __future__ import annotations

from pathlib import Path

import pytest

from tests.cmake.cmake_project import after_finalize, configure

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
target_link_libraries(with_cmake INTERFACE cstest::a INTERFACE b ext not_a_target)

get_target_property(links with_cs INTERFACE_LINK_LIBRARIES)
cstest_report(with_cs "${links}")
get_target_property(links with_cmake INTERFACE_LINK_LIBRARIES)
cstest_report(with_cmake "${links}")
"""


def test_the_links_are_the_ones_of_target_link_libraries(tmp_path: Path) -> None:
    """The arguments go to target_link_libraries as they are: same links (keywords where they are, aliases kept)."""
    result = configure(tmp_path, BODY)

    assert result.returncode == 0, result.output
    assert result.report_list("with_cs") == ["cstest::a", "b", "ext", "not_a_target"]
    assert result.report_list("with_cs") == result.report_list("with_cmake")


@pytest.mark.parametrize("name", ["lib", "cstest::lib"])
def test_links_after_the_finalization_fail_at_the_call(tmp_path: Path, name: str) -> None:
    """E.g. from a parent project: the dependencies between the components are already computed."""
    body = """
cs_initialize_project(NAMESPACE cstest CXX_STANDARD 17 DEFAULT_CONFIG Debug)
cs_add_library(lib INTERFACE)
cs_add_library(cstest::lib ALIAS lib)
cs_add_library(other INTERFACE)
""" + after_finalize(f"cs_target_link_libraries({name} INTERFACE other)\n")
    result = configure(tmp_path, body)

    assert result.returncode != 0
    message = f"[cs_target_link_libraries] {name}: its project is already finalized"
    assert message in " ".join(result.output.split())
