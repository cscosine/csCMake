"""The quick start of README.md is the smoke project myApp (GitHub shows README.md as written: no include)."""

from __future__ import annotations

import json
import re

from tests.smoke.run_smoke import REPO_ROOT, SMOKE_DIR

README = (REPO_ROOT / "README.md").read_text(encoding="utf-8")
MY_APP = SMOKE_DIR / "myApp"


def test_the_cmake_files_of_the_quick_start_are_the_ones_of_myapp() -> None:
    for name in ("CMakeLists.txt", "myApp/CMakeLists.txt"):
        text = (MY_APP / name).read_text(encoding="utf-8")
        assert f"```cmake\n{text}```" in README, f"README.md: the block of myApp/{name} differs from {MY_APP / name}"


def test_the_preset_files_of_the_quick_start_are_the_ones_of_myapp() -> None:
    """In this order: CMakePresets.json, csCMakeProjectSetup.json (same content, formatted on one line)."""
    blocks = [json.loads(block) for block in re.findall(r"```json\n(.*?)```", README, re.DOTALL)]
    expected = [
        json.loads((MY_APP / name).read_text(encoding="utf-8"))
        for name in ("CMakePresets.json", "csCMakeProjectSetup.json")
    ]
    assert blocks[:2] == expected
