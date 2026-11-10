"""Install RPATH of the targets, set by cs_finalize_target (csAddLibraryExecutable.cmake)."""

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

ORIGIN = "@loader_path" if sys.platform == "darwin" else "$ORIGIN"
FILES = {"lib.cpp": "int lib() { return 0; }\n", "main.cpp": "int main() { return 0; }\n"}
TARGETS = """
cs_add_library(shared_lib SHARED lib.cpp)
cs_add_library(module_lib MODULE lib.cpp)
cs_add_library(static_lib STATIC lib.cpp)
cs_add_executable(app main.cpp)
{before_finalize}
foreach(target shared_lib module_lib static_lib app)
  cs_finalize_target(${{target}})
  get_target_property(rpath ${{target}} INSTALL_RPATH)
  cstest_report(${{target}} "${{rpath}}")
endforeach()
cs_finalize_project()
"""


def _configure(tmp_path: Path, init_args: str = "", before_init: str = "", before_finalize: str = ""):  # type: ignore[no-untyped-def]
    body = (
        "enable_language(CXX)\n"
        + before_init
        + f"cs_initialize_project(NAMESPACE cstest CXX_STANDARD 17 DEFAULT_CONFIG Debug{init_args})\n"
        + TARGETS.format(before_finalize=before_finalize)
    )
    result = configure(tmp_path, body, FILES)
    assert result.returncode == 0, result.output
    return result


def test_default(tmp_path: Path) -> None:
    result = _configure(tmp_path)

    assert result.reports["app"] == f"{ORIGIN}/../lib"
    assert result.reports["shared_lib"] == ORIGIN
    assert result.reports["module_lib"] == ORIGIN
    assert result.reports["static_lib"] == ""


def test_off_for_the_project(tmp_path: Path) -> None:
    result = _configure(tmp_path, init_args=" INSTALL_RPATH OFF")

    assert {result.reports[t] for t in ("app", "shared_lib", "module_lib")} == {""}


def test_off_for_a_folder(tmp_path: Path) -> None:
    result = _configure(tmp_path, before_finalize="set(CSCMAKE_INSTALL_RPATH OFF)\n")

    assert result.reports["app"] == ""


def test_the_own_value_of_a_target_wins(tmp_path: Path) -> None:
    result = _configure(tmp_path, before_finalize='set_target_properties(app PROPERTIES INSTALL_RPATH "/opt/x")\n')

    assert result.reports["app"] == "/opt/x"
    assert result.reports["shared_lib"] == ORIGIN


def test_the_project_cmake_install_rpath_wins(tmp_path: Path) -> None:
    result = _configure(tmp_path, before_init='set(CMAKE_INSTALL_RPATH "/opt/y")\n')

    assert result.reports["app"] == "/opt/y"
    assert result.reports["shared_lib"] == "/opt/y"


def test_invalid_value(tmp_path: Path) -> None:
    body = "cs_initialize_project(NAMESPACE cstest CXX_STANDARD 17 DEFAULT_CONFIG Debug INSTALL_RPATH maybe)\n"

    result = configure(tmp_path, body)

    assert result.returncode != 0
    assert "INSTALL_RPATH is ON or OFF, got maybe" in " ".join(result.output.split())
