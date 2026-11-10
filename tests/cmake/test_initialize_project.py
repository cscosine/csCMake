"""cs_initialize_project: arguments, variables it sets (and does not leak), cache policy, debug messages."""

from __future__ import annotations

from pathlib import Path

import pytest

from tests.cmake.cmake_project import configure

pytestmark = pytest.mark.requires("cmake", "ninja")

INIT = """
cs_initialize_project(
  NAMESPACE cstest
  CXX_STANDARD 17
  DEFAULT_CONFIG Debug Release
  DEFAULT_CONFIG_MAPPED RelWithDebInfo MAPPED_TO "RelWithDebInfo,Release,"
  CUSTOM_CONFIG Paranoid BASED_ON "Debug,Release," POSTFIX "dp")
"""
FINALIZE = "cs_finalize_project()\n"
LIB = """
cs_add_library(lib INTERFACE)
cs_target_link_libraries(lib INTERFACE cstest::cscmake_base_include)
cs_finalize_target(lib)
"""


def test_project_without_version_is_rejected(tmp_path: Path) -> None:
    result = configure(tmp_path, "project(noversion LANGUAGES NONE)\n" + INIT)

    assert result.returncode != 0
    assert "project(noversion VERSION <x.y.z> ...) is required" in result.output


def test_no_temporary_variable_leaks_into_the_project_scope(tmp_path: Path) -> None:
    names = [
        "_cs_init_multi_config",
        "_cs_init_config_subfolder",
        "_cs_init_cxx_standard",
        "generator_is_multi_config",
        "required_cxx_standard",
        "temp_var_list",
    ]
    report = "".join(f'if(DEFINED {n})\n  cstest_report(leaked "{n}")\nendif()\n' for n in names)
    result = configure(tmp_path, INIT + report + "cstest_report(namespace ${CSCMAKE_NAMESPACE})\n" + FINALIZE)

    assert result.returncode == 0, result.output
    assert "leaked" not in result.reports
    assert result.reports["namespace"] == "cstest"


def test_derived_values_are_project_variables_not_cache(tmp_path: Path) -> None:
    body = (
        INIT
        + LIB
        + """
get_target_property(postfix lib PARANOID_POSTFIX)
cstest_report(paranoid_postfix "${postfix}")
cstest_report(map_variable "${CMAKE_MAP_IMPORTED_CONFIG_RELWITHDEBINFO}")
cstest_report(map_cache "$CACHE{CMAKE_MAP_IMPORTED_CONFIG_RELWITHDEBINFO}")
cstest_report(runtime_cache "$CACHE{CSCMAKE_MSVC_RUNTIME_LIBRARY_GENERATOR_EXPRESSION}")
cs_finalize_project()
"""
    )
    result = configure(tmp_path, body)

    assert result.returncode == 0, result.output
    assert result.reports["paranoid_postfix"] == "dp"
    # MAPPED_TO "RelWithDebInfo,Release," (trailing comma: trailing empty item, as given)
    assert result.report_list("map_variable") == ["RelWithDebInfo", "Release", ""]
    assert result.reports["map_cache"] == ""
    assert result.reports["runtime_cache"] == ""


def test_defaults_can_be_overridden_from_the_command_line(tmp_path: Path) -> None:
    body = (
        INIT
        + LIB
        + """
get_target_property(postfix lib DEBUG_POSTFIX)
cstest_report(debug_postfix "${postfix}")
cstest_report(runtime_output "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}")
cs_finalize_project()
"""
    )
    out = (tmp_path / "custom-bin").as_posix()
    result = configure(tmp_path, body, args=["-DCSCMAKE_DEBUG_POSTFIX=_dbg", f"-DCMAKE_RUNTIME_OUTPUT_DIRECTORY={out}"])

    assert result.returncode == 0, result.output
    assert result.reports["debug_postfix"] == "_dbg"
    assert result.reports["runtime_output"] == out


@pytest.mark.parametrize("debug", [False, True], ids=["default", "debug-on"])
def test_debug_messages_only_with_the_project_option(tmp_path: Path, debug: bool) -> None:
    result = configure(tmp_path, INIT + LIB + FINALIZE, args=["-Dcstest_CSCMAKE_DEBUG=ON"] if debug else [])

    assert result.returncode == 0, result.output
    assert ("[cs_target_link_libraries]" in result.output) == debug


def test_missing_imported_file_is_a_warning(tmp_path: Path) -> None:
    body = (
        INIT
        + """
add_library(ext SHARED IMPORTED)
set_target_properties(ext PROPERTIES IMPORTED_LOCATION_DEBUG ${CMAKE_CURRENT_SOURCE_DIR}/missing.so)
cs_add_library(lib INTERFACE)
cs_target_link_libraries(lib INTERFACE ext)
cs_finalize_target(lib)
cs_finalize_project()
"""
    )
    result = configure(tmp_path, body)

    assert result.returncode == 0, result.output
    assert "CMake Warning" in result.output
    assert "missing.so does not exist" in " ".join(result.output.split())  # CMake wraps warnings


SUBPROJECT = """
project(sub VERSION 1.0.0 LANGUAGES NONE)
cs_initialize_project(NAMESPACE sub CXX_STANDARD 17 DEFAULT_CONFIG Debug)
add_subdirectory(lib)
cs_finalize_project()
"""
SUBPROJECT_LIB = """
cs_add_library(h INTERFACE)
cs_target_sources(h INTERFACE_INSTALL H.hpp)
cs_install_target(h h)
cs_finalize_target(h)
"""


def test_header_install_path_is_relative_to_the_project_folder(tmp_path: Path) -> None:
    """A csCMake project added with add_subdirectory installs its headers relative to its own folder."""
    files = {"sub/CMakeLists.txt": SUBPROJECT, "sub/lib/CMakeLists.txt": SUBPROJECT_LIB, "sub/lib/H.hpp": ""}
    result = configure(tmp_path, "add_subdirectory(sub)\n", files, args=["-Dsub_CSCMAKE_DEBUG=ON"])

    assert result.returncode == 0, result.output
    line = next(x for x in result.output.splitlines() if "[cs_install_target] install" in x and "H.hpp" in x)
    assert line.rstrip().endswith("to include/lib/"), line


def test_prefix_and_module_path_head_and_tail(tmp_path: Path) -> None:
    body = (
        INIT
        + """
cstest_report(prefix "${CMAKE_PREFIX_PATH}")
cstest_report(module "${CMAKE_MODULE_PATH}")
cs_finalize_project()
"""
    )
    args = [
        "-DCSCMAKE_PREFIX_PATH_HEAD=/head",
        "-DCMAKE_PREFIX_PATH=/middle",
        "-DCSCMAKE_PREFIX_PATH_TAIL=/tail1;/tail2",
        "-DCSCMAKE_MODULE_PATH_TAIL=/module_tail",
    ]
    result = configure(tmp_path, body, args=args)

    assert result.returncode == 0, result.output
    assert result.report_list("prefix") == ["/head", "/middle", "/tail1", "/tail2"]
    assert result.report_list("module")[-1] == "/module_tail"
    assert "" not in result.report_list("module")
