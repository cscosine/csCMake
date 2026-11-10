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
    config_find_dependencies,
    find_variant,
    line_ending,
    prepare_workspace,
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
        assert set(workflow_presets(ctx, plain=True)) <= defined


def test_multi_config_runs_one_workflow_single_config_one_per_config() -> None:
    assert workflow_presets(find_variant(MULTI)) == [f"workflow-{MULTI}-debug-release-relWithDebInfo-paranoid"]
    assert workflow_presets(find_variant(SINGLE)) == [f"workflow-{SINGLE}-{c.preset}" for c in CONFIGS]


def test_a_plain_project_builds_debug_and_release() -> None:
    assert workflow_presets(find_variant(MULTI), plain=True) == [f"workflow-{MULTI}-debug-release"]
    assert workflow_presets(find_variant(SINGLE), plain=True) == [
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
