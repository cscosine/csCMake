"""cs_target_use_openmp: find_package(OpenMP) in the installed package only when consumers need it (csOpenMP.cmake)."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

from tests.cmake.cmake_project import configure

# finds OpenMP for a C++ compiler on PATH (on Windows: the Visual Studio developer environment); Apple Clang has no
# OpenMP of its own
pytestmark = [
    pytest.mark.requires("cmake", "ninja"),
    pytest.mark.skipif(sys.platform == "darwin", reason="Apple Clang has no OpenMP"),
]

BODY = """enable_language(CXX)
cs_initialize_project(NAMESPACE cstest CXX_STANDARD 17 DEFAULT_CONFIG Debug)
cs_add_library(lib {type} lib.cpp)
cs_target_use_openmp(lib {scope})
get_target_property(packages lib CSCMAKE_FIND_PACKAGES)
cstest_report(packages "${{packages}}")
"""


@pytest.mark.parametrize(
    ("lib_type", "scope", "propagated"),
    [
        ("SHARED", "PRIVATE", False),
        ("SHARED", "PUBLIC", True),
        ("STATIC", "PRIVATE", True),
    ],
)
def test_find_package_goes_to_the_installed_package_when_consumers_need_it(
    tmp_path: Path, lib_type: str, scope: str, propagated: bool
) -> None:
    result = configure(tmp_path, BODY.format(type=lib_type, scope=scope), {"lib.cpp": "int lib() { return 0; }\n"})

    assert result.returncode == 0, result.output
    assert result.reports["packages"] == ("OpenMP REQUIRED" if propagated else "packages-NOTFOUND")
    assert "Enabling OpenMP" not in result.output
