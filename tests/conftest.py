"""Opt-in markers and the requires marker of csCMake's tests (the mechanism: the root conftest.py, owned by the
project template).

- ``@pytest.mark.smoke``: the CMake smoke builds of the variants of this machine (``CSCMAKE_SMOKE_VARIANTS=id1,id2``
  to choose); skipped unless ``--run=smoke``, not part of ``--run-all``: the smoke workflow builds them on every
  runner image.
- ``@pytest.mark.requires("cmake", ...)``: skipped when one of the executables is not on PATH.
"""

from __future__ import annotations

import shutil

import pytest


def pytest_manual_markers() -> dict[str, str]:
    return {"smoke": "CMake smoke builds of the variants of this machine (the smoke workflow runs them in CI)"}


def pytest_configure(config: pytest.Config) -> None:
    config.addinivalue_line("markers", "requires(*tools): skipped when one of the executables is not on PATH")


def pytest_collection_modifyitems(config: pytest.Config, items: list[pytest.Item]) -> None:
    for item in items:
        for marker in item.iter_markers(name="requires"):
            missing = [tool for tool in marker.args if shutil.which(tool) is None]
            if missing:
                item.add_marker(pytest.mark.skip(reason=f"requires {', '.join(missing)} on PATH"))
