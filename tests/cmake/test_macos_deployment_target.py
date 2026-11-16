"""The checks on the packages found (cs_after_find_dependency, cs_add_after_find_hook) and the macOS deployment target:
recorded in the installed package, checked on the packages found, Qt through the hook of csQt (csFindPackage.cmake,
csMacosDeploymentTarget.cmake, csRecordMacosDeploymentTarget.cmake, csQt.cmake).

Configure only, on any system: the checks compare CMAKE_OSX_DEPLOYMENT_TARGET when it is set (-D here), whatever the
system; the packages are stand-ins (a Config file, the recorded file, a Qt6Config.cmake with the variables of Qt)."""

from __future__ import annotations

import subprocess
from pathlib import Path

import pytest

from tests.cmake.cmake_project import REPO_ROOT, Configured, configure, install

pytestmark = pytest.mark.requires("cmake", "ninja")

INIT = "cs_initialize_project(NAMESPACE cstest CXX_STANDARD 17 DEFAULT_CONFIG Debug)\n"


def _text(result: Configured) -> str:
    """The output with the line breaks of CMake's messages joined."""
    return " ".join(result.output.split())


def _target(version: str | None) -> list[str]:
    return [f"-DCMAKE_OSX_DEPLOYMENT_TARGET={version}"] if version else []


def _package(prefix: Path, name: str, recorded: str | None) -> None:
    """A package stand-in in prefix: lib/cmake/<name>/<name>Config.cmake, and the recorded deployment target."""
    config_dir = prefix / "lib" / "cmake" / name
    config_dir.mkdir(parents=True)
    (config_dir / f"{name}Config.cmake").write_text(f"set({name}_VERSION 1.0)\n", encoding="utf-8")
    if recorded:
        (prefix / "share" / "cscmake").mkdir(parents=True)
        # the project name of a third-party library may differ in case from its package name
        (prefix / "share" / "cscmake" / f"{name.lower()}.macos-deployment-target").write_text(
            f"{recorded}\n", encoding="utf-8"
        )


def _qt(prefix: Path, min_macos: str) -> Path:
    """A Qt stand-in: Qt6Config.cmake with a Qt command, Qt6ConfigExtras.cmake with the macOS minimum of Qt."""
    config_dir = prefix / "lib" / "cmake" / "Qt6"
    config_dir.mkdir(parents=True)
    (config_dir / "Qt6ConfigExtras.cmake").write_text(
        f'if(NOT QT_SUPPORTED_MIN_MACOS_VERSION)\n  set(QT_SUPPORTED_MIN_MACOS_VERSION "{min_macos}")\nendif()\n',
        encoding="utf-8",
    )
    (config_dir / "Qt6Config.cmake").write_text(
        'set(Qt6_VERSION 6.12.0)\ninclude("${CMAKE_CURRENT_LIST_DIR}/Qt6ConfigExtras.cmake")\n'
        "function(qt6_add_executable)\nendfunction()\n",
        encoding="utf-8",
    )
    return config_dir


@pytest.mark.parametrize(
    ("project", "required", "fails"),
    [("12.0", "14.4", True), ("14.4", "14.4", False), ("15", "14.4", False), (None, "14.4", False), ("12", "", False)],
)
def test_require(tmp_path: Path, project: str | None, required: str, fails: bool) -> None:
    """Older than required fails (raise it, in the presets); same or newer passes; no value set or nothing required:
    nothing to check."""
    body = INIT + f'cs_require_macos_deployment_target("{required}" REASON "libX")\n'
    result = configure(tmp_path, body, args=_target(project))

    assert (result.returncode != 0) == fails, result.output
    if fails:
        assert "libX needs macOS 14.4 or newer, the project builds for macOS 12.0" in _text(result)
        assert "cscmake-project-setup-macos" in _text(result)


def test_recorded_in_the_installed_package(tmp_path: Path) -> None:
    prefix = tmp_path / "prefix"
    result = install(tmp_path / "project", INIT, prefix, args=_target("13.3"))

    assert result.returncode == 0, result.output
    assert (prefix / "share" / "cscmake" / "cstest.macos-deployment-target").read_text(encoding="utf-8") == "13.3\n"


def test_nothing_recorded_without_a_value(tmp_path: Path) -> None:
    prefix = tmp_path / "prefix"
    result = install(tmp_path / "project", INIT, prefix)

    assert result.returncode == 0, result.output
    assert not (prefix / "share" / "cscmake").exists()


def test_recorded_for_a_project_without_cscmake(tmp_path: Path) -> None:
    """A project without csCMake includes the script after every project() through its preset (CMAKE_PROJECT_INCLUDE, a
    module name): it records its value too, once, for the top-level project."""
    project = tmp_path / "project"
    project.mkdir()
    (project / "CMakeLists.txt").write_text(
        "cmake_minimum_required(VERSION 3.10)\nproject(thirdParty LANGUAGES NONE)\nproject(again LANGUAGES NONE)\n",
        encoding="utf-8",
    )
    prefix = tmp_path / "prefix"
    for command in (
        [
            "cmake",
            "-S",
            str(project),
            "-B",
            str(project / "build"),
            "-G",
            "Ninja",
            f"-DCMAKE_MODULE_PATH={REPO_ROOT.as_posix()}",
            "-DCMAKE_PROJECT_INCLUDE=modules/scripts/csRecordMacosDeploymentTarget",
            "-DCMAKE_OSX_DEPLOYMENT_TARGET=13.3",
            f"-DCMAKE_INSTALL_PREFIX={prefix.as_posix()}",
        ],
        ["cmake", "--install", str(project / "build")],
    ):
        result = subprocess.run(command, capture_output=True, text=True, check=False)
        assert result.returncode == 0, result.stdout + result.stderr

    assert [p.name for p in (prefix / "share" / "cscmake").iterdir()] == ["thirdParty.macos-deployment-target"]


@pytest.mark.parametrize(("project", "fails"), [("14", True), ("15", False), ("16", False), (None, False)])
def test_package_found_built_for_a_newer_macos(tmp_path: Path, project: str | None, fails: bool) -> None:
    """cs_find_package: a package built for macOS 15 in a project for 14 fails; 15 or newer passes."""
    prefix = tmp_path / "prefix"
    _package(prefix, "OtherLib", "15")
    body = (
        INIT
        + "cs_add_library(lib INTERFACE)\n"
        + f'cs_find_package(lib PUBLIC OtherLib REQUIRED CONFIG PATHS "{prefix.as_posix()}")\n'
    )
    result = configure(tmp_path / "project", body, args=_target(project))

    assert (result.returncode != 0) == fails, result.output
    if fails:
        assert "OtherLib (built for macOS 15) needs macOS 15 or newer, the project builds for macOS 14" in _text(result)


def test_package_without_record_is_not_checked(tmp_path: Path) -> None:
    prefix = tmp_path / "prefix"
    _package(prefix, "OtherLib", None)
    body = (
        INIT
        + "cs_add_library(lib INTERFACE)\n"
        + f'cs_find_package(lib PUBLIC OtherLib REQUIRED CONFIG PATHS "{prefix.as_posix()}")\n'
    )
    result = configure(tmp_path / "project", body, args=[*_target("12"), "--log-level=VERBOSE"])

    assert result.returncode == 0, result.output
    assert "OtherLib: no recorded macOS deployment target, not checked" in _text(result)


def test_generated_config_checks_its_dependencies(tmp_path: Path) -> None:
    """The <namespace>Config.cmake of a csCMake package checks what it finds (find_dependency): a consumer of a library
    that depends on OtherLib (macOS 15) fails at 14."""
    other = tmp_path / "other"
    _package(other, "OtherLib", "15")
    lib_prefix = tmp_path / "lib-prefix"
    lib_body = (
        INIT
        + "cs_add_library(lib INTERFACE)\n"
        + f'cs_find_package(lib PUBLIC OtherLib REQUIRED CONFIG PATHS "{other.as_posix()}")\n'
        + "cs_install_target(lib COMPONENT lib DEFAULT)\n"
    )
    assert install(tmp_path / "lib", lib_body, lib_prefix, args=_target("15")).returncode == 0

    consumer = (
        INIT.replace("cstest", "consumer")
        + f'list(APPEND CMAKE_PREFIX_PATH "{other.as_posix()}")\n'
        + f'find_package(cstest REQUIRED CONFIG PATHS "{lib_prefix.as_posix()}")\n'
    )
    for project, fails in (("14", True), ("15", False)):
        result = configure(tmp_path / f"consumer{project}", consumer, args=_target(project))
        assert (result.returncode != 0) == fails, result.output
        if fails:
            assert "OtherLib (built for macOS 15) needs macOS 15" in _text(result)


@pytest.mark.parametrize(("project", "fails"), [("13.3", True), ("14.4", False), (None, False)])
def test_qt_minimum(tmp_path: Path, project: str | None, fails: bool) -> None:
    """cs_find_package of Qt6 runs the hook of csQt: the project builds for QT_SUPPORTED_MIN_MACOS_VERSION or newer."""
    qt = _qt(tmp_path / "qt", "14.4")
    body = (
        INIT
        + f'cs_add_library(lib INTERFACE)\ncs_find_package(lib PRIVATE Qt6 REQUIRED CONFIG PATHS "{qt.as_posix()}")\n'
    )
    result = configure(tmp_path / "project", body, args=_target(project))

    assert (result.returncode != 0) == fails, result.output
    if fails:
        assert "Qt 6.12.0 needs macOS 14.4 or newer, the project builds for macOS 13.3" in _text(result)


def test_qt_with_find_package_fails(tmp_path: Path) -> None:
    """A plain find_package(Qt6): no check, the end of the project fails and says how to find it."""
    qt = _qt(tmp_path / "qt", "14.4")
    result = configure(
        tmp_path / "project", INIT + f'find_package(Qt6 REQUIRED CONFIG PATHS "{qt.as_posix()}")\n', args=_target("15")
    )

    assert result.returncode != 0, result.output
    assert "is found without the checks of csCMake" in _text(result)
    assert "cs_find_package(<target> PUBLIC|PRIVATE Qt6 ...)" in _text(result)
    assert "CSCMAKE_QT_ALLOW_FIND_PACKAGE=ON" in _text(result)


@pytest.mark.parametrize(("project", "fails"), [("13.3", True), ("14.4", False)])
def test_qt_with_find_package_allowed_is_still_checked(tmp_path: Path, project: str, fails: bool) -> None:
    qt = _qt(tmp_path / "qt", "14.4")
    result = configure(
        tmp_path / "project",
        INIT + f'find_package(Qt6 REQUIRED CONFIG PATHS "{qt.as_posix()}")\n',
        args=[*_target(project), "-DCSCMAKE_QT_ALLOW_FIND_PACKAGE=ON"],
    )

    assert (result.returncode != 0) == fails, result.output
    assert "checked now from its Qt6ConfigExtras.cmake" in _text(result)
    if fails:
        assert "Qt (" in _text(result)
        assert "needs macOS 14.4 or newer" in _text(result)


HOOK = """function(cstest_hook package)
  message(STATUS "HOOK ${package} ${${package}_VERSION}")
endfunction()
cs_add_after_find_hook(OtherLib cstest_hook)
"""


def test_hook_runs_after_cs_find_package(tmp_path: Path) -> None:
    """A hook registered for a package runs when csCMake finds it, with the package's variables visible; not for the
    other packages."""
    prefix = tmp_path / "prefix"
    _package(prefix, "OtherLib", None)
    _package(prefix, "Unrelated", None)
    body = (
        INIT
        + HOOK
        + "cs_add_library(lib INTERFACE)\n"
        + f'cs_find_package(lib PUBLIC OtherLib REQUIRED CONFIG PATHS "{prefix.as_posix()}")\n'
        + f'cs_find_package(lib PUBLIC Unrelated REQUIRED CONFIG PATHS "{prefix.as_posix()}")\n'
    )
    result = configure(tmp_path / "project", body)

    assert result.returncode == 0, result.output
    assert result.output.count("-- HOOK ") == 1
    assert "-- HOOK OtherLib 1.0" in result.output


def test_hook_runs_for_the_dependencies_of_a_package(tmp_path: Path) -> None:
    """The <namespace>Config.cmake of a csCMake package runs the hooks of the consumer on what it finds."""
    other = tmp_path / "other"
    _package(other, "OtherLib", None)
    lib_prefix = tmp_path / "lib-prefix"
    lib_body = (
        INIT
        + "cs_add_library(lib INTERFACE)\n"
        + f'cs_find_package(lib PUBLIC OtherLib REQUIRED CONFIG PATHS "{other.as_posix()}")\n'
        + "cs_install_target(lib COMPONENT lib DEFAULT)\n"
    )
    assert install(tmp_path / "lib", lib_body, lib_prefix).returncode == 0

    consumer = (
        INIT.replace("cstest", "consumer")
        + HOOK
        + f'list(APPEND CMAKE_PREFIX_PATH "{other.as_posix()}")\n'
        + f'find_package(cstest REQUIRED CONFIG PATHS "{lib_prefix.as_posix()}")\n'
    )
    result = configure(tmp_path / "consumer", consumer)

    assert result.returncode == 0, result.output
    assert "-- HOOK OtherLib 1.0" in result.output


def test_hook_must_be_a_command(tmp_path: Path) -> None:
    result = configure(tmp_path, INIT + "cs_add_after_find_hook(OtherLib not_defined)\n")

    assert result.returncode != 0
    assert "not_defined is not a function" in _text(result)
