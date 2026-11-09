import json
from pathlib import Path

import pytest

from cscmake.presets.generate import (
    CS_PRESETS_ALL_JSON,
    OUTPUT_DIR,
    TEMPLATE_DIR,
    check_presets_up_to_date,
    generate_all_csv1_presets,
    main,
)
from cscmake.presets.registry import get_supported_context_os_architecture_list

# per variant: -ALL, -base and one file per single build type (debug, release, relwithdebinfo, paranoid)
FILES_PER_VARIANT = 6


@pytest.fixture
def generated(tmp_path: Path) -> Path:
    generate_all_csv1_presets(TEMPLATE_DIR, tmp_path)
    return tmp_path


def test_generates_full_matrix(tmp_path: Path) -> None:
    names = generate_all_csv1_presets(TEMPLATE_DIR, tmp_path)
    n_variants = len(get_supported_context_os_architecture_list())

    assert len(names) == len(set(names)) == n_variants * FILES_PER_VARIANT + 1
    assert sorted(p.name for p in tmp_path.iterdir()) == sorted(names)
    assert CS_PRESETS_ALL_JSON in names


def test_generated_files_are_valid_json_with_lf_endings(generated: Path) -> None:
    for path in generated.glob("*.json"):
        data = path.read_bytes()
        assert b"\r" not in data, path.name
        assert data.endswith(b"\n"), path.name
        assert isinstance(json.loads(data), dict), path.name


def test_includes_resolve(generated: Path) -> None:
    """Every include points to a generated sibling or to an existing file next to presets/csv1."""
    for path in generated.glob("*.json"):
        for include in json.loads(path.read_text(encoding="utf-8")).get("include", []):
            if include.startswith("${"):  # CMake macros (e.g. ${sourceDir}) resolve in the consumer project
                continue
            if "/" in include:
                assert (OUTPUT_DIR / include).resolve().is_file(), f"{path.name}: {include}"
            else:
                assert (generated / include).is_file(), f"{path.name}: {include}"


def test_presets_all_includes_every_all_preset_sorted(generated: Path) -> None:
    includes = json.loads((generated / CS_PRESETS_ALL_JSON).read_text(encoding="utf-8"))["include"]
    # filter by name, not glob("*-ALL.json"): globbing is case-insensitive on Windows (matches cs-presets-all.json)
    all_presets = sorted(p.name for p in generated.glob("*.json") if p.name.endswith("-ALL.json"))

    assert includes == all_presets


def test_generation_is_deterministic(generated: Path, tmp_path_factory: pytest.TempPathFactory) -> None:
    other = tmp_path_factory.mktemp("again")
    generate_all_csv1_presets(TEMPLATE_DIR, other)

    assert check_presets_up_to_date(TEMPLATE_DIR, other) == []
    assert {p.name: p.read_bytes() for p in generated.iterdir()} == {p.name: p.read_bytes() for p in other.iterdir()}


def test_stale_json_removed_other_files_kept(tmp_path: Path) -> None:
    (tmp_path / "csv1-removed-variant-ALL.json").write_text("{}", encoding="utf-8")
    (tmp_path / "notes.txt").write_text("keep me", encoding="utf-8")

    generate_all_csv1_presets(TEMPLATE_DIR, tmp_path)

    assert not (tmp_path / "csv1-removed-variant-ALL.json").exists()
    assert (tmp_path / "notes.txt").exists()


def test_check_detects_modified_missing_and_extra_files(generated: Path) -> None:
    assert check_presets_up_to_date(TEMPLATE_DIR, generated) == []

    modified = generated / CS_PRESETS_ALL_JSON
    modified.write_text(modified.read_text(encoding="utf-8") + " ", encoding="utf-8")
    missing = next(generated.glob("*-base.json"))
    missing.unlink()
    (generated / "extra.json").write_text("{}", encoding="utf-8")

    assert check_presets_up_to_date(TEMPLATE_DIR, generated) == sorted([modified.name, missing.name, "extra.json"])


def test_main_generate_then_check(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    assert main(["--output-dir", str(tmp_path), "--quiet"]) == 0
    assert capsys.readouterr().out == ""

    assert main(["--output-dir", str(tmp_path), "--check"]) == 0

    (tmp_path / CS_PRESETS_ALL_JSON).write_text("{}", encoding="utf-8")
    assert main(["--output-dir", str(tmp_path), "--check"]) == 1
    assert f"Out of date: {CS_PRESETS_ALL_JSON}" in capsys.readouterr().out


def test_main_lists_generated_files(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    assert main(["--output-dir", str(tmp_path)]) == 0
    assert f"Generated: {CS_PRESETS_ALL_JSON}" in capsys.readouterr().out


def test_check_does_not_write(tmp_path: Path) -> None:
    assert main(["--output-dir", str(tmp_path), "--check"]) == 1
    assert list(tmp_path.iterdir()) == []


def test_main_missing_template_dir_errors(tmp_path: Path) -> None:
    with pytest.raises(SystemExit) as exc:
        main(["--template-dir", str(tmp_path / "nope"), "--output-dir", str(tmp_path)])
    assert exc.value.code == 2
