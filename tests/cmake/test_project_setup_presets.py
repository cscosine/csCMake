"""The project setup of the presets, resolved by CMake: the levels of "Choosing the project setup" (user guide)."""

from __future__ import annotations

import json
import platform
import subprocess
from pathlib import Path

import pytest

from cscmake.presets.registry import (
    OS,
    BuildConfig,
    Generator,
    GeneratorType,
    create_context_os_architecture_compiler_generator_string,
    get_supported_context_os_architecture_list,
)
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
# the generators of the configure tests: single-config (a folder per build type) and multi-config
GENERATORS = (Generator.NINJA, Generator.NINJA_MULTI)
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


def _variant_preset(project: Path, generator: Generator) -> tuple[str, str, str]:
    """The first variant of the host with ``generator`` in the registry: (configure preset, variant, folder of the
    build type), the preset listed by CMake.

    The Ninja generators configure on every host: the Visual Studio ones (an installed Visual Studio of their version)
    run in the smoke workflow.
    """
    ctx = next(
        ctx
        for ctx in get_supported_context_os_architecture_list()
        if ctx.context_os_architecture.os == OS(OS_PRESET)
        and ctx.context_compiler_generator.build_generator.generator == generator
    )
    variant = create_context_os_architecture_compiler_generator_string(ctx)
    single_config = ctx.context_compiler_generator.build_generator.generator_type == GeneratorType.SINGLE_CONFIG
    config = BuildConfig.DEBUG.value if single_config else ""
    preset = f"{variant}-{config}" if config else variant
    assert preset in _host_presets(project), preset
    return preset, variant, config


def _binary(root: str, config: str) -> str:
    """The CMAKE_BINARY_DIR line of a build folder ending with the folder of the build type (none: multi-config)."""
    return f"-- CSTEST binary={root}/{config}".removesuffix("/")


def test_a_layout_resolves(tmp_path: Path) -> None:
    project = _project(tmp_path, {"include": [(PRESETS / "layout" / "sibling.json").as_posix()]})

    assert _host_presets(project)


def test_only_the_variant_presets_are_listed(tmp_path: Path) -> None:
    """The presets of the project setup are only inherited: the host lists the csv1 presets of the variants only."""
    project = _project(tmp_path, {"include": [(PRESETS / "layout" / "sibling.json").as_posix()]})

    assert all(name.startswith("csv1-") for name in _host_presets(project)), _host_presets(project)


@pytest.mark.parametrize("generator", GENERATORS, ids=[g.value for g in GENERATORS])
def test_values_of_the_project_for_every_variant(tmp_path: Path, generator: Generator) -> None:
    """The project includes csCMakeProjectSetup.json (the empty OS presets) and defines only cscmake-project-setup."""
    own = {**OWN_SETUP, "cacheVariables": {"CSTEST_VALUE": "every"}}
    setup = {"include": [(PRESETS / "csCMakeProjectSetup.json").as_posix()], "configurePresets": [own]}
    project = _project(tmp_path, setup)
    preset, variant, config = _variant_preset(project, generator)

    result = _cmake(project, "--preset", preset)

    assert result.returncode == 0, result.stdout + result.stderr
    assert "-- CSTEST value=every" in result.stdout
    # the workspace folders
    assert _binary(f"{tmp_path.as_posix()}/build/{variant}/project", config) in result.stdout.splitlines()


@pytest.mark.parametrize("generator", GENERATORS, ids=[g.value for g in GENERATORS])
def test_folders_of_the_project(tmp_path: Path, generator: Generator) -> None:
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
    preset, variant, config = _variant_preset(project, generator)

    result = _cmake(project, "--preset", preset)

    assert result.returncode == 0, result.stdout + result.stderr
    assert _binary(f"{project.as_posix()}/out/{variant}", config) in result.stdout.splitlines()
    assert f"-- CSTEST prefix=/deps/{variant}" in result.stdout


@pytest.mark.parametrize("generator", GENERATORS, ids=[g.value for g in GENERATORS])
def test_the_os_presets_of_the_project_win(tmp_path: Path, generator: Generator) -> None:
    """The project includes csCMakeProjectSetup-common.json and defines the OS presets: the one of the host sets its
    values, before cscmake-project-setup and cscmake-common-project-setup (here, CMAKE_PREFIX_PATH)."""
    setup = {
        "include": [(PRESETS / "csCMakeProjectSetup-common.json").as_posix()],
        "configurePresets": [OWN_SETUP, *(_os_preset(os) for os in ("linux", "macos", "windows"))],
    }
    project = _project(tmp_path, setup)
    preset, _, _ = _variant_preset(project, generator)

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
