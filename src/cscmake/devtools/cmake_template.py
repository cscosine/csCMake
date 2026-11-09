"""Run cmake-format / cmake-lint on ``configure_file`` templates (``*.cmake.in``).

The ``@VAR@`` placeholders of a template are not valid CMake where they replace a command name
(``@NS@_debug_message(...)``) or a whole line (``@INJECTED_CODE@``), so cmakelang cannot parse the
template as is. Each placeholder is swapped for a valid stand-in, the tools run on that text, and
the placeholders are put back:

- a line holding only ``@VAR@`` becomes the statement ``cscmake_template_line(<n>)``;
- any other ``@VAR@`` becomes the identifier ``csatph<n>__..x``, padded with ``_`` to the length of
  ``@VAR@`` so that line widths are unchanged. It is lowercase where CMake convention wants
  lowercase (command names, ``function``/``macro`` names) and uppercase elsewhere (variables), so
  cmake-lint naming checks are meaningful; it is restored case-insensitively (cmake-format may
  also lowercase command names).

Formatting fails if the restored text does not contain exactly the original placeholders.

Usage (pre-commit, from the dev venv):
    cscmake-cmake-template format [--check] FILE...
    cscmake-cmake-template lint FILE...
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
import tempfile
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

CONFIG_FILE_NAMES = (".cmake-format.json", ".cmake-format.yaml", ".cmake-format.yml", ".cmake-format.py")

_PLACEHOLDER = re.compile(r"@([A-Za-z_][A-Za-z0-9_]*)@")
_PLACEHOLDER_LINE = re.compile(r"^([ \t]*)@([A-Za-z_][A-Za-z0-9_]*)@[ \t]*$", re.MULTILINE)
_STANDIN_LINE = re.compile(r"^([ \t]*)cscmake_template_line\((\d+)\)[ \t]*$", re.MULTILINE | re.IGNORECASE)
_STANDIN = re.compile(r"csatph(\d+)_*x", re.IGNORECASE)
# a placeholder at the start of a command name, or right after function( / macro(
_LOWERCASE_CONTEXT = re.compile(r"(^[ \t]*|\b(?:function|macro)\([ \t]*)$", re.IGNORECASE)


class TemplateError(RuntimeError):
    """The template could not be processed without altering its placeholders."""


@dataclass(frozen=True)
class Protected:
    text: str
    names: tuple[str, ...]


def placeholders(text: str) -> Counter[str]:
    """Return how many times each ``@VAR@`` placeholder occurs in ``text``."""
    return Counter(_PLACEHOLDER.findall(text))


def protect(text: str) -> Protected:
    """Replace the ``@VAR@`` placeholders of ``text`` with parseable CMake stand-ins."""
    if _STANDIN.search(text) or _STANDIN_LINE.search(text):
        raise TemplateError("template already contains a stand-in token (csatph<n>x / cscmake_template_line)")
    names = tuple(sorted(placeholders(text)))
    index = {name: i for i, name in enumerate(names)}
    text = _PLACEHOLDER_LINE.sub(lambda m: f"{m.group(1)}cscmake_template_line({index[m.group(2)]})", text)

    def standin(m: re.Match[str]) -> str:
        token = _standin(index[m.group(1)], len(m.group(0)))
        line_start = text.rfind("\n", 0, m.start()) + 1
        return token if _LOWERCASE_CONTEXT.search(text[line_start : m.start()]) else token.upper()

    text = _PLACEHOLDER.sub(standin, text)
    return Protected(text, names)


def _standin(i: int, width: int) -> str:
    """Return the stand-in of placeholder ``i``, padded to ``width`` characters when possible."""
    head = f"csatph{i}"
    return head + "_" * max(0, width - len(head) - 1) + "x"


def restore(text: str, names: tuple[str, ...]) -> str:
    """Inverse of :func:`protect`: put the ``@VAR@`` placeholders back."""

    def name(i: str) -> str:
        if int(i) >= len(names):
            raise TemplateError(f"unknown stand-in index {i}")
        return f"@{names[int(i)]}@"

    text = _STANDIN_LINE.sub(lambda m: f"{m.group(1)}{name(m.group(2))}", text)
    return _STANDIN.sub(lambda m: name(m.group(1)), text)


def find_config(path: Path) -> Path | None:
    """Return the cmake-format config that applies to ``path`` (searched upwards), if any."""
    for folder in path.resolve().parents:
        for config_name in CONFIG_FILE_NAMES:
            candidate = folder / config_name
            if candidate.is_file():
                return candidate
    return None


def _run_cmakelang(tool: str, args: list[str], config: Path | None) -> subprocess.CompletedProcess[str]:
    cmd = [sys.executable, "-m", f"cmakelang.{tool}", *args]
    if config is not None:
        # last: -c takes one or more values and would swallow the input files
        cmd += ["-c", str(config)]
    return subprocess.run(cmd, capture_output=True, text=True, check=False)


def format_text(text: str, config: Path | None) -> str:
    """Return ``text`` (a template) formatted by cmake-format, placeholders preserved."""
    protected = protect(text)
    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp) / "template.cmake"
        work.write_text(protected.text, encoding="utf-8", newline="\n")
        result = _run_cmakelang("format", ["-i", str(work)], config)
        if result.returncode != 0:
            raise TemplateError(f"cmake-format failed:\n{result.stderr}")
        formatted = restore(work.read_text(encoding="utf-8"), protected.names)
    if placeholders(formatted) != placeholders(text):
        raise TemplateError("formatting changed the @VAR@ placeholders")
    return formatted


def lint_text(text: str, display_name: str, config: Path | None) -> tuple[int, str]:
    """Run cmake-lint on ``text`` (a template); return the exit code and the report."""
    protected = protect(text)
    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp) / "template.cmake"
        work.write_text(protected.text, encoding="utf-8", newline="\n")
        result = _run_cmakelang("lint", [str(work)], config)
    report = restore(result.stdout, protected.names).replace(str(work), display_name)
    return result.returncode, report + result.stderr


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    fmt = sub.add_parser("format", help="format templates in place")
    fmt.add_argument("--check", action="store_true", help="do not write; exit 1 if a file would change")
    fmt.add_argument("files", nargs="+", type=Path)
    lint = sub.add_parser("lint", help="lint templates")
    lint.add_argument("files", nargs="+", type=Path)
    args = parser.parse_args(argv)

    status = 0
    for path in args.files:
        text = path.read_text(encoding="utf-8")
        config = find_config(path)
        try:
            if args.command == "format":
                formatted = format_text(text, config)
                if formatted != text:
                    status = 1
                    if args.check:
                        print(f"would reformat {path}")
                    else:
                        path.write_text(formatted, encoding="utf-8", newline="\n")
                        print(f"reformatted {path}")
            else:
                code, report = lint_text(text, str(path), config)
                if code != 0:
                    status = 1
                    print(report, end="")
        except TemplateError as exc:
            print(f"{path}: {exc}", file=sys.stderr)
            status = 1
    return status


if __name__ == "__main__":
    sys.exit(main())
