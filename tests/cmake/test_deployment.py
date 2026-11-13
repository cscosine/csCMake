"""Deployments (csDeployment.cmake): cs_deployment, the build targets cs_deploy_<name>, cs-deployments.json."""

from __future__ import annotations

import json
import shutil
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
# the libraries of the system a deployment needs (Linux)
REPORT = {"system-requirements.txt"} if sys.platform == "linux" else set()
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

    assert _files(deploy / "demo-Release") == {f"bin/app{EXE}", SHARED_LIB, *REPORT}
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
    assert deployed == {f"bin/app{EXE}", f"bin/sample{EXE}", SHARED_LIB, "share/demo/sample.txt", *REPORT}
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
        *REPORT,
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
    assert _files(deploy / "first-Release") == {f"bin/app{EXE}", SHARED_LIB, *REPORT}
    assert _files(deploy / "second-Release") == {f"bin/sample{EXE}", SHARED_LIB, *REPORT}
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


# --- the libraries of other packages (Linux) ---

linux_only = pytest.mark.skipif(sys.platform != "linux", reason="the libraries of other packages: Linux only")

# another package (plain CMake): ext links ext2, both versioned (symlink chains), RPATH $ORIGIN unless EXT_RPATH
EXTERNAL = {
    "CMakeLists.txt": """cmake_minimum_required(VERSION 3.31)
project(ext LANGUAGES CXX)
add_library(ext2 SHARED ext2.cpp)
add_library(ext SHARED ext.cpp)
target_link_libraries(ext PRIVATE ext2)
set(EXT_RPATH "$ORIGIN" CACHE STRING "")
set_target_properties(ext ext2 PROPERTIES VERSION 1.2.3 SOVERSION 1 INSTALL_RPATH "${EXT_RPATH}")
install(TARGETS ext ext2 EXPORT extTargets LIBRARY DESTINATION lib)
install(EXPORT extTargets NAMESPACE ext:: DESTINATION lib/cmake/ext FILE extConfig.cmake)
""",
    "ext2.cpp": "int ext2() { return 2; }\n",
    "ext.cpp": "int ext2();\nint ext() { return ext2() - 1; }\n",
}
EXT_FILES = {"lib/libext.so.1", "lib/libext.so.1.2.3", "lib/libext2.so.1", "lib/libext2.so.1.2.3"}
# the application and the sample link the library of the other package too
EXT_TARGETS = """
find_package(ext CONFIG REQUIRED)
cs_target_link_libraries(app PRIVATE ext::ext)
cs_target_link_libraries(sample PRIVATE ext::ext)
"""
EXT_SOURCES = {
    **SOURCES,
    "main.cpp": "int core();\nint st();\nint ext();\nint main() { return core() + st() + ext() - 4; }\n",
    "sample.cpp": "int core();\nint ext();\nint main() { return core() + ext() - 2; }\n",
}


def _external(folder: Path, rpath: str = "$ORIGIN") -> Path:
    """Build and install the other package in folder; its install prefix."""
    for name, content in EXTERNAL.items():
        (folder / "ext-src").mkdir(parents=True, exist_ok=True)
        (folder / "ext-src" / name).write_text(content, encoding="utf-8")
    prefix = folder / "ext"
    for command in (
        ["-S", "ext-src", "-B", "ext-build", "-G", "Ninja", "-DCMAKE_BUILD_TYPE=Release", f"-DEXT_RPATH={rpath}"],
        ["--build", "ext-build"],
        ["--install", "ext-build", "--prefix", str(prefix)],
    ):
        run = subprocess.run(["cmake", *command], cwd=folder, capture_output=True, text=True, check=False)
        assert run.returncode == 0, run.stdout + run.stderr
    return prefix


def _deploy_ext(
    project_dir: Path, ext: Path, body: str, target: str = "cs_deploy_demo"
) -> subprocess.CompletedProcess[str]:
    """Configure INIT + TARGETS + EXT_TARGETS + body against the other package (Release), build the target."""
    args = [*RELEASE, f"-DCMAKE_PREFIX_PATH={ext}"]
    result = configure(project_dir, INIT + TARGETS + EXT_TARGETS + body, EXT_SOURCES, args=args)
    assert result.returncode == 0, result.output
    return _build(project_dir, target)


@linux_only
def test_ships_the_libraries_of_other_packages(tmp_path: Path) -> None:
    """Two deployments: each gets the libraries of the other package (with their symlinks), not the ones of the
    system; each application runs with an empty environment."""
    ext = _external(tmp_path)
    body = "cs_deployment(first TARGETS app)\ncs_deployment(second TARGETS sample)\n"
    for target in ("cs_deploy_first", "cs_deploy_second"):
        built = _deploy_ext(tmp_path / "project", ext, body, target)
        assert built.returncode == 0, built.stdout + built.stderr
        assert "2 libraries of other packages shipped" in _text(built.stdout)

    deploy = tmp_path / "project" / "build" / "deploy"
    assert _files(deploy / "first-Release") == {"bin/app", SHARED_LIB, *EXT_FILES, *REPORT}
    assert _files(deploy / "second-Release") == {"bin/sample", SHARED_LIB, *EXT_FILES, *REPORT}
    assert (deploy / "first-Release" / "lib" / "libext.so.1").is_symlink()
    for folder, program in (("first-Release", "app"), ("second-Release", "sample")):
        run = subprocess.run([str(deploy / folder / "bin" / program)], env={}, check=False)
        assert run.returncode == 0


@linux_only
def test_a_library_not_found_fails(tmp_path: Path) -> None:
    """A library of the other package removed after the build: not found, the deployment fails, and so does the
    install."""
    ext = _external(tmp_path)
    project = tmp_path / "project"
    configured = configure(
        project,
        INIT + TARGETS + EXT_TARGETS + "cs_deployment(demo TARGETS app)\n",
        EXT_SOURCES,
        args=[*RELEASE, f"-DCMAKE_PREFIX_PATH={ext}"],
    )
    assert configured.returncode == 0, configured.output
    assert _build(project, "app").returncode == 0
    for library in (ext / "lib").glob("libext2.so*"):
        library.unlink()

    run = subprocess.run(
        ["cmake", "--install", "build", "--prefix", "install"], cwd=project, capture_output=True, text=True, check=False
    )

    assert run.returncode != 0
    assert (
        "not found from the build tree (a library without the RPATH to find the ones it needs?): libext2.so.1"
        in _text(run.stdout + run.stderr)
    )


@linux_only
def test_a_binary_not_finding_its_libraries_fails(tmp_path: Path) -> None:
    """The install RPATH of the application does not reach lib/: the check fails."""
    ext = _external(tmp_path)
    body = 'set_target_properties(app PROPERTIES INSTALL_RPATH "$ORIGIN/nowhere")\ncs_deployment(demo TARGETS app)\n'

    built = _deploy_ext(tmp_path / "project", ext, body)

    assert built.returncode != 0
    assert "libraries not found from the deployment" in _text(built.stdout + built.stderr)


@linux_only
def test_a_shadowed_library_fails(tmp_path: Path) -> None:
    """The application finds the library of the other package outside the deployment (an absolute RPATH first), while
    the deployment ships it: the check fails."""
    ext = _external(tmp_path)
    body = (
        f'set_target_properties(app PROPERTIES INSTALL_RPATH "{ext}/lib;$ORIGIN/../lib")\n'
        "cs_deployment(demo TARGETS app)\n"
    )

    built = _deploy_ext(tmp_path / "project", ext, body)

    assert built.returncode != 0
    output = _text(built.stdout + built.stderr)
    assert "libext.so.1 resolves to" in output
    assert "which ships it: a binary does not find the copy of the deployment" in output


@linux_only
def test_excluded_libraries(tmp_path: Path) -> None:
    """EXCLUDE_REGEXES: not shipped (the machines running the deployment have it), and ignored by the check."""
    ext = _external(tmp_path)

    built = _deploy_ext(tmp_path / "project", ext, "cs_deployment(demo TARGETS app EXCLUDE_REGEXES ^libext2)\n")

    assert built.returncode == 0, built.stdout + built.stderr
    deployed = _files(tmp_path / "project" / "build" / "deploy" / "demo-Release")
    assert deployed == {"bin/app", SHARED_LIB, "lib/libext.so.1", "lib/libext.so.1.2.3", *REPORT}


@linux_only
def test_libraries_without_rpath(tmp_path: Path) -> None:
    """The other package without RPATH: libext does not find libext2 (its RPATH), the deployment fails."""
    ext = _external(tmp_path, rpath="")

    built = _deploy_ext(tmp_path / "project", ext, "cs_deployment(demo TARGETS app)\n")

    assert built.returncode != 0
    assert "not found from the build tree (a library without the RPATH to find the ones it needs?): libext2.so.1" in (
        _text(built.stdout + built.stderr)
    )


@linux_only
def test_system_requirements(tmp_path: Path) -> None:
    """system-requirements.txt: the libraries of the system the deployment needs (libc), with their Debian
    packages and the apt install line when dpkg-query is there; not the libraries it ships."""
    ext = _external(tmp_path)
    built = _deploy_ext(tmp_path / "project", ext, "cs_deployment(demo TARGETS app)\n")
    assert built.returncode == 0, built.stdout + built.stderr

    report = (tmp_path / "project" / "build" / "deploy" / "demo-Release" / "system-requirements.txt").read_text(
        encoding="utf-8"
    )
    names = {line.split()[0] for line in report.splitlines() if line and not line.startswith(("#", "apt "))}
    assert "libc.so.6" in names, report
    assert not any(name.startswith(("libext", "libcore")) for name in names), report
    if shutil.which("dpkg-query"):
        apt = next(line for line in report.splitlines() if line.startswith("apt install "))
        assert "libc6" in apt.split()[2:], report


@pytest.mark.skipif(sys.platform == "linux", reason="Linux ships the libraries of other packages")
def test_other_systems_warn(tmp_path: Path) -> None:
    result = configure(tmp_path, INIT + TARGETS + "cs_deployment(demo TARGETS app)\n", SOURCES)

    assert result.returncode == 0, result.output
    assert "the libraries of other packages are shipped on Linux only" in _text(result.output)


@pytest.mark.parametrize(
    ("body", "message"),
    [
        (
            "cs_deployment(demo TARGETS app EXCLUDE_REGEXES a)\ncs_deployment(demo EXCLUDE_REGEXES b)",
            "EXCLUDE_REGEXES b, but already EXCLUDE_REGEXES a (given once per deployment)",
        ),
    ],
    ids=["exclude-regexes-changed"],
)
def test_closure_mistakes_fail(tmp_path: Path, body: str, message: str) -> None:
    result = configure(tmp_path, INIT + TARGETS + body + "\n", SOURCES)

    assert result.returncode != 0
    assert message in _text(result.output), result.output
