"""cscmake-check-docs: completeness of the reference documentation of the CMake modules."""

from __future__ import annotations

from pathlib import Path

import pytest

from cscmake.devtools.check_docs import check, entry_pattern, main, names_in_code

HEADER = """#.rst:
# csThing
# -------
#
# Things.
include_guard(GLOBAL)
"""

DOCUMENTED = """
#.rst:
# .. command:: cs_thing
#
#   Do a thing.
#
#   :Writes: :prop_tgt:`CSCMAKE_THING_<CONFIG>`
function(cs_thing target_name)
  set_property(TARGET ${target_name} PROPERTY CSCMAKE_THING_${config} TRUE)
endfunction()

# Private helper.
function(_cs_helper)
  set(CSCMAKE_SETTING ON)
endfunction()

#.rst:
# Target properties
# ^^^^^^^^^^^^^^^^^
#
# .. prop_tgt:: CSCMAKE_THING_<CONFIG>
#
#   A thing.
#
# .. variable:: CSCMAKE_SETTING
#
#   A setting.
"""


def _repo(tmp_path: Path, module: str, page: bool = True) -> Path:
    (tmp_path / "modules").mkdir()
    (tmp_path / "modules" / "csThing.cmake").write_text(module, encoding="utf-8")
    if page:
        (tmp_path / "docs" / "reference").mkdir(parents=True)
        (tmp_path / "docs" / "reference" / "csThing.rst").write_text(".. cmake-module:: x\n", encoding="utf-8")
    return tmp_path


def test_the_repository_is_complete() -> None:
    assert check() == []


def test_a_complete_module(tmp_path: Path) -> None:
    assert check(_repo(tmp_path, HEADER + DOCUMENTED)) == []


@pytest.mark.parametrize(
    ("change", "problem"),
    [
        (
            ("#.rst:\n# .. command:: cs_thing\n", "# Do a thing.\n"),
            "public command cs_thing has no '.. command::' block",
        ),
        (("command:: cs_thing", "command:: cs_other"), "'.. command:: cs_other' documents the function cs_thing"),
        (("function(_cs_helper)", "\nfunction(_cs_helper)"), ""),
        (("CSCMAKE_THING_${config}", "CSCMAKE_STUFF_${config}"), "CSCMAKE_STUFF_<x> is not documented"),
        (("set(CSCMAKE_SETTING ON)", "set(other ON)"), "'.. variable:: CSCMAKE_SETTING' is not used by the code"),
    ],
)
def test_problems(tmp_path: Path, change: tuple[str, str], problem: str) -> None:
    module = (HEADER + DOCUMENTED).replace(*change)

    problems = check(_repo(tmp_path, module))

    if problem:
        assert any(problem in p for p in problems), problems
    else:
        assert problems == []


@pytest.mark.parametrize(
    ("code", "problems"), [("set(_cs_switch ON)", 0), ("set(other ON)", 1)], ids=["used", "unused"]
)
def test_an_entry_outside_the_cscmake_naming_is_matched_as_written(tmp_path: Path, code: str, problems: int) -> None:
    """A documented name that is not CSCMAKE_* (e.g. a lowercase variable): used when the code has it as written."""
    module = (
        HEADER
        + DOCUMENTED.replace("set(CSCMAKE_SETTING ON)", f"set(CSCMAKE_SETTING ON)\n  {code}")
        + ("#\n# .. variable:: _cs_switch\n#\n#   A switch.\n")
    )

    found = check(_repo(tmp_path, module))

    unused = [p for p in found if p.endswith("'.. variable:: _cs_switch' is not used by the code")]
    assert len(unused) == problems, found


def test_a_command_block_not_above_its_function(tmp_path: Path) -> None:
    module = HEADER + DOCUMENTED.replace("function(cs_thing target_name)", "set(x 1)\nfunction(cs_thing target_name)")

    problems = check(_repo(tmp_path, module))

    assert any("'.. command:: cs_thing' is not right above its function" in p for p in problems), problems
    assert any("public command cs_thing has no" in p for p in problems), problems


def test_a_documented_module_needs_its_page(tmp_path: Path) -> None:
    problems = check(_repo(tmp_path, HEADER + DOCUMENTED, page=False))

    assert problems == ["modules/csThing.cmake:1: no reference page docs/reference/csThing.rst"]


def test_names_in_code() -> None:
    line = (
        "set_property(GLOBAL PROPERTY CSCMAKE_${CSCMAKE_NAMESPACE}_COMPONENT_${name}_TARGETS ${PROJECT_NAME}_CSCMAKE_X)"
    )

    assert sorted(names_in_code(line)) == [
        "<x>_CSCMAKE_X",
        "CSCMAKE_<x>_COMPONENT_<x>_TARGETS",
        "CSCMAKE_NAMESPACE",
    ]


def test_entry_placeholders_match_anything() -> None:
    pattern = entry_pattern("CSCMAKE_<namespace>_COMPONENT_<component>_TARGETS")

    assert pattern.match("CSCMAKE_<x>_COMPONENT_<x>_TARGETS")
    assert pattern.match("CSCMAKE_myApp_COMPONENT_core_TARGETS")
    assert not pattern.match("CSCMAKE_<x>_COMPONENTS")


def test_main(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    root = _repo(tmp_path, HEADER + DOCUMENTED.replace("CSCMAKE_THING_${config}", "CSCMAKE_STUFF"))

    assert main(["--root", str(root)]) == 1
    assert "CSCMAKE_STUFF is not documented" in capsys.readouterr().out
    assert main([]) == 0


def test_a_comment_between_a_command_block_and_its_function(tmp_path: Path) -> None:
    module = HEADER + DOCUMENTED.replace("function(cs_thing target_name)", "  # a note\nfunction(cs_thing target_name)")

    assert check(_repo(tmp_path, module)) == []


@pytest.mark.parametrize(
    "module",
    [
        HEADER + DOCUMENTED.replace("function(cs_thing target_name)", "\nfunction(cs_thing target_name)"),
        HEADER + "#.rst:\n# .. command:: cs_thing\n#\n#   Do a thing.\n",
    ],
    ids=["an empty line before the function", "the end of the file"],
)
def test_a_command_block_followed_by_no_function(tmp_path: Path, module: str) -> None:
    problems = check(_repo(tmp_path, module))

    assert any("'.. command:: cs_thing' is not right above its function" in p for p in problems), problems
