"""cscmake-lint: the CMake rules of csCMake (names, comments, complexity, line length)."""

from __future__ import annotations

from pathlib import Path

import pytest

from cscmake.devtools.cmake_lint import MAX_LINE_LENGTH, lint_text, main, parse

REPO_ROOT = Path(__file__).resolve().parents[3]

GOOD = """# Add two numbers.
function(add first second out_var)
  set(sum 0)
  math(EXPR sum "${first} + ${second}")
  set(${out_var} ${sum} PARENT_SCOPE)
endfunction()
"""


def _codes(text: str) -> list[str]:
    return [finding.split(": ", 1)[1].split()[0] for finding in lint_text(text, "f.cmake")]


def test_the_repository_is_clean() -> None:
    files = [
        REPO_ROOT / "csCMake.cmake",
        *(REPO_ROOT / "modules").rglob("*.cmake"),
        *(REPO_ROOT / "templates").glob("*.cmake.in"),
        *(REPO_ROOT / "tests" / "smoke").rglob("CMakeLists.txt"),
    ]
    findings = [f for path in files for f in lint_text(path.read_text(encoding="utf-8"), str(path))]

    assert findings == []


def test_a_clean_function() -> None:
    assert _codes(GOOD) == []


def test_parse_reads_commands_and_arguments() -> None:
    text = """# comment ( not a command )
#[[ bracket
comment(x) ]]
set(a "quoted ) (" [=[bracket ) arg]=] # trailing comment )
  b)
if((x) AND y)
endif()
"""
    commands = parse(text)

    assert [(c.name, c.line) for c in commands] == [("set", 4), ("if", 6), ("endif", 7)]
    assert commands[0].args == ["a", '"quoted ) ("', "[=[bracket ) arg]=]", "b"]
    assert commands[1].args == ["x", "AND", "y"]


def test_parse_unterminated_text() -> None:
    assert parse('set(a "open')[0].args == ["a"]  # the unfinished argument is dropped
    assert [c.name for c in parse("#[[ open\nset(a)")] == []
    assert parse("set(a [[open")[0].args == ["a"]
    assert parse('set(a "x\\"y")')[0].args == ["a", '"x\\"y"']


@pytest.mark.parametrize(
    ("text", "code"),
    [
        ("# c\nfunction(Add)\nendfunction()\n", "CS101"),
        ("# c\nfunction(add First)\nendfunction()\n", "CS102"),
        ("# c\nfunction(add)\n  set(Total 1)\nendfunction()\n", "CS103"),
        ("function(add)\nendfunction()\n", "CS104"),
        ("set(x 1)\n\nfunction(add)\nendfunction()\n", "CS104"),
        ("# c\nfunction(add a b c d e f)\nendfunction()\n", "CS105"),
        ("# c\nfunction(add)\n" + "  set(x 1)\n" * 51 + "endfunction()\n", "CS106"),
        ("# c\nfunction(add)\n" + "  if(x)\n  endif()\n" * 13 + "endfunction()\n", "CS107"),
        ("set(x " + "a" * MAX_LINE_LENGTH + ")\n", "CS108"),
    ],
)
def test_findings(text: str, code: str) -> None:
    assert _codes(text) == [code]


def test_not_local_variables() -> None:
    text = """# c
function(add out_var)
  set(OUT ${x} PARENT_SCOPE)
  set(CACHED x CACHE STRING "doc")
  set(${out_var} 1)
  set(ENV{PATH} x)
  set()
endfunction()
# a macro sets the variables of its caller
macro(add_in_caller)
  set(CALLER_VAR 1)
endmacro()
"""
    assert _codes(text) == []


def test_template_placeholders_are_lowercase_names() -> None:
    text = "# c\nfunction(@NS_SANITIZED@_debug @ARG@)\n  set(@VAR@_x 1)\nendfunction()\n"

    assert _codes(text) == []


def test_disable_comment() -> None:
    text = """# c
function(add a b c d e f)
  # cscmake-lint: disable=CS105, CS103
  # (the reason)
  set(Total 1)
endfunction()
"""
    assert _codes(text) == []
    assert _codes(text.replace("CS105, CS103", "CS103")) == ["CS105"]


def test_disable_comment_only_at_the_start_of_the_body() -> None:
    text = "# c\nfunction(add a b c d e f)\n  set(x 1)\n  # cscmake-lint: disable=CS105\nendfunction()\n"

    assert _codes(text) == ["CS105"]


def test_a_function_without_end() -> None:
    assert _codes("# c\nfunction(Add)\n  set(x 1)\n") == ["CS101"]


def test_main(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    bad = tmp_path / "bad.cmake"
    bad.write_text("function(Add)\nendfunction()\n", encoding="utf-8")
    good = tmp_path / "good.cmake"
    good.write_text(GOOD, encoding="utf-8")

    assert main([str(good)]) == 0
    assert main([str(bad), str(good)]) == 1
    out = capsys.readouterr().out
    assert f"{bad}:1: CS101" in out
    assert f"{bad}:1: CS104" in out
    assert main(["--disable", "CS101,CS104", str(bad)]) == 0
