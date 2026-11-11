"""cs_target_check_installed_headers: each installed header compiles on its own (csCheckInstalledHeaders.cmake)."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

from tests.cmake.cmake_project import install

# the generated sources compile: a C++ compiler on PATH (not set up on Windows for these tests; covered by the smoke
# tests)
pytestmark = [
    pytest.mark.requires("cmake", "ninja"),
    pytest.mark.skipif(sys.platform == "win32", reason="needs a C++ compiler environment"),
]

BODY = """enable_language(CXX)
cs_initialize_project(NAMESPACE cstest CXX_STANDARD 17 DEFAULT_CONFIG Debug)
cs_add_library(lib INTERFACE)
cs_target_sources(lib INTERFACE_INSTALL {headers})
cs_target_link_libraries(lib INTERFACE cstest::cscmake_base_include)
cs_install_target(lib COMPONENT core DEFAULT)
cs_target_check_installed_headers(lib)
get_target_property(sources lib_installed_headers SOURCES)
cstest_report(sources "${{sources}}")
"""


def _check(tmp_path: Path, files: dict[str, str]):  # type: ignore[no-untyped-def]
    body = BODY.format(headers=" ".join(files))
    return install(tmp_path / "project", body, tmp_path / "prefix", files)


def test_headers_with_the_same_name_are_each_checked(tmp_path: Path) -> None:
    """a/util.h, b/util.h and util.hpp (at the base of the project, INTERFACE_INSTALL with relative paths): one source
    each, all built."""
    files = {"a/util.h": "#pragma once\n", "b/util.h": "#pragma once\n", "util.hpp": "#pragma once\n"}

    result = _check(tmp_path, files)

    assert result.returncode == 0, result.output
    sources = [Path(s.removeprefix("$<BUILD_INTERFACE:").removesuffix(">")) for s in result.report_list("sources")]
    assert sorted(s.relative_to(tmp_path / "project" / "build" / "gen" / "shc").as_posix() for s in sources) == [
        "a/util.h.cpp",
        "b/util.h.cpp",
        "util.hpp.cpp",
    ]


def test_a_header_that_is_not_self_contained_fails_the_build(tmp_path: Path) -> None:
    files = {
        "good.h": "#pragma once\n#include <string>\ninline std::string good() { return {}; }\n",
        "bad.h": "#pragma once\ninline std::string bad() { return {}; }\n",
    }

    result = _check(tmp_path, files)

    assert result.returncode != 0
    assert "bad.h.cpp" in result.output
