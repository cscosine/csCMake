"""cs_finalize_target and cs_finalize_project are mandatory, and checked."""

from __future__ import annotations

from pathlib import Path

import pytest

from tests.cmake.cmake_project import configure

pytestmark = pytest.mark.requires("cmake", "ninja")

INIT = "cs_initialize_project(NAMESPACE cstest CXX_STANDARD 17 DEFAULT_CONFIG Debug)\n"


def _text(output: str) -> str:
    return " ".join(output.split())  # CMake wraps the messages


def test_complete_project(tmp_path: Path) -> None:
    body = (
        INIT
        + """
cs_add_library(a INTERFACE)
cs_add_library(b INTERFACE)
cs_target_link_libraries(b INTERFACE a)
cs_finalize_target(a)
cs_finalize_target(b)
cs_finalize_project()
"""
    )
    assert configure(tmp_path, body).returncode == 0


def test_target_not_finalized(tmp_path: Path) -> None:
    body = (
        INIT
        + """
cs_add_library(a INTERFACE)
cs_add_library(b INTERFACE)
cs_finalize_target(a)
cs_finalize_project()
"""
    )
    result = configure(tmp_path, body)

    assert result.returncode != 0
    assert "cs_finalize_target(<target>) is required for every target, after its links: missing for b" in _text(
        result.output
    )


def test_links_added_after_finalize_target(tmp_path: Path) -> None:
    """With target_link_libraries (cs_target_link_libraries fails at the call): found by cs_finalize_project."""
    body = (
        INIT
        + """
cs_add_library(a INTERFACE)
cs_add_library(b INTERFACE)
cs_finalize_target(a)
cs_finalize_target(b)
target_link_libraries(b INTERFACE a)
cs_finalize_project()
"""
    )
    result = configure(tmp_path, body)

    assert result.returncode != 0
    assert "links added after cs_finalize_target: b" in _text(result.output)


def test_finalize_project_missing(tmp_path: Path) -> None:
    body = (
        INIT
        + """
cs_add_library(a INTERFACE)
cs_finalize_target(a)
"""
    )
    result = configure(tmp_path, body)

    assert result.returncode != 0
    expected = (
        f"cs_finalize_project() is required at the end of {tmp_path.as_posix()}/CMakeLists.txt (namespace cstest)"
    )
    assert expected in _text(result.output)
