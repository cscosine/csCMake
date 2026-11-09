import json
from pathlib import Path

import pytest

from cscmake.presets.registry import (
    create_context_os_architecture_compiler_generator_string,
    get_supported_context_os_architecture_list,
)
from tests.smoke.ci_matrix import main, matrix, runner


def test_matrix_has_one_entry_per_registry_variant() -> None:
    entries = matrix()["include"]
    variants = [
        create_context_os_architecture_compiler_generator_string(c)
        for c in get_supported_context_os_architecture_list()
    ]

    assert [e["variant"] for e in entries] == variants
    assert len(entries) == 34
    assert all(e["runner"] and e["generator_type"] in ("singleconfig", "multiconfig") for e in entries)


@pytest.mark.parametrize(
    ("variant", "expected"),
    [
        ("csv1-linux-ubuntu22.04-x64-generic-gcc-default-ninja", "ubuntu-22.04"),
        ("csv1-linux-ubuntu24.04-x64-generic-clang-default-ninjamulticonfig", "ubuntu-24.04"),
        ("csv1-linux-ubuntu22.04-arm64-generic-gcc-default-ninjamulticonfig", "ubuntu-22.04-arm"),
        ("csv1-linux-ubuntu24.04-arm64-generic-clang-default-ninja", "ubuntu-24.04-arm"),
        ("csv1-linux-ubuntu26.04-x64-generic-gcc-default-ninja", "ubuntu-26.04"),
        ("csv1-linux-ubuntu26.04-arm64-generic-clang-default-ninjamulticonfig", "ubuntu-26.04-arm"),
        ("csv1-windows-v10-x64-generic-msvc-default-msvc2022", "windows-2022"),
        ("csv1-windows-v10-x64-generic-msvcclang-default-msvc2026", "windows-2025-vs2026"),
        ("csv1-macos-macos15-arm64-generic-appleclang-default-ninja", "macos-15"),
        ("csv1-macos-macos26-arm64-generic-appleclang-default-xcode", "macos-26"),
    ],
)
def test_runner_labels(variant: str, expected: str) -> None:
    by_id = {
        create_context_os_architecture_compiler_generator_string(c): c
        for c in get_supported_context_os_architecture_list()
    }

    assert runner(by_id[variant]) == expected


def test_main_writes_github_output(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    out = tmp_path / "github_output"
    monkeypatch.setenv("GITHUB_OUTPUT", str(out))

    assert main() == 0
    key, value = out.read_text(encoding="utf-8").strip().split("=", 1)
    assert key == "matrix"
    assert json.loads(value) == matrix() == json.loads(capsys.readouterr().out)
