"""cscmake-update-cmake-inventory: the local copy of the CMake documentation inventory (no network in these tests)."""

from __future__ import annotations

import zlib
from pathlib import Path

import pytest

from cscmake.devtools import cmake_inventory
from cscmake.devtools.cmake_inventory import (
    CMAKE_DOCS_VERSION,
    DOCS_DIR,
    InventoryError,
    check_inventory,
    docs_url,
    inventory_path,
    update,
)

HEADER = b"# Sphinx inventory version 2\n# Project: CMake\n# Version: 3.31\n# The remainder is compressed using zlib.\n"
OBJECTS = b"target_sources cmake:command 1 command/target_sources.html#$ -\n"


def _inventory(objects: bytes = OBJECTS) -> bytes:
    return HEADER + zlib.compress(objects)


def test_committed_inventory_is_the_one_of_the_docs_version() -> None:
    inventories = sorted(p.name for p in (DOCS_DIR / "_inventories").glob("cmake-*.inv"))

    assert inventories == [Path(inventory_path()).name]
    check_inventory((DOCS_DIR / inventory_path()).read_bytes())


def test_urls_and_paths_follow_the_version() -> None:
    assert docs_url("4.0") == "https://cmake.org/cmake/help/v4.0"
    assert inventory_path("4.0") == "_inventories/cmake-4.0.inv"


@pytest.mark.parametrize(
    ("data", "message"),
    [
        (b"<html>not found</html>", "not a Sphinx inventory"),
        (HEADER.split(b"\n# The")[0] + b"\n", "truncated"),
        (HEADER + b"plain text", "not zlib-compressed"),
        (_inventory(b"foo py:function 1 foo.html#$ -\n"), "no CMake command"),
    ],
)
def test_invalid_inventories_are_rejected(data: bytes, message: str) -> None:
    with pytest.raises(InventoryError, match=message):
        check_inventory(data)


def test_update_writes_the_inventory_and_removes_other_versions(tmp_path: Path) -> None:
    stale = tmp_path / "_inventories" / "cmake-3.30.inv"
    stale.parent.mkdir()
    stale.write_bytes(_inventory())
    urls: list[str] = []

    def fetch(url: str) -> bytes:
        urls.append(url)
        return _inventory()

    target = update(tmp_path, "3.31", fetch)

    assert urls == ["https://cmake.org/cmake/help/v3.31/objects.inv"]
    assert target == tmp_path / "_inventories" / "cmake-3.31.inv"
    assert target.read_bytes() == _inventory()
    assert not stale.exists()


def test_update_writes_nothing_when_the_download_is_invalid(tmp_path: Path) -> None:
    with pytest.raises(InventoryError):
        update(tmp_path, "3.31", lambda _url: b"<html>error</html>")

    assert not (tmp_path / "_inventories").exists()


def test_main_reports_errors(monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    def failing_update() -> Path:
        raise OSError("network unreachable")

    monkeypatch.setattr(cmake_inventory, "update", failing_update)

    assert cmake_inventory.main([]) == 1
    assert "network unreachable" in capsys.readouterr().err


def test_main_reports_the_written_file(
    monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str], tmp_path: Path
) -> None:
    monkeypatch.setattr(cmake_inventory, "update", lambda: tmp_path / "cmake.inv")

    assert cmake_inventory.main([]) == 0
    assert f"{docs_url(CMAKE_DOCS_VERSION)}/objects.inv" in capsys.readouterr().out


def test_download_reads_the_url(tmp_path: Path) -> None:
    path = tmp_path / "objects.inv"
    path.write_bytes(_inventory())

    assert cmake_inventory.download(path.as_uri()) == _inventory()
