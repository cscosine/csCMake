"""Lint CMake files with the rules of csCMake (``cscmake-lint``).

The rules (see ``docs/contributing/code.md``, "CMake conventions"):

- ``CS101`` a function or macro name is lowercase: ``[0-9a-z_]+``;
- ``CS102`` an argument of a function or macro is lowercase: ``[a-z][a-z0-9_]*``;
- ``CS103`` a local variable of a function (``set(<name> ...)`` without ``PARENT_SCOPE`` / ``CACHE``) is lowercase:
  ``[a-z][a-z0-9_]*``;
- ``CS104`` a comment block right above every function and macro (what it does);
- ``CS105`` at most ``MAX_ARGUMENTS`` named arguments (use keyword arguments, ``cmake_parse_arguments``);
- ``CS106`` at most ``MAX_STATEMENTS`` commands in a function or macro;
- ``CS107`` at most ``MAX_BRANCHES`` branches (``if``, ``elseif``, ``else``, ``foreach``, ``while``);
- ``CS108`` lines of at most ``MAX_LINE_LENGTH`` characters.

In templates (``*.cmake.in``), ``@VAR@`` placeholders count as lowercase names. A finding is silenced for one function
or macro with ``# cscmake-lint: disable=<code>[,<code>...]`` as the first line of its body, plus the reason.

Usage (from the dev venv):
    cscmake-lint <file>...                    # exit 1 and list the findings as <file>:<line>: <code> <message>
    cscmake-lint --disable CS101,CS108 <file>
"""

from __future__ import annotations

import argparse
import re
import sys
from collections.abc import Iterator
from dataclasses import dataclass, field
from pathlib import Path

MAX_ARGUMENTS = 5
MAX_STATEMENTS = 50
MAX_BRANCHES = 12
MAX_LINE_LENGTH = 120

_FUNCTION_NAME = re.compile(r"[0-9a-z_]+$")
_VARIABLE_NAME = re.compile(r"[a-z][a-z0-9_]*$")
_IDENTIFIER = re.compile(r"[A-Za-z_@][A-Za-z0-9_@]*")
_PLACEHOLDER = re.compile(r"@[A-Za-z_][A-Za-z0-9_]*@")
_BRACKET_OPEN = re.compile(r"\[(=*)\[")
_DISABLE = re.compile(r"^\s*#\s*cscmake-lint:\s*disable=([A-Z0-9, ]+)")
_BRANCHES = {"if", "elseif", "else", "foreach", "while"}


@dataclass
class Command:
    """A command invocation: its name, the line where it starts, its arguments (unquoted words and quoted strings)."""

    name: str
    line: int
    args: list[str] = field(default_factory=list)


def _skip_bracket(text: str, pos: int) -> int:
    """Return the position after the bracket argument or comment starting at ``pos`` (``[=*[``)."""
    match = _BRACKET_OPEN.match(text, pos)
    assert match is not None
    close = "]" + match.group(1) + "]"
    end = text.find(close, match.end())
    return len(text) if end == -1 else end + len(close)


def _skip_comment(text: str, pos: int) -> int:
    """Return the position after the comment starting at ``pos`` (``#``)."""
    if _BRACKET_OPEN.match(text, pos + 1):
        return _skip_bracket(text, pos + 1)
    end = text.find("\n", pos)
    return len(text) if end == -1 else end


def _skip_quoted(text: str, pos: int) -> int:
    """Return the position after the quoted argument starting at ``pos`` (``"``)."""
    pos += 1
    while pos < len(text):
        if text[pos] == "\\":
            pos += 2
            continue
        if text[pos] == '"':
            return pos + 1
        pos += 1
    return pos


def parse(text: str) -> list[Command]:
    """Return the command invocations of a CMake file, in order (nested parentheses are part of the arguments)."""
    commands: list[Command] = []
    pos, line = 0, 1
    while pos < len(text):
        char = text[pos]
        if char == "#":
            end = _skip_comment(text, pos)
        elif char in " \t\r\n":
            end = pos + 1
        elif (match := _IDENTIFIER.match(text, pos)) and (paren := re.compile(r"\s*\(").match(text, match.end())):
            command = Command(match.group(0), line)
            end = _parse_arguments(text, paren.end(), command)
            commands.append(command)
        else:
            end = pos + 1
        line += text.count("\n", pos, end)
        pos = end
    return commands


def _parse_arguments(text: str, pos: int, command: Command) -> int:
    """Read the arguments of ``command`` from ``pos`` (after its ``(``); return the position after its ``)``."""
    depth = 1
    word = ""
    while pos < len(text) and depth:
        char = text[pos]
        if char == "#":
            pos = _skip_comment(text, pos)
            continue
        if char == '"':
            end = _skip_quoted(text, pos)
            word += text[pos:end]
            pos = end
            continue
        if char == "[" and _BRACKET_OPEN.match(text, pos) and not word:
            end = _skip_bracket(text, pos)
            word = text[pos:end]
            pos = end
            continue
        if char in "()":
            depth += 1 if char == "(" else -1
        if char in " \t\r\n()" and word:
            command.args.append(word)
            word = ""
        elif char not in " \t\r\n()":
            word += char
        pos += 1
    return pos


def _lowercase_placeholders(name: str) -> str:
    """Return ``name`` with every ``@VAR@`` placeholder of a template replaced by a lowercase name."""
    return _PLACEHOLDER.sub("x", name)


@dataclass
class _Function:
    command: Command
    end_line: int
    body: list[Command]


def _functions(commands: list[Command]) -> Iterator[_Function]:
    """Yield the functions and macros with the commands of their body."""
    for index, command in enumerate(commands):
        kind = command.name.lower()
        if kind not in ("function", "macro"):
            continue
        end = next(
            (k for k in range(index + 1, len(commands)) if commands[k].name.lower() == f"end{kind}"), len(commands) - 1
        )
        yield _Function(command, commands[end].line, commands[index + 1 : end])


def lint_text(text: str, path: str = "<text>") -> list[str]:
    """Return the findings of a CMake text as ``<path>:<line>: <code> <message>``, sorted by line."""
    lines = text.split("\n")
    findings: list[tuple[int, str, str]] = []

    for number, line in enumerate(lines, start=1):
        if len(line) > MAX_LINE_LENGTH:
            findings.append((number, "CS108", f"line of {len(line)} characters (at most {MAX_LINE_LENGTH})"))

    for function in _functions(parse(text)):
        command = function.command
        kind = command.name.lower()
        name, *arguments = command.args or ["?"]
        disabled = _disabled_codes(lines, command.line, function.end_line)

        def report(code: str, message: str, line: int = command.line, disabled: set[str] = disabled) -> None:
            if code not in disabled:
                findings.append((line, code, message))

        if not _FUNCTION_NAME.match(_lowercase_placeholders(name)):
            report("CS101", f"{kind} name {name} is not lowercase ([0-9a-z_]+)")
        for argument in arguments:
            if not _VARIABLE_NAME.match(_lowercase_placeholders(argument)):
                report("CS102", f"argument {argument} of {name} is not lowercase ([a-z][a-z0-9_]*)")
        if command.line < 2 or not lines[command.line - 2].lstrip().startswith("#"):
            report("CS104", f"no comment block right above {kind} {name}")
        if len(arguments) > MAX_ARGUMENTS:
            report("CS105", f"{name} has {len(arguments)} arguments (at most {MAX_ARGUMENTS}): use keyword arguments")
        if len(function.body) > MAX_STATEMENTS:
            report("CS106", f"{name} has {len(function.body)} statements (at most {MAX_STATEMENTS})")
        branches = sum(1 for c in function.body if c.name.lower() in _BRANCHES)
        if branches > MAX_BRANCHES:
            report("CS107", f"{name} has {branches} branches (at most {MAX_BRANCHES})")
        if kind == "function":
            for statement in function.body:
                variable = _local_variable(statement)
                if variable and not _VARIABLE_NAME.match(_lowercase_placeholders(variable)):
                    report("CS103", f"local variable {variable} of {name} is not lowercase", statement.line)

    return [f"{path}:{line}: {code} {message}" for line, code, message in sorted(findings)]


def _disabled_codes(lines: list[str], start: int, end: int) -> set[str]:
    """The codes disabled by a ``# cscmake-lint: disable=`` comment on the first line of a function body."""
    for line in lines[start : min(end, start + 3)]:
        if match := _DISABLE.match(line):
            return {code.strip() for code in match.group(1).split(",") if code.strip()}
        if line.strip() and not line.lstrip().startswith("#"):
            break
    return set()


def _local_variable(statement: Command) -> str | None:
    """The variable a ``set()`` of a function body defines locally (not ``PARENT_SCOPE``, ``CACHE``, ``ENV{}``)."""
    if statement.name.lower() != "set" or not statement.args:
        return None
    variable = statement.args[0]
    if "$" in variable or "{" in variable or {"PARENT_SCOPE", "CACHE"} & set(statement.args[1:]):
        return None
    return variable


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("files", nargs="+", type=Path)
    parser.add_argument("--disable", default="", help="comma-separated codes not to check, e.g. CS101,CS108")
    args = parser.parse_args(argv)
    disabled = {code.strip() for code in args.disable.split(",") if code.strip()}
    findings = [
        finding
        for path in args.files
        for finding in lint_text(path.read_text(encoding="utf-8"), str(path))
        if finding.split(": ", 1)[1].split()[0] not in disabled
    ]
    for finding in findings:
        print(finding)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
