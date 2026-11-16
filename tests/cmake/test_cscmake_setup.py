"""cs_macos_deployment_target: the deployment target of a csCMake project, before project() (csCMakeSetup.cmake).

These projects write their own CMakeLists.txt: the call comes before project(), which the shared header has."""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

import pytest

from tests.cmake.cmake_project import REPO_ROOT, Configured

pytestmark = pytest.mark.requires("cmake", "ninja")

macos_only = pytest.mark.skipif(sys.platform != "darwin", reason="the deployment target is set on a macOS host only")

TOP = """cmake_minimum_required(VERSION 3.31)
include(csCMakeSetup)
cs_macos_deployment_target({version})
project(cstest VERSION 1.0.0 LANGUAGES NONE)
message(STATUS "CSTEST target=${{CMAKE_OSX_DEPLOYMENT_TARGET}}")
"""


def _configure(
    project: Path, cmakelists: str, args: list[str] | None = None, env: dict[str, str] | None = None
) -> Configured:
    project.mkdir(parents=True, exist_ok=True)
    (project / "CMakeLists.txt").write_text(cmakelists, encoding="utf-8")
    result = subprocess.run(
        [
            "cmake",
            "-S",
            str(project),
            "-B",
            str(project / "build"),
            "-G",
            "Ninja",
            f"-DCMAKE_MODULE_PATH={REPO_ROOT.as_posix()}",
            *(args or []),
        ],
        capture_output=True,
        text=True,
        check=False,
        env=env,
    )
    return Configured(result.returncode, result.stdout + result.stderr)


def _text(result: Configured) -> str:
    return " ".join(result.output.split())


def test_after_project_fails(tmp_path: Path) -> None:
    """After project() the compilers are set up with another value: the call says where it goes (any host)."""
    cmakelists = (
        "cmake_minimum_required(VERSION 3.31)\nproject(cstest LANGUAGES NONE)\ninclude(csCMakeSetup)\n"
        "cs_macos_deployment_target(14.4)\n"
    )
    result = _configure(tmp_path, cmakelists)

    assert result.returncode != 0
    assert "call it before project()" in _text(result)


def test_a_second_configure_passes(tmp_path: Path) -> None:
    """The cache of the first configure (CMAKE_PROJECT_NAME) does not look like a project() before the call."""
    assert _configure(tmp_path, TOP.format(version="14.4")).returncode == 0
    result = _configure(tmp_path, TOP.format(version="14.4"))

    assert result.returncode == 0, result.output


def test_not_a_version_fails(tmp_path: Path) -> None:
    result = _configure(tmp_path, TOP.format(version="fourteen"))

    assert result.returncode != 0
    assert "a macOS version is expected" in _text(result)


@pytest.mark.skipif(sys.platform == "darwin", reason="the other hosts")
def test_nothing_on_other_hosts(tmp_path: Path) -> None:
    result = _configure(tmp_path, TOP.format(version="14.4"))

    assert result.returncode == 0, result.output
    assert result.reports["target"] == ""


@macos_only
def test_sets_the_value(tmp_path: Path) -> None:
    result = _configure(tmp_path, TOP.format(version="14.4"))

    assert result.returncode == 0, result.output
    assert result.reports["target"] == "14.4"


@macos_only
@pytest.mark.parametrize(("given", "expected"), [("15", "15"), ("14.4", "14.4"), ("13.3", None)])
def test_the_build_may_raise_it_never_lower_it(tmp_path: Path, given: str, expected: str | None) -> None:
    result = _configure(tmp_path, TOP.format(version="14.4"), args=[f"-DCMAKE_OSX_DEPLOYMENT_TARGET={given}"])

    if expected is None:
        assert result.returncode != 0
        assert "needs macOS 14.4 or newer, the build is given macOS 13.3" in _text(result)
    else:
        assert result.returncode == 0, result.output
        assert result.reports["target"] == expected


@macos_only
def test_the_environment_is_a_given_value(tmp_path: Path) -> None:
    env = {**os.environ, "MACOSX_DEPLOYMENT_TARGET": "13.0"}
    result = _configure(tmp_path, TOP.format(version="14.4"), env=env)

    assert result.returncode != 0
    assert "the build is given macOS 13.0" in _text(result)


@macos_only
def test_a_changed_call_replaces_its_earlier_value(tmp_path: Path) -> None:
    """The cache keeps the value of an earlier configure: the call replaces its own value (it is not a given one)."""
    assert _configure(tmp_path, TOP.format(version="14.4")).returncode == 0
    result = _configure(tmp_path, TOP.format(version="15"))

    assert result.returncode == 0, result.output
    assert result.reports["target"] == "15"


@pytest.mark.parametrize(("nested", "fails"), [("15", True), ("14", False)])
def test_nested_project_checks_the_build(tmp_path: Path, nested: str, fails: bool) -> None:
    """A project added with add_subdirectory has the value of the top-level one: its call only checks it."""
    top = "cmake_minimum_required(VERSION 3.31)\nproject(top LANGUAGES NONE)\nadd_subdirectory(sub)\n"
    sub = tmp_path / "sub"
    sub.mkdir(parents=True)
    (sub / "CMakeLists.txt").write_text(
        f"include(csCMakeSetup)\ncs_macos_deployment_target({nested})\nproject(sub LANGUAGES NONE)\n", encoding="utf-8"
    )
    result = _configure(tmp_path, top, args=["-DCMAKE_OSX_DEPLOYMENT_TARGET=14.4"])

    assert (result.returncode != 0) == fails, result.output
    if fails:
        assert "needs macOS 15 or newer, the build is for macOS 14.4" in _text(result)
