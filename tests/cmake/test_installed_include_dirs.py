"""The include folders of an installed package, for its consumers (csBaseInclude.cmake, cscmake_base_include)."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

from tests.cmake.cmake_project import configure, install

pytestmark = pytest.mark.requires("cmake", "ninja")

# a header-only package; installed in Debug only (configure() builds Debug)
PACKAGE = """
cs_initialize_project(NAMESPACE pkg CXX_STANDARD 17 DEFAULT_CONFIG {configs})
cs_add_library(lib INTERFACE)
cs_target_sources(lib PRIVATE_INSTALL pkg/lib.hpp)
cs_target_link_libraries(lib INTERFACE pkg::cscmake_base_include)
cs_install_target(lib COMPONENT lib DEFAULT)
cs_finalize_target(lib)
cs_finalize_project()
"""
HEADER = {"pkg/lib.hpp": "#pragma once\ninline int lib() { return 42; }\n"}
CONSUMER = """
enable_language(CXX)
find_package(pkg REQUIRED CONFIG)
add_executable(app main.cpp)
target_link_libraries(app PRIVATE pkg::lib)
"""
MAIN = {"main.cpp": "#include <pkg/lib.hpp>\nint main() { return lib() == 42 ? 0 : 1; }\n"}


def _package(tmp_path: Path, configs: str) -> Path:
    prefix = tmp_path / "install"
    result = install(tmp_path / "pkg", PACKAGE.format(configs=configs), prefix, HEADER)
    assert result.returncode == 0, result.output
    return prefix


def _exported_include_dirs(prefix: Path) -> str:
    targets = (prefix / "lib" / "cmake" / "pkg" / "targets" / "cscmake_commonTargets.cmake").read_text(encoding="utf-8")
    line = next(line for line in targets.splitlines() if "INTERFACE_INCLUDE_DIRECTORIES" in line)
    return line.split(None, 1)[1]


def test_one_configuration_exports_the_include_folder(tmp_path: Path) -> None:
    prefix = _package(tmp_path, "Debug")

    assert _exported_include_dirs(prefix) == '"${_IMPORT_PREFIX}/include"'
    assert (prefix / "include" / "pkg" / "lib.hpp").is_file()


def test_several_configurations_export_one_folder_per_configuration(tmp_path: Path) -> None:
    prefix = _package(tmp_path, "Debug Release")

    assert _exported_include_dirs(prefix) == (
        '"\\$<\\$<CONFIG:Debug>:${_IMPORT_PREFIX}/include/Debug>;'
        '\\$<\\$<CONFIG:Release>:${_IMPORT_PREFIX}/include/Release>"'
    )
    assert (prefix / "include" / "Debug" / "pkg" / "lib.hpp").is_file()


@pytest.mark.skipif(sys.platform == "win32", reason="needs a C++ compiler environment")
@pytest.mark.parametrize("mapped", [False, True], ids=["not-mapped", "mapped"])
def test_a_consumer_configuration_the_package_does_not_have(tmp_path: Path, mapped: bool) -> None:
    """A MinSizeRel consumer of a package installed in Debug only: generates (no missing folder); with the configuration
    mapped (CMAKE_MAP_IMPORTED_CONFIG_MINSIZEREL), it gets the headers of the mapped configuration."""
    prefix = _package(tmp_path, "Debug Release")
    args = [f"-DCMAKE_PREFIX_PATH={prefix.as_posix()}", "-DCMAKE_BUILD_TYPE=MinSizeRel"]
    if mapped:
        args.append("-DCMAKE_MAP_IMPORTED_CONFIG_MINSIZEREL=Debug")

    result = configure(tmp_path / "consumer", CONSUMER, MAIN, args=args)

    assert result.returncode == 0, result.output
    build_rules = (tmp_path / "consumer" / "build" / "build.ninja").read_text(encoding="utf-8")
    assert ("install/include/Debug" in build_rules) == mapped
