"""Update the local copy of the CMake documentation inventory used by the csCMake documentation.

The csCMake reference links CMake's own commands, variables and properties (``:command:`target_sources```,
``:variable:`CMAKE_PREFIX_PATH```, ...) to the CMake documentation of the minimum CMake version of csCMake through
Sphinx intersphinx. Intersphinx needs the ``objects.inv`` inventory of that documentation (the list of its objects and
their pages); the docs build reads a local copy, ``docs/_inventories/cmake-<version>.inv``, so it needs no network and
always produces the same links.

This tool downloads ``https://cmake.org/cmake/help/v<version>/objects.inv`` for ``CMAKE_DOCS_VERSION``, checks it is a
Sphinx inventory of CMake objects, writes it and removes the inventories of other versions. Run it after changing
``CMAKE_DOCS_VERSION`` (when the minimum CMake version of csCMake changes); ``docs/conf.py`` reads the same constant.

Usage (from the dev venv):
    cscmake-update-cmake-inventory
"""

from __future__ import annotations

import argparse
import sys
import urllib.request
import zlib
from collections.abc import Callable
from pathlib import Path

# the CMake documentation linked by the csCMake documentation: the minimum CMake version of csCMake
CMAKE_DOCS_VERSION = "3.31"

REPO_ROOT = Path(__file__).resolve().parents[3]
DOCS_DIR = REPO_ROOT / "docs"
INVENTORY_DIR = "_inventories"

_HEADER = b"# Sphinx inventory version 2\n"
_HEADER_LINES = 4


class InventoryError(RuntimeError):
    """The downloaded file is not a Sphinx inventory of CMake objects."""


def docs_url(version: str = CMAKE_DOCS_VERSION) -> str:
    """Return the base URL of the CMake documentation of ``version``."""
    return f"https://cmake.org/cmake/help/v{version}"


def inventory_path(version: str = CMAKE_DOCS_VERSION) -> str:
    """Return the path of the local inventory of ``version``, relative to the docs folder (as ``conf.py`` uses it)."""
    return f"{INVENTORY_DIR}/cmake-{version}.inv"


def check_inventory(data: bytes) -> None:
    """Raise :class:`InventoryError` unless ``data`` is a Sphinx inventory (version 2) listing CMake commands."""
    if not data.startswith(_HEADER):
        raise InventoryError("not a Sphinx inventory (version 2)")
    parts = data.split(b"\n", _HEADER_LINES)
    if len(parts) <= _HEADER_LINES:
        raise InventoryError("truncated inventory")
    try:
        objects = zlib.decompress(parts[_HEADER_LINES])
    except zlib.error as error:
        raise InventoryError(f"the inventory content is not zlib-compressed: {error}") from error
    if b" cmake:command " not in objects:
        raise InventoryError("the inventory lists no CMake command")


def download(url: str) -> bytes:
    """Return the content of ``url``."""
    with urllib.request.urlopen(url, timeout=60) as response:
        data: bytes = response.read()
    return data


def update(
    docs_dir: Path = DOCS_DIR,
    version: str = CMAKE_DOCS_VERSION,
    fetch: Callable[[str], bytes] = download,
) -> Path:
    """Download and check the inventory of ``version``, write it in ``docs_dir``, remove the ones of other versions."""
    url = f"{docs_url(version)}/objects.inv"
    data = fetch(url)
    check_inventory(data)
    target = docs_dir / inventory_path(version)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
    for other in target.parent.glob("cmake-*.inv"):
        if other != target:
            other.unlink()
    return target


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.parse_args(argv)
    try:
        target = update()
    except (OSError, InventoryError) as error:
        print(f"cscmake-update-cmake-inventory: {error}", file=sys.stderr)
        return 1
    print(f"wrote {target} ({docs_url()}/objects.inv)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
