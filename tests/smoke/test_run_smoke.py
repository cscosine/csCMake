import os
import platform
import re
from pathlib import Path

import pytest

from cscmake.presets.registry import (
    OS,
    Architecture,
    create_context_os_architecture_compiler_generator_string,
    get_supported_context_os_architecture_list,
)
from tests.smoke.run_smoke import (
    CONFIGS,
    PROJECTS,
    SMOKE_DIR,
    SmokeError,
    check_debugger_environment,
    check_environment_script_output,
    config_find_dependencies,
    debugger_environments,
    find_variant,
    line_ending,
    prepare_workspace,
    relocate_install,
    relocated_prefixes,
    run_smoke,
    workflow_presets,
)

MULTI = "csv1-linux-ubuntu24.04-x64-generic-gcc-default-ninjamulticonfig"
SINGLE = "csv1-linux-ubuntu24.04-x64-generic-gcc-default-ninja"


def test_workflow_presets_exist_in_generated_presets() -> None:
    presets_dir = Path(__file__).resolve().parents[2] / "presets" / "csv1"
    defined = set(re.findall(r'"name": "(workflow-[^"]+)"', "".join(p.read_text() for p in presets_dir.glob("*.json"))))
    for ctx in get_supported_context_os_architecture_list():
        assert set(workflow_presets(ctx)) <= defined
        assert set(workflow_presets(ctx, debug_release=True)) <= defined


def test_multi_config_runs_one_workflow_single_config_one_per_config() -> None:
    assert workflow_presets(find_variant(MULTI)) == [f"workflow-{MULTI}-debug-release-relWithDebInfo-paranoid"]
    assert workflow_presets(find_variant(SINGLE)) == [f"workflow-{SINGLE}-{c.preset}" for c in CONFIGS]


def test_a_debug_release_project_builds_debug_and_release() -> None:
    assert workflow_presets(find_variant(MULTI), debug_release=True) == [f"workflow-{MULTI}-debug-release"]
    assert workflow_presets(find_variant(SINGLE), debug_release=True) == [
        f"workflow-{SINGLE}-debug",
        f"workflow-{SINGLE}-release",
    ]


def test_unknown_variant_is_rejected() -> None:
    with pytest.raises(SmokeError):
        find_variant("csv1-plan9-v4-mips-generic-tcc-default-make")


def test_prepare_workspace_lays_out_siblings_and_cleans_leftovers(tmp_path: Path) -> None:
    (tmp_path / "install" / "stale").mkdir(parents=True)
    prepare_workspace(tmp_path)

    assert (tmp_path / "csCMake" / "csCMake.cmake").is_file()
    assert (tmp_path / "csCMake" / "presets" / "csv1" / "cs-presets-all.json").is_file()
    for project in PROJECTS:
        assert (tmp_path / project.name / "CMakePresets.json").is_file(), project.name
    assert not (tmp_path / "install").exists()


def test_every_smoke_project_is_run() -> None:
    """Every project folder in tests/smoke is part of PROJECTS (and vice versa)."""
    folders = {p.name for p in SMOKE_DIR.iterdir() if (p / "CMakeLists.txt").is_file()}
    assert folders == {project.name for project in PROJECTS}


def _host_variants() -> list[str]:
    """Preset variants this machine can build (override with CSCMAKE_SMOKE_VARIANTS=id1,id2)."""
    if os.environ.get("CSCMAKE_SMOKE_VARIANTS"):
        return os.environ["CSCMAKE_SMOKE_VARIANTS"].split(",")
    if platform.system() != "Linux" or not Path("/etc/os-release").is_file():
        return []  # Windows: pick the installed Visual Studio with CSCMAKE_SMOKE_VARIANTS
    release = dict(line.split("=", 1) for line in Path("/etc/os-release").read_text().splitlines() if "=" in line)
    os_version = release.get("ID", "").strip('"') + release.get("VERSION_ID", "").strip('"')
    arch = Architecture.ARM64 if platform.machine().lower() in ("aarch64", "arm64") else Architecture.X64
    return [
        create_context_os_architecture_compiler_generator_string(c)
        for c in get_supported_context_os_architecture_list()
        if c.context_os_architecture.os == OS.LINUX
        and c.context_os_architecture.os_version == os_version
        and c.context_os_architecture.architecture == arch
    ]


@pytest.mark.slow
@pytest.mark.requires("cmake")
@pytest.mark.parametrize(
    "variant", _host_variants() or [pytest.param("none", marks=pytest.mark.skip("no host variant"))]
)
def test_smoke_host_variant(variant: str, tmp_path: Path) -> None:
    run_smoke(variant, tmp_path)


def test_line_ending_detection(tmp_path: Path) -> None:
    unix, windows, mixed = tmp_path / "unix", tmp_path / "windows", tmp_path / "mixed"
    unix.write_bytes(b"a\nb\n")
    windows.write_bytes(b"a\r\nb\r\n")
    mixed.write_bytes(b"a\r\nb\n")

    assert line_ending(unix) == "unix"
    assert line_ending(windows) == "windows"
    with pytest.raises(SmokeError, match="mixed line endings"):
        line_ending(mixed)


def test_config_find_dependencies() -> None:
    text = """
macro(pkg_find_dependency_for_component COMPONENT_NAME)
  if(NOT pkgConfig_a_FIND_DONE)
      pkg_debug_message("[pkgConfig] find_dependency(csSmokeBase COMPONENTS text REQUIRED CONFIG)")
      find_dependency(csSmokeBase COMPONENTS text REQUIRED CONFIG)
      find_dependency(Eigen3)
  endif()
endmacro()
"""
    assert config_find_dependencies(text) == {"csSmokeBase", "Eigen3"}
    assert config_find_dependencies("# nothing injected\n") == set()


VCXPROJ = """<?xml version="1.0" encoding="UTF-8"?>
<Project DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|x64'">
    <LocalDebuggerEnvironment>PATH=C:\\ws\\runtime\\Debug;C:/ws/build/bin/Debug;%PATH%</LocalDebuggerEnvironment>
  </PropertyGroup>
  <PropertyGroup>
    <LocalDebuggerEnvironment Condition="'$(Configuration)|$(Platform)'=='Release|x64'"
      >PATH=C:/r;%PATH%</LocalDebuggerEnvironment>
  </PropertyGroup>
</Project>
"""


def test_debugger_environments_of_each_configuration(tmp_path: Path) -> None:
    """The condition on the property group or on the element itself (both are valid MSBuild)."""
    vcxproj = tmp_path / "app.vcxproj"
    vcxproj.write_text(VCXPROJ, encoding="utf-8")

    assert debugger_environments(vcxproj) == {
        "Debug": "PATH=C:\\ws\\runtime\\Debug;C:/ws/build/bin/Debug;%PATH%",
        "Release": "PATH=C:/r;%PATH%",
    }


def _vs_workspace(tmp_path: Path, path_of: str) -> Path:
    """A workspace with a csSmokeSharedApp.vcxproj whose debugger PATH of each configuration is ``path_of``."""
    groups = "".join(
        f"<PropertyGroup Condition=\"'$(Configuration)|$(Platform)'=='{c.cmake}|x64'\">"
        f"<LocalDebuggerEnvironment>{path_of.format(config=c.cmake)}</LocalDebuggerEnvironment></PropertyGroup>"
        for c in CONFIGS
    )
    vcxproj = tmp_path / "build" / "variant" / "csSmokeShared" / "csSmokeSharedApp.vcxproj"
    vcxproj.parent.mkdir(parents=True)
    vcxproj.write_text(f'<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">{groups}</Project>')
    return tmp_path


def test_check_debugger_environment(tmp_path: Path) -> None:
    good = "CSSMOKE_CONFIG={config}\n" + r"PATH=C:\ws\csSmokeShared\runtime\{config};C:/ws/build/bin/{config};%PATH%"
    check_debugger_environment(_vs_workspace(tmp_path / "good", good), "variant")

    swapped = "CSSMOKE_CONFIG={config}\n" + r"PATH=C:/ws/build/bin/{config};C:/ws/csSmokeShared/runtime/{config};%PATH%"
    with pytest.raises(SmokeError, match="must come before"):
        check_debugger_environment(_vs_workspace(tmp_path / "swapped", swapped), "variant")

    with pytest.raises(SmokeError, match="expected CSSMOKE_CONFIG="):
        check_debugger_environment(_vs_workspace(tmp_path / "none", "A=1"), "variant")

    no_dlls = "CSSMOKE_CONFIG={config}\n" + r"PATH=C:/ws/csSmokeShared/runtime/{config};%PATH%"
    with pytest.raises(SmokeError, match="expected PATH="):
        check_debugger_environment(_vs_workspace(tmp_path / "no_dlls", no_dlls), "variant")


def test_check_environment_script_output(tmp_path: Path) -> None:
    """The variable, then PATH: runtime/<config>, the DLL folder of the build folder, the PATH before."""
    script = tmp_path / "cs-env.bat"
    bin_dir = (tmp_path / "bin").as_posix()
    good = f"CSSMOKE_CONFIG=Debug\r\nPATH=C:\\ws\\runtime\\Debug;{bin_dir}/Debug;C:\\Windows\r\n"
    check_environment_script_output(script, "Debug", good)

    with pytest.raises(SmokeError, match="CSSMOKE_CONFIG='Release'"):
        check_environment_script_output(script, "Debug", good.replace("=Debug", "=Release", 1))

    swapped = f"CSSMOKE_CONFIG=Debug\nPATH={bin_dir}/Debug;C:/ws/runtime/Debug;C:/Windows\n"
    with pytest.raises(SmokeError, match="expected"):
        check_environment_script_output(script, "Debug", swapped)


def test_relocate_install_moves_the_folder_and_finds_absolute_paths(tmp_path: Path) -> None:
    """Relative Config files move; one naming the folder it was installed in (any slash, any case on Windows) fails."""
    config = tmp_path / "install" / "variant" / "pkg" / "lib" / "cmake" / "pkg" / "pkgConfig.cmake"
    config.parent.mkdir(parents=True)
    config.write_text('get_filename_component(_prefix "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)\n')

    relocated = relocate_install(tmp_path)

    assert not (tmp_path / "install").exists()
    assert relocated_prefixes(relocated) == [relocated / "variant" / "pkg"]

    relocated.rename(tmp_path / "install")
    absolute = str(tmp_path / "install" / "variant" / "pkg").replace("/", "\\").upper()
    config.write_text(f'set(_prefix "{absolute}")\n')
    with pytest.raises(SmokeError, match="cannot be moved"):
        relocate_install(tmp_path)
