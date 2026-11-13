"""Deployments (csDeployment.cmake): cs_deployment, the build targets cs_deploy_<name>, cs-deployments.json."""

from __future__ import annotations

import json
import os
import re
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


# the C++ runtime of MSVC in a deployment (Windows with MSVC, MSVC_RUNTIME ON): its DLLs vary with the compiler
MSVC_RUNTIME_FILE = re.compile(r"bin/(vcruntime|msvcp|concrt|vccorlib|vcomp)[0-9]+[0-9a-z_]*\.dll", re.IGNORECASE)


def _all_files(folder: Path) -> set[str]:
    return {path.relative_to(folder).as_posix() for path in folder.rglob("*") if path.is_file()}


def _files(folder: Path) -> set[str]:
    """The files of folder, but the C++ runtime of MSVC (test_msvc_runtime)."""
    return {name for name in _all_files(folder) if not MSVC_RUNTIME_FILE.fullmatch(name)}


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


@pytest.mark.skipif(sys.platform == "win32", reason="Windows: a Debug deployment fails (test_debug_runtime_fails)")
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
        ("cs_deployment(demo TARGETS app FILES data/sample.txt)", "PLUGINS, FILES and DIRECTORY go with DESTINATION"),
        ("cs_deployment(demo TARGETS app DESTINATION d)", "PLUGINS, FILES and DIRECTORY go with DESTINATION"),
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


# --- the libraries of other packages ---

WINDOWS = sys.platform == "win32"
MACOS = sys.platform == "darwin"
linux_only = pytest.mark.skipif(sys.platform != "linux", reason="system-requirements.txt: Linux only")
rpath_only = pytest.mark.skipif(WINDOWS, reason="RPATH: Linux and macOS")
windows_only = pytest.mark.skipif(not WINDOWS, reason="Windows only")

# another package (plain CMake): ext links ext2, both versioned (symlink chains on Linux and macOS), RPATH $ORIGIN
# (@loader_path) unless EXT_RPATH; DLLs in bin/ on Windows
EXTERNAL = {
    "CMakeLists.txt": """cmake_minimum_required(VERSION 3.31)
project(ext LANGUAGES CXX)
set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)
if(APPLE)
  set(origin "@loader_path")
else()
  set(origin "$ORIGIN")
endif()
add_library(ext2 SHARED ext2.cpp)
add_library(ext SHARED ext.cpp)
target_link_libraries(ext PRIVATE ext2)
set(EXT_RPATH "${origin}" CACHE STRING "")
set_target_properties(ext ext2 PROPERTIES VERSION 1.2.3 SOVERSION 1 INSTALL_RPATH "${EXT_RPATH}")
install(TARGETS ext ext2 EXPORT extTargets RUNTIME DESTINATION bin LIBRARY DESTINATION lib ARCHIVE DESTINATION lib)
install(EXPORT extTargets NAMESPACE ext:: DESTINATION lib/cmake/ext FILE extConfig.cmake)
# a plugin, laid out as the Qt ones: plugins/<type>/, RPATH $ORIGIN/../../lib, needing ext3 (not used by the
# applications)
add_library(ext3 SHARED ext3.cpp)
add_library(fake MODULE fake.cpp)
target_link_libraries(fake PRIVATE ext3)
set_target_properties(ext3 PROPERTIES INSTALL_RPATH "${origin}")
set_target_properties(fake PROPERTIES INSTALL_RPATH "${origin}/../../lib")
install(TARGETS ext3 RUNTIME DESTINATION bin LIBRARY DESTINATION lib ARCHIVE DESTINATION lib)
install(TARGETS fake LIBRARY DESTINATION plugins/platforms)
""",
    "ext3.cpp": "int ext3() { return 3; }\n",
    # exported (on Windows, an unused function of a DLL is dropped, and its import of ext3 with it)
    "fake.cpp": "int ext3();\n#ifdef _WIN32\n__declspec(dllexport)\n#endif\nint fake() { return ext3(); }\n",
    "ext2.cpp": "int ext2() { return 2; }\n",
    "ext.cpp": "int ext2();\nint ext() { return ext2() - 1; }\n",
}


def _ext_files(name: str) -> set[str]:
    """The files of the library name of the other package in a deployment (with its symlink chain)."""
    if WINDOWS:
        return {f"bin/{name}.dll"}
    if MACOS:
        return {f"lib/lib{name}.1.dylib", f"lib/lib{name}.1.2.3.dylib"}
    return {f"lib/lib{name}.so.1", f"lib/lib{name}.so.1.2.3"}


EXT_FILES = _ext_files("ext") | _ext_files("ext2")
# the symlink of libext (Linux, macOS): its soname, its install name
EXT_SYMLINK = "lib/libext.1.dylib" if MACOS else "lib/libext.so.1"
EXT3_FILE = {"win32": "bin/ext3.dll", "darwin": "lib/libext3.dylib"}.get(sys.platform, "lib/libext3.so")
PLUGIN_FILE = "plugins/platforms/" + ("fake.dll" if WINDOWS else "libfake.so")
# the application and the sample link the library of the other package too
EXT_TARGETS = """
find_package(ext CONFIG REQUIRED)
cs_target_link_libraries(app PRIVATE ext::ext)
cs_target_link_libraries(sample PRIVATE ext::ext)
"""
EXT_SOURCES = {
    **SOURCES,
    "main.cpp": f"{IMPORT}int core();\nint st();\nint ext();\nint main() {{ return core() + st() + ext() - 4; }}\n",
    "sample.cpp": f"{IMPORT}int core();\nint ext();\nint main() {{ return core() + ext() - 2; }}\n",
}


def _clean_environment() -> dict[str, str]:
    """An environment with nothing to find libraries with: empty; Windows: PATH with the system folder only."""
    if WINDOWS:
        system_root = os.environ["SYSTEMROOT"]  # case-insensitive on Windows
        return {"SystemRoot": system_root, "PATH": str(Path(system_root) / "System32")}
    return {}


def _external(folder: Path, rpath: str | None = None) -> Path:
    """Build and install the other package in folder (EXT_RPATH: rpath when given); its install prefix."""
    for name, content in EXTERNAL.items():
        (folder / "ext-src").mkdir(parents=True, exist_ok=True)
        (folder / "ext-src" / name).write_text(content, encoding="utf-8")
    prefix = folder / "ext"
    configure_args = ["-S", "ext-src", "-B", "ext-build", "-G", "Ninja", "-DCMAKE_BUILD_TYPE=Release"]
    if rpath is not None:
        configure_args.append(f"-DEXT_RPATH={rpath}")
    for command in (configure_args, ["--build", "ext-build"], ["--install", "ext-build", "--prefix", str(prefix)]):
        run = subprocess.run(["cmake", *command], cwd=folder, capture_output=True, text=True, check=False)
        assert run.returncode == 0, run.stdout + run.stderr
    return prefix


def _deploy_ext(
    project_dir: Path, ext: Path, body: str, target: str = "cs_deploy_demo"
) -> subprocess.CompletedProcess[str]:
    """Configure INIT + TARGETS + EXT_TARGETS + body against the other package (Release), build the target."""
    args = [*RELEASE, f"-DCMAKE_PREFIX_PATH={ext.as_posix()}"]
    result = configure(project_dir, INIT + TARGETS + EXT_TARGETS + body, EXT_SOURCES, args=args)
    assert result.returncode == 0, result.output
    return _build(project_dir, target)


def test_ships_the_libraries_of_other_packages(tmp_path: Path) -> None:
    """Two deployments: each gets the libraries of the other package (with their symlinks), not the ones of the
    system; each application runs with a clean environment."""
    ext = _external(tmp_path)
    body = "cs_deployment(first TARGETS app)\ncs_deployment(second TARGETS sample)\n"
    for target in ("cs_deploy_first", "cs_deploy_second"):
        built = _deploy_ext(tmp_path / "project", ext, body, target)
        assert built.returncode == 0, built.stdout + built.stderr
        assert "2 libraries of other packages shipped" in _text(built.stdout)

    deploy = tmp_path / "project" / "build" / "deploy"
    assert _files(deploy / "first-Release") == {f"bin/app{EXE}", SHARED_LIB, *EXT_FILES, *REPORT}
    assert _files(deploy / "second-Release") == {f"bin/sample{EXE}", SHARED_LIB, *EXT_FILES, *REPORT}
    if not WINDOWS:
        assert (deploy / "first-Release" / EXT_SYMLINK).is_symlink()
    for folder, program in (("first-Release", "app"), ("second-Release", "sample")):
        run = subprocess.run([str(deploy / folder / "bin" / f"{program}{EXE}")], env=_clean_environment(), check=False)
        assert run.returncode == 0


def _plugin(ext: Path) -> str:
    """CMake code: the imported target fakeplugin, the plugin of the other package."""
    return (
        "add_library(fakeplugin MODULE IMPORTED)\n"
        f'set_target_properties(fakeplugin PROPERTIES IMPORTED_LOCATION "{(ext / PLUGIN_FILE).as_posix()}")\n'
    )


def test_plugins(tmp_path: Path) -> None:
    """A plugin goes to its DESTINATION with the libraries it needs (ext3, which the application does not need; found
    on Windows in the folders of the DLLs of the targets); loaded from the deployment with an empty environment, it
    finds them (Linux, macOS: its RPATH, $ORIGIN/../../lib)."""
    ext = _external(tmp_path)
    body = _plugin(ext) + "cs_deployment(demo TARGETS app PLUGINS fakeplugin DESTINATION plugins/platforms/)\n"

    built = _deploy_ext(tmp_path / "project", ext, body)

    assert built.returncode == 0, built.stdout + built.stderr
    deploy = tmp_path / "project" / "build" / "deploy" / "demo-Release"
    assert _files(deploy) == {f"bin/app{EXE}", SHARED_LIB, *EXT_FILES, EXT3_FILE, PLUGIN_FILE, *REPORT}
    if not WINDOWS:  # Windows: the DLLs of a plugin are found next to the executable that loads it
        load = f"import ctypes; ctypes.CDLL({str(deploy / PLUGIN_FILE)!r})"
        assert subprocess.run([sys.executable, "-c", load], env={}, check=False).returncode == 0


def test_a_plugin_of_a_subfolder(tmp_path: Path) -> None:
    """The plugin target defined in a subfolder (an imported target is visible there only, e.g. a find_package(Qt6) of
    the folder of the application), its deployment declared there: shipped and scanned, the project finalized at the
    top."""
    ext = _external(tmp_path)
    files = {
        **EXT_SOURCES,
        "sub/CMakeLists.txt": _plugin(ext) + "cs_deployment(demo PLUGINS fakeplugin DESTINATION plugins/platforms)\n",
    }
    args = [*RELEASE, f"-DCMAKE_PREFIX_PATH={ext.as_posix()}"]
    body = INIT + TARGETS + EXT_TARGETS + "cs_deployment(demo TARGETS app)\nadd_subdirectory(sub)\n"
    result = configure(tmp_path / "project", body, files, args=args)
    assert result.returncode == 0, result.output

    built = _build(tmp_path / "project", "cs_deploy_demo")

    assert built.returncode == 0, built.stdout + built.stderr
    assert {PLUGIN_FILE, EXT3_FILE} <= _files(tmp_path / "project" / "build" / "deploy" / "demo-Release")


def test_a_library_not_found_fails(tmp_path: Path) -> None:
    """A library of the other package removed after the build: not found, the deployment fails, and so does the
    install."""
    ext = _external(tmp_path)
    project = tmp_path / "project"
    configured = configure(
        project,
        INIT + TARGETS + EXT_TARGETS + "cs_deployment(demo TARGETS app)\n",
        EXT_SOURCES,
        args=[*RELEASE, f"-DCMAKE_PREFIX_PATH={ext.as_posix()}"],
    )
    assert configured.returncode == 0, configured.output
    assert _build(project, "app").returncode == 0
    for name in _ext_files("ext2"):
        (ext / name).unlink()

    run = subprocess.run(
        ["cmake", "--install", "build", "--prefix", "install"], cwd=project, capture_output=True, text=True, check=False
    )

    assert run.returncode != 0
    output = _text(run.stdout + run.stderr)
    assert "libraries not found from the build tree" in output, output
    assert "ext2" in output.split("libraries not found from the build tree")[1]


@rpath_only
def test_a_binary_not_finding_its_libraries_fails(tmp_path: Path) -> None:
    """The install RPATH of the application does not reach lib/: the check fails."""
    ext = _external(tmp_path)
    origin = "@loader_path" if MACOS else "$ORIGIN"
    body = f'set_target_properties(app PROPERTIES INSTALL_RPATH "{origin}/nowhere")\ncs_deployment(demo TARGETS app)\n'

    built = _deploy_ext(tmp_path / "project", ext, body)

    assert built.returncode != 0
    assert "libraries not found from the deployment" in _text(built.stdout + built.stderr)


@rpath_only
def test_a_shadowed_library_fails(tmp_path: Path) -> None:
    """The application finds the library of the other package outside the deployment (an absolute RPATH first), while
    the deployment ships it: the check fails."""
    ext = _external(tmp_path)
    origin = "@loader_path" if MACOS else "$ORIGIN"
    body = (
        f'set_target_properties(app PROPERTIES INSTALL_RPATH "{ext}/lib;{origin}/../lib")\n'
        "cs_deployment(demo TARGETS app)\n"
    )

    built = _deploy_ext(tmp_path / "project", ext, body)

    assert built.returncode != 0
    output = _text(built.stdout + built.stderr)
    assert "resolves to" in output
    assert "which ships it: a binary does not find the copy of the deployment" in output


def test_excluded_libraries(tmp_path: Path) -> None:
    """EXCLUDE_REGEXES: not shipped (the machines running the deployment have it), and ignored by the check."""
    ext = _external(tmp_path)

    built = _deploy_ext(tmp_path / "project", ext, "cs_deployment(demo TARGETS app EXCLUDE_REGEXES ext2[.])\n")

    assert built.returncode == 0, built.stdout + built.stderr
    deployed = _files(tmp_path / "project" / "build" / "deploy" / "demo-Release")
    assert deployed == {f"bin/app{EXE}", SHARED_LIB, *_ext_files("ext"), *REPORT}


@linux_only
def test_libraries_without_rpath(tmp_path: Path) -> None:
    """The other package without RPATH: libext does not find libext2 (its RPATH), the deployment fails. (macOS: found
    through the RPATH of the executable from the build tree, then not from the deployment: the check fails.)"""
    ext = _external(tmp_path, rpath="")

    built = _deploy_ext(tmp_path / "project", ext, "cs_deployment(demo TARGETS app)\n")

    assert built.returncode != 0
    output = _text(built.stdout + built.stderr)
    assert "libraries not found from the build tree (Linux, macOS: a library without the RPATH" in output, output
    assert "ext2" in output.split("libraries not found from the build tree")[1]


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


@windows_only
def test_msvc_runtime(tmp_path: Path) -> None:
    """Windows with MSVC: the C++ runtime of MSVC next to the executables, unless MSVC_RUNTIME OFF."""
    deploy = _deploy(tmp_path / "on", "cs_deployment(demo TARGETS app)\n", "cs_deploy_demo")
    assert "bin/vcruntime140.dll" in _all_files(deploy / "demo-Release")

    deploy = _deploy(tmp_path / "off", "cs_deployment(demo TARGETS app MSVC_RUNTIME OFF)\n", "cs_deploy_demo")
    assert not any(MSVC_RUNTIME_FILE.match(name) for name in _all_files(deploy / "demo-Release"))


@windows_only
def test_debug_runtime_fails(tmp_path: Path) -> None:
    """Windows with MSVC: a Debug deployment needs the debug C runtime of MSVC, not redistributable: it fails."""
    result = configure(tmp_path, INIT + TARGETS + "cs_deployment(demo TARGETS app CONFIGS Debug)\n", SOURCES)
    assert result.returncode == 0, result.output

    built = _build(tmp_path, "cs_deploy_demo")

    assert built.returncode != 0
    assert "a debug C runtime of MSVC, not redistributable" in _text(built.stdout + built.stderr)


@pytest.mark.parametrize(
    ("body", "message"),
    [
        (
            "cs_deployment(demo TARGETS app EXCLUDE_REGEXES a)\ncs_deployment(demo EXCLUDE_REGEXES b)",
            "EXCLUDE_REGEXES b, but already EXCLUDE_REGEXES a (given once per deployment)",
        ),
        ("cs_deployment(demo TARGETS app DIRECTORIES missing)", "DIRECTORIES missing is not a folder"),
        (
            "cs_deployment(demo TARGETS app DIRECTORIES data)\ncs_deployment(demo DIRECTORIES data/sub)",
            "but already DIRECTORIES",
        ),
        ("cs_deployment(demo TARGETS app MSVC_RUNTIME maybe)", "MSVC_RUNTIME maybe: ON or OFF"),
        (
            "cs_deployment(demo TARGETS app MSVC_RUNTIME ON)\ncs_deployment(demo MSVC_RUNTIME OFF)",
            "MSVC_RUNTIME OFF, but already MSVC_RUNTIME ON (given once per deployment)",
        ),
        ("cs_deployment(demo TARGETS app PLUGINS nothing DESTINATION p)", "PLUGINS nothing is not a target"),
        (
            "cs_deployment(demo TARGETS app PLUGINS core DESTINATION p)",
            "PLUGINS core is not an imported module library",
        ),
        ("cs_deployment(demo TARGETS app PLUGINS core)", "PLUGINS, FILES and DIRECTORY go with DESTINATION"),
        (
            "add_library(p MODULE IMPORTED)\n"
            "cs_deployment(demo TARGETS app PLUGINS p DESTINATION a)\ncs_deployment(demo PLUGINS p DESTINATION b)",
            "PLUGINS p DESTINATION b, but already PLUGINS p DESTINATION a (given once per deployment)",
        ),
    ],
    ids=[
        "exclude-regexes-changed",
        "missing-directory",
        "directories-changed",
        "msvc-runtime-not-a-switch",
        "msvc-runtime-changed",
        "plugin-unknown",
        "plugin-not-imported",
        "plugin-without-destination",
        "plugin-destination-changed",
    ],
)
def test_closure_mistakes_fail(tmp_path: Path, body: str, message: str) -> None:
    result = configure(tmp_path, INIT + TARGETS + body + "\n", SOURCES)

    assert result.returncode != 0
    assert message in _text(result.output), result.output
