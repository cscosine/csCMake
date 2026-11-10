import re
from pathlib import Path

import pytest

from cscmake.devtools.cmake_template import (
    TemplateError,
    find_config,
    format_text,
    lint_text,
    main,
    placeholders,
    protect,
    restore,
)

REPO_ROOT = Path(__file__).resolve().parents[3]
TEMPLATE = REPO_ROOT / "templates" / "csTemplateConfig.cmake.in"
CONFIG = REPO_ROOT / ".cmake-format.json"

UNFORMATTED = """\
OPTION(@NS@_DEBUG "debug @NS@" OFF)
function(@NS_SANITIZED@_debug_message msg)
\tif(${@NS_SANITIZED@_DEBUG})
\t\tMESSAGE(STATUS "${msg}")
\tendif()
endfunction()
macro(@NS_SANITIZED@_find COMPONENT_NAME)
@INJECTED_CODE@
endmacro()
"""


def test_protect_removes_every_placeholder_and_restore_inverts_it() -> None:
    text = TEMPLATE.read_text(encoding="utf-8")
    protected = protect(text)

    assert placeholders(protected.text) == {}
    assert "cscmake_template_line(" in protected.text  # standalone @VAR@ lines
    assert restore(protected.text, protected.names) == text


def test_inline_standins_keep_line_width() -> None:
    line = "@EXPORT_NAMESPACE_SANITIZED@_debug_message(@EXPORT_NAMESPACE@)"
    protected = protect(line)

    assert len(protected.text) == len(line)


def test_restore_is_case_insensitive() -> None:
    protected = protect("@NS_SANITIZED@_debug_message()\n")

    assert restore(protected.text.lower(), protected.names) == "@NS_SANITIZED@_debug_message()\n"
    assert restore(protected.text.upper(), protected.names).startswith("@NS_SANITIZED@")


def test_protect_rejects_text_that_already_contains_standins() -> None:
    with pytest.raises(TemplateError):
        protect("set(csatph0x 1)\n")


def test_restore_rejects_unknown_standin_index() -> None:
    with pytest.raises(TemplateError):
        restore("set(csatph7x 1)\n", ("ONLY_ONE",))


def test_find_config_walks_up_to_repo_config() -> None:
    assert find_config(TEMPLATE) == CONFIG


def test_committed_template_is_formatted_and_lint_clean() -> None:
    text = TEMPLATE.read_text(encoding="utf-8")

    assert format_text(text, CONFIG) == text
    code, report = lint_text(text, str(TEMPLATE), CONFIG)
    assert code == 0, report


def test_format_keeps_placeholders_and_is_idempotent() -> None:
    formatted = format_text(UNFORMATTED, CONFIG)

    assert placeholders(formatted) == placeholders(UNFORMATTED)
    assert "\t" not in formatted
    assert "  @INJECTED_CODE@\n" in formatted  # standalone placeholder line kept, re-indented in the macro body
    assert format_text(formatted, CONFIG) == formatted


def test_main_format_check_then_write(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    (tmp_path / ".cmake-format.json").write_text(CONFIG.read_text(encoding="utf-8"), encoding="utf-8")
    template = tmp_path / "Config.cmake.in"
    template.write_text(UNFORMATTED, encoding="utf-8")

    assert main(["format", "--check", str(template)]) == 1
    assert template.read_text(encoding="utf-8") == UNFORMATTED
    assert "would reformat" in capsys.readouterr().out

    assert main(["format", str(template)]) == 1
    assert template.read_text(encoding="utf-8") != UNFORMATTED
    assert main(["format", "--check", str(template)]) == 0


def test_main_lint_reports_findings_with_original_path(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    (tmp_path / ".cmake-format.json").write_text(CONFIG.read_text(encoding="utf-8"), encoding="utf-8")
    template = tmp_path / "Config.cmake.in"
    # no docstring before the function -> C0111
    template.write_text("set(X 1)\n\nfunction(@NS@_f)\nendfunction()\n", encoding="utf-8")

    assert main(["lint", str(template)]) == 1
    out = capsys.readouterr().out
    assert str(template) in out
    assert "C0111" in out
    assert "@NS@" in out or "csatph" not in out


def test_standin_case_follows_cmake_naming_context() -> None:
    text = "function(@NS@_f)\nendfunction()\n@NS@_f()\nset(@NS@_VAR 1)\n"
    lines = protect(text).text.splitlines()

    assert lines[0].startswith("function(csatph")  # function name: lowercase
    assert lines[2].startswith("csatph")  # command name: lowercase
    assert lines[3].startswith("set(CSATPH")  # variable: uppercase


@pytest.mark.parametrize(
    ("text", "lowercase"),
    [
        ("set(_@NS@_items 1)\n", True),  # private variable: lowercase around the placeholder
        ("foreach(@NS@_item IN LISTS x)\nendforeach()\n", True),
        ("set(@NS@_${x}_FOUND 1)\n", False),  # no lowercase around: uppercase
        ("set(_@NS@_Mixed 1)\n", False),
    ],
)
def test_standin_case_follows_the_identifier_around_it(text: str, lowercase: bool) -> None:
    standin = re.search("csatph[0-9_]*x", protect(text).text, re.IGNORECASE)

    assert standin is not None
    assert standin.group(0).islower() == lowercase
