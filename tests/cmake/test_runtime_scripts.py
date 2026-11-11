"""The run-time environment scripts of the build: cs-env.bat / cs-env.ps1 in its top build folder.

Only their text is checked here (the scripts run in the Windows smoke test, tests/smoke/run_smoke.py).
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

from tests.cmake.cmake_project import configure

pytestmark = pytest.mark.requires("cmake", "ninja")

INIT = "cs_initialize_project(NAMESPACE cstest CXX_STANDARD 17 DEFAULT_CONFIG Debug)\n"
SCRIPTS_ON = ["-DCSCMAKE_RUNTIME_SCRIPTS=ON"]
SOURCES = {"main.cpp": "int main() { return 0; }\n", "lib.cpp": "int lib() { return 0; }\n"}
needs_compiler = pytest.mark.skipif(sys.platform == "win32", reason="needs a C++ compiler environment")


def _text(path: Path) -> list[str]:
    """The lines of a generated script; they are all CRLF."""
    data = path.read_bytes()
    assert data.count(b"\n") == data.count(b"\r\n"), f"{path}: not CRLF only"
    return data.decode("utf-8").splitlines()


@pytest.mark.parametrize(
    ("args", "written"),
    [([], sys.platform == "win32"), (["-DCSCMAKE_RUNTIME_SCRIPTS=OFF"], False), (SCRIPTS_ON, True)],
    ids=["default", "off", "on"],
)
def test_written_on_windows_or_when_asked(tmp_path: Path, args: list[str], written: bool) -> None:
    """Default: on Windows only (elsewhere the RPATH runs the build tree); CSCMAKE_RUNTIME_SCRIPTS chooses."""
    result = configure(tmp_path, INIT, args=args)

    assert result.returncode == 0, result.output
    build = tmp_path / "build"
    for name in ("cs-env.bat", "cs-env.ps1", "cs-env/Debug.bat", "cs-env/Debug.ps1"):
        assert (build / name).is_file() == written, name


@needs_compiler
def test_path_and_variables_of_every_program_and_shared_library(tmp_path: Path) -> None:
    """PATH: the folders of every executable and shared library once (a "," kept, a per-configuration folder
    evaluated), before %PATH%; the variables once each, written as given (";" kept; "'" doubled for PowerShell).
    An INTERFACE library has no run-time environment of its own: not in the scripts."""
    body = (
        "enable_language(CXX)\n"
        + INIT
        + """
cs_add_executable(app main.cpp)
cs_add_library(lib SHARED lib.cpp)
cs_add_library(headers INTERFACE)
cs_target_runtime_environment(app PATH /opt/a,b "$<$<CONFIG:Release>:/release>" SET "LIST=x;y" "QUOTE=it's")
cs_target_runtime_environment(lib PATH /opt/a,b /opt/lib SET "LIST=x;y")
cs_target_runtime_environment(headers PATH /opt/headers SET HEADERS=1)
"""
    )
    result = configure(tmp_path, body, SOURCES, args=SCRIPTS_ON)

    assert result.returncode == 0, result.output
    env = tmp_path / "build" / "cs-env"
    assert _text(env / "Debug.bat")[1:] == [
        '@set "PATH=/opt/a,b;/opt/lib;%PATH%"',
        '@set "LIST=x;y"',
        '@set "QUOTE=it\'s"',
    ]
    assert _text(env / "Debug.ps1")[1:] == [
        "$env:PATH = '/opt/a,b;/opt/lib;' + $env:PATH",
        "$env:LIST = 'x;y'",
        "$env:QUOTE = 'it''s'",
    ]


@needs_compiler
def test_no_path_line_without_folders(tmp_path: Path) -> None:
    body = "enable_language(CXX)\n" + INIT + "cs_add_executable(app main.cpp)\n"
    result = configure(tmp_path, body, SOURCES, args=SCRIPTS_ON)

    assert result.returncode == 0, result.output
    assert len(_text(tmp_path / "build" / "cs-env" / "Debug.bat")) == 1


@needs_compiler
def test_a_variable_with_two_values_fails(tmp_path: Path) -> None:
    body = (
        "enable_language(CXX)\n"
        + INIT
        + """
cs_add_executable(app main.cpp)
cs_add_library(lib SHARED lib.cpp)
cs_target_runtime_environment(app SET MODE=a)
cs_target_runtime_environment(lib SET MODE=b)
"""
    )
    result = configure(tmp_path, body, SOURCES, args=SCRIPTS_ON)

    assert result.returncode != 0
    output = " ".join(result.output.split())
    assert "app sets MODE=a, lib sets MODE=b; one value per variable for the whole build" in output


@needs_compiler
def test_one_pair_of_scripts_for_the_build_in_its_top_folder(tmp_path: Path) -> None:
    """A top folder without csCMake project, two csCMake projects in subfolders: their targets are in the scripts of
    the top build folder (next to the .sln with Visual Studio)."""
    project = (
        "project({name} VERSION 1.0.0 LANGUAGES CXX)\n"
        "cs_initialize_project(NAMESPACE {name} CXX_STANDARD 17 DEFAULT_CONFIG Debug)\n"
        "cs_add_executable({name}_app main.cpp)\n"
        "cs_target_runtime_environment({name}_app PATH /opt/{name})\n"
    )
    files = {
        "one/CMakeLists.txt": project.format(name="one"),
        "two/CMakeLists.txt": project.format(name="two"),
        "one/main.cpp": SOURCES["main.cpp"],
        "two/main.cpp": SOURCES["main.cpp"],
    }
    result = configure(tmp_path, "add_subdirectory(one)\nadd_subdirectory(two)\n", files, args=SCRIPTS_ON)

    assert result.returncode == 0, result.output
    build = tmp_path / "build"
    assert _text(build / "cs-env" / "Debug.bat")[1] == '@set "PATH=/opt/one;/opt/two;%PATH%"'
    assert not list((build / "one").rglob("cs-env*"))


def test_the_scripts_list_the_configurations_of_the_build(tmp_path: Path) -> None:
    """Single-config generator: the configuration of the build only."""
    result = configure(tmp_path, INIT.replace("Debug", "Debug Release"), args=SCRIPTS_ON)

    assert result.returncode == 0, result.output
    build = tmp_path / "build"
    assert 'set "_cs_env_configs=Debug"' in _text(build / "cs-env.bat")
    assert "    $configs = @('Debug')" in _text(build / "cs-env.ps1")


def test_the_scripts_are_reported(tmp_path: Path) -> None:
    result = configure(tmp_path, INIT, args=[*SCRIPTS_ON, "--log-level=VERBOSE"])

    assert result.returncode == 0, result.output
    build = (tmp_path / "build").as_posix()
    expected = f"run-time environment scripts: {build}/cs-env.bat, cs-env.ps1 (configurations Debug)"
    assert expected in result.output
