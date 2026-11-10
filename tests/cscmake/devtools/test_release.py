"""cscmake-release: the assets of a release from the tag, the project files and the built documentation."""

from __future__ import annotations

import hashlib
import tarfile
import zipfile
from pathlib import Path

import pytest

from cscmake.devtools.release import (
    PACKAGE_CONTENT,
    ReleaseError,
    build_release,
    main,
    parse_tag,
    project_version,
    release_notes,
)

CHANGELOG = """# Changelog

Intro.

## v0.2.0 (2026-11-10)

New things.

### Breaking

- Renamed.

## v0.1.0

First.
"""


def _repo(tmp_path: Path, version: str = "0.2.0") -> Path:
    root = tmp_path / "repo"
    for entry in PACKAGE_CONTENT:
        path = root / entry
        if path.suffix or entry == "LICENSE":
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(entry, encoding="utf-8")
        else:
            (path / "sub").mkdir(parents=True)
            (path / "sub" / "a.cmake").write_text(entry, encoding="utf-8")
            (path / "__pycache__").mkdir()
            (path / "__pycache__" / "x.pyc").write_text("", encoding="utf-8")
    (root / "pyproject.toml").write_text(f'[project]\nname = "cscmake"\nversion = "{version}"\n', encoding="utf-8")
    (root / "CHANGELOG.md").write_text(CHANGELOG, encoding="utf-8")
    (root / "presets" / "template").mkdir()
    (root / "presets" / "template" / "t.json.template").write_text("", encoding="utf-8")
    docs = tmp_path / "html"
    (docs / "_static").mkdir(parents=True)
    (docs / "index.html").write_text("<html/>", encoding="utf-8")
    (docs / "_static" / "style.css").write_text("", encoding="utf-8")
    return root


@pytest.mark.parametrize(
    ("tag", "expected"),
    [("v0.2.0", ("0.2.0", False)), ("v0.2.0-rc1", ("0.2.0", True)), ("v10.20.30-beta.2", ("10.20.30", True))],
)
def test_parse_tag(tag: str, expected: tuple[str, bool]) -> None:
    assert parse_tag(tag) == expected


@pytest.mark.parametrize("tag", ["0.2.0", "v0.2", "v0.2.0-", "release-0.2.0"])
def test_parse_tag_rejects(tag: str) -> None:
    with pytest.raises(ReleaseError, match="is not a release tag"):
        parse_tag(tag)


def test_the_repository_is_releasable() -> None:
    version = project_version(Path(__file__).resolve().parents[3])

    assert release_notes(Path(__file__).resolve().parents[3], version)


def test_release_notes(tmp_path: Path) -> None:
    root = _repo(tmp_path)

    assert release_notes(root, "0.2.0") == "New things.\n\n### Breaking\n\n- Renamed.\n"
    assert release_notes(root, "0.1.0") == "First.\n"
    with pytest.raises(ReleaseError, match="no section '## v0.3.0'"):
        release_notes(root, "0.3.0")


def test_build_release(tmp_path: Path) -> None:
    root = _repo(tmp_path)
    output = tmp_path / "dist"

    paths = build_release("v0.2.0-rc1", tmp_path / "html", output, root)

    assert [p.name for p in paths] == [
        "csCMake-0.2.0-rc1.tar.gz",
        "csCMake-0.2.0-rc1.zip",
        "csCMake-docs-0.2.0-rc1.zip",
        "SHA256SUMS",
        "release-notes.md",
    ]
    with tarfile.open(output / "csCMake-0.2.0-rc1.tar.gz") as tar:
        tar_names = tar.getnames()
    with zipfile.ZipFile(output / "csCMake-0.2.0-rc1.zip") as archive:
        zip_names = archive.namelist()
    assert tar_names == zip_names
    assert "csCMake/csCMake.cmake" in tar_names
    assert "csCMake/presets/csv1/sub/a.cmake" in tar_names
    assert not [n for n in tar_names if "__pycache__" in n or "template/" in n or "pyproject" in n]
    with zipfile.ZipFile(output / "csCMake-docs-0.2.0-rc1.zip") as archive:
        assert sorted(archive.namelist()) == [
            "csCMake-docs-0.2.0-rc1/_static/style.css",
            "csCMake-docs-0.2.0-rc1/index.html",
        ]
    checksums = (output / "SHA256SUMS").read_text(encoding="utf-8").splitlines()
    tar_sum = hashlib.sha256((output / "csCMake-0.2.0-rc1.tar.gz").read_bytes()).hexdigest()
    assert checksums[0] == f"{tar_sum}  csCMake-0.2.0-rc1.tar.gz"
    assert len(checksums) == 3
    assert (output / "release-notes.md").read_text(encoding="utf-8").startswith("New things.")


def test_the_tag_must_match_the_project_version(tmp_path: Path) -> None:
    root = _repo(tmp_path, version="0.1.0")

    with pytest.raises(ReleaseError, match=r"tag v0.2.0 does not match the version 0.1.0 of pyproject.toml"):
        build_release("v0.2.0", tmp_path / "html", tmp_path / "dist", root)


def test_the_documentation_must_be_built(tmp_path: Path) -> None:
    root = _repo(tmp_path)

    with pytest.raises(ReleaseError, match="no index.html"):
        build_release("v0.2.0", tmp_path / "missing", tmp_path / "dist", root)


def test_main(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    root = _repo(tmp_path)
    args = ["--docs", str(tmp_path / "html"), "--output", str(tmp_path / "dist"), "--root", str(root)]

    assert main(["--tag", "v0.2.0", *args]) == 0
    assert "SHA256SUMS" in capsys.readouterr().out
    assert main(["--tag", "v0.3.0", *args]) == 1
    assert "does not match the version" in capsys.readouterr().err
