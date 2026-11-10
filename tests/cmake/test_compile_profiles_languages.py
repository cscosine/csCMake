"""LANGUAGES of the compile profile rules: C++-only options not given to C sources (csCompileProfiles.cmake)."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

from tests.cmake.cmake_project import configure

# compile_commands.json of a C and a C++ source (Ninja; not set up on Windows for these tests)
pytestmark = [
    pytest.mark.requires("cmake", "ninja"),
    pytest.mark.skipif(sys.platform == "win32", reason="needs a C and C++ compiler environment"),
]

BODY = """enable_language(C)
enable_language(CXX)
cs_initialize_project(NAMESPACE cstest CXX_STANDARD 17 DEFAULT_CONFIG Debug DEFAULT_COMPILE_PROFILES NONE)
cs_add_compile_profile_rule(PROFILE both LANGUAGES C CXX COMPILE_OPTIONS -DCSTEST_BOTH_OPTION)
cs_add_compile_profile_rule(PROFILE default_language COMPILE_DEFINITIONS CSTEST_CXX_ONLY)
cs_add_library(lib STATIC lib.c lib.cpp)
cs_target_use_compile_profiles(lib both default_language cscmake_warnings)
cs_finalize_target(lib)
cs_finalize_project()
"""


def _commands(tmp_path: Path) -> dict[str, str]:
    """The compile command of each source, by file name."""
    files = {"lib.c": "int lib_c(void) { return 0; }\n", "lib.cpp": "int lib_cpp() { return 0; }\n"}
    result = configure(tmp_path, BODY, files, args=["-DCMAKE_EXPORT_COMPILE_COMMANDS=ON"])
    assert result.returncode == 0, result.output
    entries = json.loads((tmp_path / "build" / "compile_commands.json").read_text(encoding="utf-8"))
    return {Path(entry["file"]).name: entry["command"] for entry in entries}


def test_rules_apply_to_their_languages(tmp_path: Path) -> None:
    """LANGUAGES C CXX: both; no LANGUAGES: C++ only; the shipped warnings: the C++-only ones not on C."""
    commands = _commands(tmp_path)

    assert "-DCSTEST_BOTH_OPTION" in commands["lib.c"]
    assert "-DCSTEST_BOTH_OPTION" in commands["lib.cpp"]
    assert "CSTEST_CXX_ONLY" not in commands["lib.c"]
    assert "-DCSTEST_CXX_ONLY" in commands["lib.cpp"]
    assert "-Wall" in commands["lib.c"]
    assert "-Wold-style-cast" not in commands["lib.c"]
    assert "-Wold-style-cast" in commands["lib.cpp"]
