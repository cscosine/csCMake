"""pytest options and markers shared by the whole test suite.

- ``@pytest.mark.slow``: long tests (e.g. CMake smoke builds), skipped unless ``--run-all`` is given.
- ``@pytest.mark.requires("cmake", ...)``: skipped when one of the executables is not on PATH.
"""

from __future__ import annotations

import shutil

import pytest


def pytest_addoption(parser: pytest.Parser) -> None:
    parser.addoption("--run-all", action="store_true", default=False, help="also run the tests marked slow")


def pytest_collection_modifyitems(config: pytest.Config, items: list[pytest.Item]) -> None:
    run_all = config.getoption("--run-all")
    skip_slow = pytest.mark.skip(reason="slow test, use --run-all")
    for item in items:
        if "slow" in item.keywords and not run_all:
            item.add_marker(skip_slow)
        for marker in item.iter_markers(name="requires"):
            missing = [tool for tool in marker.args if shutil.which(tool) is None]
            if missing:
                item.add_marker(pytest.mark.skip(reason=f"requires {', '.join(missing)} on PATH"))
