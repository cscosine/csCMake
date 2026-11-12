"""The project setup of the presets, resolved by CMake: the levels of "Choosing the project setup" (user guide)."""

from __future__ import annotations

import json
import platform
import subprocess
from pathlib import Path

import pytest

from tests.cmake.cmake_project import REPO_ROOT

pytestmark = pytest.mark.requires("cmake", "ninja")

PRESETS = REPO_ROOT / "presets"
OS_PRESET = {"Linux": "linux", "Windows": "windows", "Darwin": "macos"}[platform.system()]
CMAKELISTS = """cmake_minimum_required(VERSION 3.31)
project(cstest LANGUAGES NONE)
message(STATUS "CSTEST os=${CSTEST_OS}")
message(STATUS "CSTEST prefix=${CMAKE_PREFIX_PATH}")
message(STATUS "CSTEST value=${CSTEST_VALUE}")
message(STATUS "CSTEST binary=${CMAKE_BINARY_DIR}")
"""
# a setup of the project, as a layout defines it
OWN_SETUP = {
    "name": "cscmake-project-setup",
    "hidden": True,
    "inherits": "cscmake-common-project-setup",
    "environment": {
        "CSCMAKE_WORKSPACE_ROOT": "${sourceParentDir}",
        "CSCMAKE_ROOT": REPO_ROOT.as_posix(),
        "CSCMAKE_BUILD_SUB_DIR": "$env{CSCMAKE_CSV1_SUB_DIR}",
    },
}


def _os_preset(os: str) -> dict[str, object]:
    return {
        "name": f"cscmake-project-setup-{os}",
        "hidden": True,
        "cacheVariables": {"CSTEST_OS": os, "CMAKE_PREFIX_PATH": f"/{os}"},
    }


def _project(tmp_path: Path, setup: dict[str, object]) -> Path:
    project = tmp_path / "project"
    project.mkdir()
    (project / "CMakeLists.txt").write_text(CMAKELISTS, encoding="utf-8")
    presets = {"version": 10, "include": [(PRESETS / "csv1" / "cs-presets-all.json").as_posix()]}
    (project / "CMakePresets.json").write_text(json.dumps(presets), encoding="utf-8")
    (project / "csCMakeProjectSetup.json").write_text(json.dumps({"version": 10, **setup}), encoding="utf-8")
    return project


def _cmake(project: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(["cmake", *args], cwd=project, capture_output=True, text=True, check=False, timeout=120)


def _host_presets(project: Path) -> list[str]:
    """The configure presets of the host (`cmake --list-presets`); fails if the presets do not resolve."""
    result = _cmake(project, "--list-presets")
    assert result.returncode == 0, result.stdout + result.stderr
    return [line.split('"')[1] for line in result.stdout.splitlines() if line.strip().startswith('"')]


def test_a_layout_resolves(tmp_path: Path) -> None:
    project = _project(tmp_path, {"include": [(PRESETS / "layout" / "sibling.json").as_posix()]})

    assert _host_presets(project)


def test_only_the_variant_presets_are_listed(tmp_path: Path) -> None:
    """The presets of the project setup are only inherited: the host lists the csv1 presets of the variants only."""
    project = _project(tmp_path, {"include": [(PRESETS / "layout" / "sibling.json").as_posix()]})

    assert all(name.startswith("csv1-") for name in _host_presets(project)), _host_presets(project)


def test_values_of_the_project_for_every_variant(tmp_path: Path) -> None:
    """The project includes csCMakeProjectSetup.json (the empty OS presets) and defines only cscmake-project-setup."""
    own = {**OWN_SETUP, "cacheVariables": {"CSTEST_VALUE": "every"}}
    setup = {"include": [(PRESETS / "csCMakeProjectSetup.json").as_posix()], "configurePresets": [own]}
    project = _project(tmp_path, setup)

    result = _cmake(project, "--preset", _host_presets(project)[0])

    assert result.returncode == 0, result.stdout + result.stderr
    assert "-- CSTEST value=every" in result.stdout
    assert f"-- CSTEST binary={tmp_path.as_posix()}/build/" in result.stdout  # the workspace folders


def test_folders_of_the_project(tmp_path: Path) -> None:
    """cscmake-project-setup without cscmake-common-project-setup: the folders of the project, the variant names from
    the environment of the variant presets."""
    own = {
        "name": "cscmake-project-setup",
        "hidden": True,
        "binaryDir": "${sourceDir}/out/$env{CSCMAKE_CSV1_SUB_DIR}/$env{CSCMAKE_CSV1_SINGLE_CONFIG_SUB_DIR}",
        "cacheVariables": {"CMAKE_PREFIX_PATH": "/deps/$env{CSCMAKE_CSV1_SUB_DIR}"},
    }
    setup = {"include": [(PRESETS / "csCMakeProjectSetup.json").as_posix()], "configurePresets": [own]}
    project = _project(tmp_path, setup)
    preset = _host_presets(project)[0]

    result = _cmake(project, "--preset", preset)

    assert result.returncode == 0, result.stdout + result.stderr
    variant = preset.removesuffix("-debug").removesuffix("-release").removesuffix("-relwithdebinfo")
    variant = variant.removesuffix("-paranoid")
    assert f"-- CSTEST binary={project.as_posix()}/out/{variant}" in result.stdout
    assert f"-- CSTEST prefix=/deps/{variant}" in result.stdout


def test_the_os_presets_of_the_project_win(tmp_path: Path) -> None:
    """The project includes csCMakeProjectSetup-common.json and defines the OS presets: the one of the host sets its
    values, before cscmake-project-setup and cscmake-common-project-setup (here, CMAKE_PREFIX_PATH)."""
    setup = {
        "include": [(PRESETS / "csCMakeProjectSetup-common.json").as_posix()],
        "configurePresets": [OWN_SETUP, *(_os_preset(os) for os in ("linux", "macos", "windows"))],
    }
    project = _project(tmp_path, setup)
    preset = _host_presets(project)[0]

    result = _cmake(project, "--preset", preset)

    assert result.returncode == 0, result.stdout + result.stderr
    assert f"-- CSTEST os={OS_PRESET}" in result.stdout
    assert f"-- CSTEST prefix=/{OS_PRESET}" in result.stdout


def test_os_presets_of_the_project_next_to_the_empty_ones_are_duplicates(tmp_path: Path) -> None:
    setup = {
        "include": [(PRESETS / "csCMakeProjectSetup.json").as_posix()],
        "configurePresets": [OWN_SETUP, _os_preset(OS_PRESET)],
    }
    project = _project(tmp_path, setup)

    result = _cmake(project, "--list-presets")

    assert result.returncode != 0
    assert "Duplicate preset" in result.stderr
