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
    CONSUMER,
    PRODUCER,
    SmokeError,
    find_variant,
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


def test_multi_config_runs_one_workflow_single_config_one_per_config() -> None:
    assert workflow_presets(find_variant(MULTI)) == [f"workflow-{MULTI}-debug-release-relWithDebInfo-paranoid"]
    assert workflow_presets(find_variant(SINGLE)) == [f"workflow-{SINGLE}-{c.preset}" for c in CONFIGS]


def test_unknown_variant_is_rejected() -> None:
    with pytest.raises(SmokeError):
        find_variant("csv1-plan9-v4-mips-generic-tcc-default-make")


def test_prepare_workspace_lays_out_siblings_and_cleans_leftovers(tmp_path: Path) -> None:
    (tmp_path / "install" / "stale").mkdir(parents=True)
    prepare_workspace(tmp_path)

    assert (tmp_path / "csCMake" / "csCMake.cmake").is_file()
    assert (tmp_path / "csCMake" / "presets" / "csv1" / "cs-presets-all.json").is_file()
    assert (tmp_path / PRODUCER / "CMakePresets.json").is_file()
    assert (tmp_path / CONSUMER / "CMakePresets.json").is_file()
    assert not (tmp_path / "install").exists()


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
