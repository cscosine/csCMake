"""Deployments (csDeployment.cmake): cs_deployment, the build targets cs_deploy_<name>, cs-deployments.json."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest

from tests.cmake.cmake_project import Configured, after_finalize, configure

# the targets compile: a C++ compiler on PATH (on Windows: the Visual Studio developer environment)
pytestmark = pytest.mark.requires("cmake", "ninja")

EXE = ".exe" if sys.platform == "win32" else ""
# a shared library of the project in a deployment: next to the executables on Windows, else in lib/
SHARED_LIB = {"win32": "bin/core.dll", "darwin": "lib/libcore.dylib"}.get(sys.platform, "lib/libcore.so")
RELEASE = ["-DCMAKE_BUILD_TYPE=Release"]

INIT = "enable_language(CXX)\ncs_initialize_project(NAMESPACE cstest CXX_STANDARD 17 DEFAULT_CONFIG Debug Release)\n"
# an application linking a shared and a static library of the project, a sample linking the shared one
TARGETS = """
cs_add_library(core SHARED core.cpp)
cs_add_library(st STATIC st.cpp)
cs_add_executable(app main.cpp)
cs_target_link_libraries(app PRIVATE core st)
cs_add_executable(sample sample.cpp)
cs_target_link_libraries(sample PRIVATE core)
cs_install_target(core COMPONENT core DEFAULT)
cs_install_target(st COMPONENT st)
cs_install_target(app COMPONENT app)
"""
EXPORT = "__declspec(dllexport) " if sys.platform == "win32" else ""
IMPORT = "__declspec(dllimport) " if sys.platform == "win32" else ""
SOURCES = {
    "core.cpp": f"{EXPORT}int core() {{ return 1; }}\n",
    "st.cpp": "int st() { return 2; }\n",
    "main.cpp": f"{IMPORT}int core();\nint st();\nint main() {{ return core() + st() - 3; }}\n",
    "sample.cpp": f"{IMPORT}int core();\nint main() {{ return core() - 1; }}\n",
    "data/sample.txt": "data\n",
    "data/sub/more.txt": "more\n",
}


def _build(project_dir: Path, target: str | None = None) -> subprocess.CompletedProcess[str]:
    command = ["cmake", "--build", str(project_dir / "build")]
    if target:
        command += ["--target", target]
    return subprocess.run(command, capture_output=True, text=True, check=False)


def _files(folder: Path) -> set[str]:
    return {path.relative_to(folder).as_posix() for path in folder.rglob("*") if path.is_file()}


def _deploy(project_dir: Path, body: str, target: str, args: list[str] | None = None) -> Path:
    """Configure INIT + TARGETS + body (Release unless args), build the deployment target; the deploy folder."""
    result = configure(project_dir, INIT + TARGETS + body, SOURCES, args=RELEASE if args is None else args)
    assert result.returncode == 0, result.output
    built = _build(project_dir, target)
    assert built.returncode == 0, built.stdout + built.stderr
    return project_dir / "build" / "deploy"


def _text(output: str) -> str:
    return " ".join(output.split())


def test_ships_the_targets_and_their_shared_libraries_only(tmp_path: Path) -> None:
    """The executables, the shared libraries of the project they need (where the install RPATH finds them); not the
    static library, nor headers, import libraries, CMake files. The deployed application runs."""
    deploy = _deploy(tmp_path, "cs_deployment(demo TARGETS app)\n", "cs_deploy_demo")

    assert _files(deploy / "demo-Release") == {f"bin/app{EXE}", SHARED_LIB}
    run = subprocess.run([str(deploy / "demo-Release" / "bin" / f"app{EXE}")], check=False)
    assert run.returncode == 0


def _install(project_dir: Path, body: str, args: list[str]) -> Configured:
    """Configure INIT + TARGETS + body with an install prefix (and args), build and install it."""
    prefix = project_dir / "install"
    result = configure(project_dir, INIT + TARGETS + body, SOURCES, args=[f"-DCMAKE_INSTALL_PREFIX={prefix}", *args])
    if result.returncode != 0:
        return result
    output = result.output
    for command in (["--build", "build"], ["--install", "build"]):
        run = subprocess.run(["cmake", *command], cwd=project_dir, capture_output=True, text=True, check=False)
        output += run.stdout + run.stderr
        if run.returncode != 0:
            return Configured(run.returncode, output)
    return Configured(0, output)


DEMO = "cs_deployment(demo TARGETS app sample FILES data/sample.txt DESTINATION share/demo)\n"


def test_the_install_makes_the_deployment_in_its_own_folder(tmp_path: Path) -> None:
    """The normal install makes the deployment, in its folder: nothing of it in the install prefix."""
    result = _install(tmp_path, DEMO, RELEASE)

    assert result.returncode == 0, result.output
    deployed = _files(tmp_path / "build" / "deploy" / "demo-Release")
    assert deployed == {f"bin/app{EXE}", f"bin/sample{EXE}", SHARED_LIB, "share/demo/sample.txt"}
    installed = _files(tmp_path / "install")
    assert f"bin/app{EXE}" in installed
    assert not any("sample" in name for name in installed), installed


def test_the_install_skips_the_configurations_not_listed(tmp_path: Path) -> None:
    """Installing Debug (the deployment is made in Release): skipped, with a message; the install succeeds."""
    result = _install(tmp_path, DEMO, [])

    assert result.returncode == 0, result.output
    assert "[cs_deploy_demo] Debug: not made (the deployment is made in Release)" in _text(result.output)
    assert not (tmp_path / "build" / "deploy").exists()


def test_deploy_on_install_off(tmp_path: Path) -> None:
    result = _install(tmp_path, DEMO, [*RELEASE, "-DCSCMAKE_DEPLOY_ON_INSTALL=OFF"])

    assert result.returncode == 0, result.output
    assert not (tmp_path / "build" / "deploy").exists()
    built = _build(tmp_path, "cs_deploy_demo")
    assert built.returncode == 0, built.stdout + built.stderr
    assert (tmp_path / "build" / "deploy" / "demo-Release" / "bin" / f"app{EXE}").is_file()


def test_a_failing_deployment_fails_the_install(tmp_path: Path) -> None:
    """A file of the deployment removed after the configure: the deployment fails, and so does the install."""
    result = configure(tmp_path, INIT + TARGETS + DEMO, SOURCES, args=RELEASE)
    assert result.returncode == 0, result.output
    (tmp_path / "data" / "sample.txt").unlink()
    assert _build(tmp_path).returncode == 0

    run = subprocess.run(
        ["cmake", "--install", "build", "--prefix", "install"],
        cwd=tmp_path,
        capture_output=True,
        text=True,
        check=False,
    )

    assert run.returncode != 0
    assert "sample.txt" in run.stdout + run.stderr


def test_content_added_from_several_folders(tmp_path: Path) -> None:
    """Later calls (another folder too) add targets and files; a folder ships itself, a folder/ its content; relative
    paths are relative to the folder of the call."""
    body = """
cs_deployment(demo TARGETS app FILES data/sample.txt DESTINATION share/demo)
add_subdirectory(samples)
"""
    files = {"samples/CMakeLists.txt": "cs_deployment(demo TARGETS sample DIRECTORY ../data ../data/ DESTINATION d)\n"}
    result = configure(tmp_path, INIT + TARGETS + body, {**SOURCES, **files}, args=RELEASE)
    assert result.returncode == 0, result.output
    built = _build(tmp_path, "cs_deploy_demo")
    assert built.returncode == 0, built.stdout + built.stderr

    assert _files(tmp_path / "build" / "deploy" / "demo-Release") == {
        f"bin/app{EXE}",
        f"bin/sample{EXE}",
        SHARED_LIB,
        "share/demo/sample.txt",
        "d/data/sample.txt",
        "d/data/sub/more.txt",
        "d/sample.txt",
        "d/sub/more.txt",
    }


def test_two_deployments_each_complete(tmp_path: Path) -> None:
    """Two deployments sharing a library: each folder has its own copy, and each application runs."""
    body = "cs_deployment(first TARGETS app)\ncs_deployment(second TARGETS sample)\n"
    result = configure(tmp_path, INIT + TARGETS + body, SOURCES, args=RELEASE)
    assert result.returncode == 0, result.output
    for target in ("cs_deploy_first", "cs_deploy_second"):
        built = _build(tmp_path, target)
        assert built.returncode == 0, built.stdout + built.stderr

    deploy = tmp_path / "build" / "deploy"
    assert _files(deploy / "first-Release") == {f"bin/app{EXE}", SHARED_LIB}
    assert _files(deploy / "second-Release") == {f"bin/sample{EXE}", SHARED_LIB}
    for folder, program in (("first-Release", "app"), ("second-Release", "sample")):
        assert subprocess.run([str(deploy / folder / "bin" / f"{program}{EXE}")], check=False).returncode == 0


def test_the_folder_is_emptied_first(tmp_path: Path) -> None:
    deploy = _deploy(tmp_path, "cs_deployment(demo TARGETS app)\n", "cs_deploy_demo")
    stale = deploy / "demo-Release" / "stale.txt"
    stale.write_text("stale\n", encoding="utf-8")

    built = _build(tmp_path, "cs_deploy_demo")

    assert built.returncode == 0, built.stdout + built.stderr
    assert not stale.exists()


def test_fails_in_a_configuration_not_listed(tmp_path: Path) -> None:
    """Default CONFIGS Release: building the target in Debug fails, and says why."""
    result = configure(tmp_path, INIT + TARGETS + "cs_deployment(demo TARGETS app)\n", SOURCES)
    assert result.returncode == 0, result.output

    built = _build(tmp_path, "cs_deploy_demo")

    assert built.returncode != 0
    assert "the deployment demo is made in Release, not in Debug" in _text(built.stdout + built.stderr)
    assert not (tmp_path / "build" / "deploy" / "demo-Debug").exists()


def test_other_configurations(tmp_path: Path) -> None:
    """CONFIGS chooses the configurations (here Debug: the postfixed output names)."""
    deploy = _deploy(tmp_path, "cs_deployment(demo TARGETS app CONFIGS Debug)\n", "cs_deploy_demo", args=[])

    assert f"bin/appd{EXE}" in _files(deploy / "demo-Debug")


def test_deployments_file(tmp_path: Path) -> None:
    """cs-deployments.json: the configurations of the build, each deployment with its folders per configuration; an
    alias is accepted as target; CSCMAKE_DEPLOY_DIR relative to the build folder."""
    body = """
cs_add_executable(cstest::app ALIAS app)
cs_deployment(demo TARGETS cstest::app CONFIGS Release Debug)
cs_deployment(other TARGETS sample)
"""
    result = configure(tmp_path, INIT + TARGETS + body, SOURCES, args=["-DCSCMAKE_DEPLOY_DIR=out"])
    assert result.returncode == 0, result.output

    build = (tmp_path / "build").resolve().as_posix()
    data = json.loads((tmp_path / "build" / "cs-deployments.json").read_text(encoding="utf-8"))
    assert data == {
        "version": 1,
        "build_dir": build,
        "build_configs": ["Debug"],
        "deployments": [
            {
                "name": "demo",
                "project": "cstest",
                "build_target": "cs_deploy_demo",
                "configs": ["Release", "Debug"],
                "targets": ["cstest::app"],
                "folders": {"Release": f"{build}/out/demo-Release", "Debug": f"{build}/out/demo-Debug"},
            },
            {
                "name": "other",
                "project": "cstest",
                "build_target": "cs_deploy_other",
                "configs": ["Release"],
                "targets": ["sample"],
                "folders": {"Release": f"{build}/out/other-Release"},
            },
        ],
    }


def test_no_deployments_file_without_deployments(tmp_path: Path) -> None:
    result = configure(tmp_path, INIT + TARGETS, SOURCES)

    assert result.returncode == 0, result.output
    assert not (tmp_path / "build" / "cs-deployments.json").exists()


@pytest.mark.parametrize(
    ("body", "message"),
    [
        ("cs_deployment(demo TARGETS)", "unexpected or empty arguments TARGETS"),
        ("cs_deployment(1demo TARGETS app)", "a deployment name is a letter, then letters, digits and _"),
        ("cs_deployment(de-mo TARGETS app)", "a deployment name is a letter"),
        ("cs_deployment(demo FILES data/sample.txt DESTINATION d)", "demo: no TARGETS"),
        ("cs_deployment(demo TARGETS nothing)", "demo: nothing is not a target"),
        ("cs_deployment(demo TARGETS st)", "st is a STATIC_LIBRARY"),
        ("add_executable(plain main.cpp)\ncs_deployment(demo TARGETS plain)", "plain is not a target of the project"),
        ("cs_deployment(demo TARGETS app CONFIGS Paranoid)", "Paranoid is not a configuration of the project"),
        ("cs_deployment(demo TARGETS app CONFIGS Release Release)", "configuration Release given twice"),
        (
            "cs_deployment(demo TARGETS app CONFIGS Release)\ncs_deployment(demo CONFIGS Debug)",
            "CONFIGS Debug, but already CONFIGS Release",
        ),
        ("cs_deployment(demo TARGETS app FILES data/sample.txt)", "FILES and DIRECTORY go with DESTINATION"),
        ("cs_deployment(demo TARGETS app DESTINATION d)", "FILES and DIRECTORY go with DESTINATION"),
        ("cs_deployment(demo TARGETS app FILES data/sample.txt DESTINATION /abs)", "DESTINATION /abs is a folder"),
        ("cs_deployment(demo TARGETS app FILES data/sample.txt DESTINATION a/../..)", "relative, without .."),
        ("cs_deployment(demo TARGETS app FILES missing.txt DESTINATION d)", "FILES missing.txt is not a file"),
        ("cs_deployment(demo TARGETS app FILES data DESTINATION d)", "FILES data is not a file"),
        ("cs_deployment(demo TARGETS app DIRECTORY data/sample.txt DESTINATION d)", "is not a folder"),
    ],
    ids=[
        "keyword-without-value",
        "name-digit",
        "name-dash",
        "no-targets",
        "unknown-target",
        "static-library",
        "not-a-cscmake-target",
        "unknown-config",
        "config-twice",
        "configs-changed",
        "files-without-destination",
        "destination-without-files",
        "absolute-destination",
        "destination-outside",
        "missing-file",
        "file-is-a-folder",
        "folder-is-a-file",
    ],
)
def test_mistakes_fail(tmp_path: Path, body: str, message: str) -> None:
    result = configure(tmp_path, INIT + TARGETS + body + "\n", SOURCES)

    assert result.returncode != 0
    assert message in _text(result.output), result.output


def test_same_configs_repeated(tmp_path: Path) -> None:
    body = "cs_deployment(demo TARGETS app CONFIGS Debug)\ncs_deployment(demo TARGETS sample CONFIGS Debug)\n"
    result = configure(tmp_path, INIT + TARGETS + body, SOURCES)

    assert result.returncode == 0, result.output


def test_release_by_default_needs_release(tmp_path: Path) -> None:
    body = (
        "enable_language(CXX)\ncs_initialize_project(NAMESPACE cstest CXX_STANDARD 17 DEFAULT_CONFIG Debug)\n"
        + TARGETS
        + "cs_deployment(demo TARGETS app)\n"
    )
    result = configure(tmp_path, body, SOURCES)

    assert result.returncode != 0
    assert "Release is not a configuration of the project (Debug)" in _text(result.output), result.output


@pytest.mark.parametrize(
    ("body", "message"),
    [
        ("cs_deployment(demo TARGETS app)", "call cs_initialize_project(NAMESPACE ...) before"),
    ],
    ids=["before-initialize"],
)
def test_called_outside_a_project_fails(tmp_path: Path, body: str, message: str) -> None:
    result = configure(tmp_path, body + "\n")

    assert result.returncode != 0
    assert message in _text(result.output), result.output


def test_after_finalize_fails(tmp_path: Path) -> None:
    result = configure(tmp_path, INIT + TARGETS + after_finalize("cs_deployment(demo TARGETS app)"), SOURCES)

    assert result.returncode != 0
    assert "the project cstest is already finalized" in _text(result.output), result.output


def test_name_unique_in_the_build(tmp_path: Path) -> None:
    """Two csCMake projects of one build cannot declare the same deployment (same build target, same folder)."""
    inner = """
project(inner VERSION 1.0.0 LANGUAGES CXX)
cs_initialize_project(NAMESPACE inner CXX_STANDARD 17 DEFAULT_CONFIG Debug Release)
cs_add_executable(inner_app ../main.cpp ../st.cpp ../core.cpp)
cs_deployment(demo TARGETS inner_app)
"""
    body = INIT + TARGETS + "cs_deployment(demo TARGETS app)\nadd_subdirectory(inner)\n"
    result: Configured = configure(tmp_path, body, {**SOURCES, "inner/CMakeLists.txt": inner})

    assert result.returncode != 0
    assert "demo: already a deployment of the project cstest" in _text(result.output), result.output
