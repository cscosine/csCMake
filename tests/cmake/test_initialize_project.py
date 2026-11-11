"""cs_initialize_project: arguments, variables it sets (and does not leak), cache policy, messages."""

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
LIB = """
cs_add_library(lib INTERFACE)
cs_target_link_libraries(lib INTERFACE cstest::cscmake_base_include)
"""


def test_project_without_version_is_rejected(tmp_path: Path) -> None:
    result = configure(tmp_path, "project(noversion LANGUAGES NONE)\n" + INIT)

    assert result.returncode != 0
    assert "project(noversion VERSION <x.y.z> ...) is required" in result.output


@pytest.mark.parametrize(
    ("build_type", "message"),
    [
        ("", "CMAKE_BUILD_TYPE is empty: a single-config generator builds one configuration of the project"),
        ("MinSizeRel", "CMAKE_BUILD_TYPE MinSizeRel is not a configuration of the project"),
    ],
)
def test_a_single_config_build_type_must_be_a_configuration_of_the_project(
    tmp_path: Path, build_type: str, message: str
) -> None:
    result = configure(tmp_path, INIT, args=[f"-DCMAKE_BUILD_TYPE={build_type}"])

    assert result.returncode != 0
    assert message in " ".join(result.output.split())
    assert "(Debug, Release, RelWithDebInfo, Paranoid)" in " ".join(result.output.split())


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
    result = configure(tmp_path, INIT + report + "cstest_report(namespace ${CSCMAKE_NAMESPACE})\n")

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
"""
    )
    result = configure(tmp_path, body)

    assert result.returncode == 0, result.output
    assert result.reports["paranoid_postfix"] == "dp"
    # MAPPED_TO "RelWithDebInfo,Release," (trailing comma: trailing empty item, as given)
    assert result.report_list("map_variable") == ["RelWithDebInfo", "Release", ""]
    assert result.reports["map_cache"] == ""
    assert result.reports["runtime_cache"] == ""


def test_a_custom_configuration_copies_the_variables_defined_for_its_base(tmp_path: Path) -> None:
    """Paranoid is based on Debug: the C++ flags of Debug are copied (C++ is enabled), not the ones of the languages
    that are not (no empty cache entries for them)."""
    body = (
        "enable_language(CXX)\n"
        + INIT
        + LIB
        + """
cstest_report(cxx_debug "${CMAKE_CXX_FLAGS_DEBUG}")
cstest_report(cxx "$CACHE{CMAKE_CXX_FLAGS_PARANOID}")
get_property(fortran CACHE CMAKE_Fortran_FLAGS_PARANOID PROPERTY TYPE SET)
cstest_report(fortran "${fortran}")
"""
    )
    result = configure(tmp_path, body)

    assert result.returncode == 0, result.output
    assert result.reports["cxx"] == result.reports["cxx_debug"]
    assert result.reports["fortran"] == "0"


def test_defaults_can_be_overridden_from_the_command_line(tmp_path: Path) -> None:
    body = (
        INIT
        + LIB
        + """
get_target_property(postfix lib DEBUG_POSTFIX)
cstest_report(debug_postfix "${postfix}")
cstest_report(runtime_output "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}")
"""
    )
    out = (tmp_path / "custom-bin").as_posix()
    result = configure(tmp_path, body, args=["-DCSCMAKE_DEBUG_POSTFIX=_dbg", f"-DCMAKE_RUNTIME_OUTPUT_DIRECTORY={out}"])

    assert result.returncode == 0, result.output
    assert result.reports["debug_postfix"] == "_dbg"
    assert result.reports["runtime_output"] == out


@pytest.mark.parametrize(
    ("level", "verbose", "debug"),
    [(None, False, False), ("VERBOSE", True, False), ("DEBUG", True, True)],
    ids=["default", "verbose", "debug"],
)
def test_messages_follow_the_log_level(tmp_path: Path, level: str | None, verbose: bool, debug: bool) -> None:
    """VERBOSE: what csCMake does; DEBUG: the details. Nothing at the default level."""
    result = configure(tmp_path, INIT + LIB, args=[f"--log-level={level}"] if level else [])

    assert result.returncode == 0, result.output
    assert ("cstest: target lib (INTERFACE_LIBRARY)" in result.output) == verbose
    assert ("cstest: lib links INTERFACE cstest::cscmake_base_include" in result.output) == debug


def test_the_context_names_the_project_and_the_command(tmp_path: Path) -> None:
    """--log-context: [<namespace>.<command>]; sub-steps indented."""
    result = configure(tmp_path, INIT + LIB, args=["--log-level=DEBUG", "--log-context"])

    assert result.returncode == 0, result.output
    lines = result.output.splitlines()
    assert "-- [cstest.cs_add_library] cstest: target lib (INTERFACE_LIBRARY)" in lines
    assert "-- [cstest.cs_add_library]   default compile profiles of the folder: cscmake_default" in lines
    assert any(line.startswith("-- [cstest.finalize] cstest: finalizing the project") for line in lines)


def test_a_block_shows_the_messages_of_some_calls_only(tmp_path: Path) -> None:
    body = (
        INIT
        + "cs_add_library(quiet INTERFACE)\n"
        + "block()\n  set(CMAKE_MESSAGE_LOG_LEVEL VERBOSE)\n  cs_add_library(shown INTERFACE)\nendblock()\n"
    )
    result = configure(tmp_path, body)

    assert result.returncode == 0, result.output
    assert "cstest: target shown (INTERFACE_LIBRARY)" in result.output
    assert "target quiet" not in result.output


SUBPROJECT = """
project(sub VERSION 1.0.0 LANGUAGES NONE)
cs_initialize_project(NAMESPACE sub CXX_STANDARD 17 DEFAULT_CONFIG Debug)
add_subdirectory(lib)
"""
SUBPROJECT_LIB = """
cs_add_library(h INTERFACE)
cs_target_sources(h INTERFACE_INSTALL H.hpp)
cs_install_target(h COMPONENT h)
"""


def test_header_install_path_is_relative_to_the_project_folder(tmp_path: Path) -> None:
    """A csCMake project added with add_subdirectory installs its headers relative to its own folder."""
    files = {"sub/CMakeLists.txt": SUBPROJECT, "sub/lib/CMakeLists.txt": SUBPROJECT_LIB, "sub/lib/H.hpp": ""}
    result = configure(tmp_path, "add_subdirectory(sub)\n", files, args=["--log-level=DEBUG"])

    assert result.returncode == 0, result.output
    line = next(x for x in result.output.splitlines() if "H.hpp -> " in x)
    assert line.rstrip().endswith("-> include/lib/"), line


def test_prefix_and_module_path_head_and_tail(tmp_path: Path) -> None:
    body = (
        INIT
        + """
cstest_report(prefix "${CMAKE_PREFIX_PATH}")
cstest_report(module "${CMAKE_MODULE_PATH}")
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


def test_static_msvc_runtime_from_the_command_line(tmp_path: Path) -> None:
    """The runtime of a configuration is overridable; a custom configuration copies the one it is based on."""
    body = (
        INIT
        + LIB
        + """
get_target_property(runtime lib MSVC_RUNTIME_LIBRARY)
cstest_report(runtime "${runtime}")
"""
    )
    result = configure(tmp_path, body, args=["-DCSCMAKE_MSVC_RUNTIME_LIBRARY_DEBUG=MultiThreadedDebug"])

    assert result.returncode == 0, result.output
    runtime = result.reports["runtime"]
    assert "$<$<CONFIG:Debug>:MultiThreadedDebug>" in runtime
    assert "$<$<CONFIG:Paranoid>:MultiThreadedDebug>" in runtime  # Paranoid is based on Debug
    assert "$<$<CONFIG:Release>:MultiThreadedDLL>" in runtime


def test_the_c_compiler_of_the_presets_is_not_reported_unused(tmp_path: Path) -> None:
    """The presets give CMAKE_C_COMPILER, a project without C sources does not use it: no unused-cli warning."""
    result = configure(tmp_path, INIT + LIB, args=["-DCMAKE_C_COMPILER=cc"])

    assert result.returncode == 0, result.output
    assert "Manually-specified variables were not used" not in result.output


REPORT_LANGUAGE = """
cstest_report(standard "${CMAKE_CXX_STANDARD}")
cstest_report(required "${CMAKE_CXX_STANDARD_REQUIRED}")
cstest_report(extensions "${CMAKE_CXX_EXTENSIONS}")
cstest_report(compile_commands "${CMAKE_EXPORT_COMPILE_COMMANDS}")
"""


def test_language_and_compile_commands_defaults(tmp_path: Path) -> None:
    result = configure(tmp_path, INIT + REPORT_LANGUAGE)

    assert result.returncode == 0, result.output
    assert result.reports == {"standard": "17", "required": "ON", "extensions": "OFF", "compile_commands": "ON"}


def test_the_choices_of_the_project_win(tmp_path: Path) -> None:
    """Set by the project before cs_initialize_project (or on the command line): kept."""
    before = "set(CMAKE_CXX_STANDARD_REQUIRED OFF)\nset(CMAKE_CXX_EXTENSIONS ON)\n"

    result = configure(tmp_path, before + INIT + REPORT_LANGUAGE, args=["-DCMAKE_EXPORT_COMPILE_COMMANDS=OFF"])

    assert result.returncode == 0, result.output
    assert result.reports == {"standard": "17", "required": "OFF", "extensions": "ON", "compile_commands": "OFF"}


def test_a_target_before_initialize_is_rejected(tmp_path: Path) -> None:
    result = configure(tmp_path, "cs_add_library(lib INTERFACE)\n")

    assert result.returncode != 0
    assert "lib: call cs_initialize_project(NAMESPACE ...) before adding targets" in " ".join(result.output.split())
