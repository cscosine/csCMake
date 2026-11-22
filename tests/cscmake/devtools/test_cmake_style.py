"""The CMake files of csCMake follow the CMake rules of cscosine (cscmake-lint, from cs-pre-commit-hooks)."""

from __future__ import annotations

from pathlib import Path

from cs_pre_commit_hooks.cmake_lint import lint_text

REPO_ROOT = Path(__file__).resolve().parents[3]


def test_the_repository_is_clean() -> None:
    files = [
        REPO_ROOT / "csCMake.cmake",
        REPO_ROOT / "csCMakeSetup.cmake",
        *(REPO_ROOT / "modules").rglob("*.cmake"),
        *(REPO_ROOT / "templates").glob("*.cmake.in"),
        *(REPO_ROOT / "tests" / "smoke").rglob("CMakeLists.txt"),
    ]
    findings = [f for path in files for f in lint_text(path.read_text(encoding="utf-8"), str(path))]

    assert findings == []
