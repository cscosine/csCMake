"""Check that the reference documentation of the CMake modules is complete.

The reference is written in the ``#.rst:`` comment blocks of ``csCMake.cmake`` and ``modules/**/*.cmake`` (see
``docs/contributing/documentation.md``). Sphinx (``sphinx-build -W -n``) checks that every reference resolves; this tool
checks what Sphinx cannot see:

- every public ``cs_*`` function or macro has a ``.. command::`` block of the same name right above it, and every
  ``.. command::`` block is right above its function;
- every csCMake variable or property the code uses (``CSCMAKE_*``, ``_CSCMAKE_*``, ``<prefix>_CSCMAKE_*``) has a
  ``.. variable::`` / ``.. prop_tgt::`` / ``.. prop_gbl::`` entry, and every entry is used by the code. In names built
  at configure time, each ``${...}`` part is a placeholder, matched by the ``<...>`` placeholders of the entries
  (``CSCMAKE_${config}_POSTFIX`` matches ``CSCMAKE_<CONFIG>_POSTFIX``). An entry outside this naming
  (e.g. a lowercase variable) must appear as written in the code;
- every module with a reference header (a ``#.rst:`` block before its code) has its page
  ``docs/reference/<module>.rst``.

Usage (from the dev venv):
    cscmake-check-docs            # exit 1 and list the problems as <file>:<line>: <message>
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]

_FUNCTION = re.compile(r"^(?:function|macro)\(\s*([A-Za-z0-9_]+)", re.MULTILINE)
_COMMAND = re.compile(r"^# \.\. command:: (\S+)$")
_ENTRY = re.compile(r"^#\s+\.\. (variable|prop_tgt|prop_gbl):: (\S+)$")
_INNER_VARIABLE = re.compile(r"\$\{([^${}]*)\}")
_NAME = re.compile(r"(?:<x>_)?_?CSCMAKE_[A-Za-z0-9_<>]*[A-Za-z0-9>]")
_PLACEHOLDER = re.compile(r"<[^<>]+>")
PLACEHOLDER = "<x>"


@dataclass
class Module:
    """What check_docs reads from one CMake module."""

    path: Path
    has_reference_header: bool = False
    functions: list[tuple[str, int]] = field(default_factory=list)
    command_blocks: list[tuple[str, int, str | None]] = field(default_factory=list)  # name, line, function after it
    entries: list[tuple[str, str, int]] = field(default_factory=list)  # kind, name, line
    used_names: list[tuple[str, int]] = field(default_factory=list)
    code: list[str] = field(default_factory=list)


def names_in_code(line: str) -> list[str]:
    """Return the csCMake variable and property names of a code line, ``${...}`` parts turned into ``<x>``."""
    names: list[str] = []
    while match := _INNER_VARIABLE.search(line):
        names += _NAME.findall(match.group(1))
        line = line[: match.start()] + PLACEHOLDER + line[match.end() :]
    names += _NAME.findall(line)
    return names


def entry_pattern(name: str) -> re.Pattern[str]:
    """Return the pattern matching the code names of a documented entry: each ``<...>`` placeholder matches anything."""
    parts = _PLACEHOLDER.split(name)
    return re.compile(".+".join(re.escape(part) for part in parts) + "$")


def read_module(path: Path) -> Module:
    """Parse the functions, the ``#.rst:`` blocks and the code names of a CMake module."""
    module = Module(path)
    lines = path.read_text(encoding="utf-8").splitlines()
    in_rst = False
    pending: tuple[str, int] | None = None
    seen_code = False
    for number, line in enumerate(lines, start=1):
        stripped = line.strip()
        if stripped == "#.rst:":
            in_rst = True
            if not seen_code:
                module.has_reference_header = True
            continue
        if in_rst and (stripped == "#" or line.startswith("# ")):
            if command := _COMMAND.match(line):
                pending = (command.group(1), number)
            elif entry := _ENTRY.match(line):
                module.entries.append((entry.group(1), entry.group(2), number))
            continue
        in_rst = False
        if stripped.startswith("#") or not stripped:
            if pending and stripped.startswith("#"):
                continue
            if pending and not stripped:
                module.command_blocks.append((pending[0], pending[1], None))
                pending = None
            continue
        seen_code = True
        if function := _FUNCTION.match(line):
            if pending:
                module.command_blocks.append((pending[0], pending[1], function.group(1)))
                pending = None
            module.functions.append((function.group(1), number))
        elif pending:
            module.command_blocks.append((pending[0], pending[1], None))
            pending = None
        module.used_names += [(name, number) for name in names_in_code(line)]
        module.code.append(line)
    if pending:
        module.command_blocks.append((pending[0], pending[1], None))
    return module


def check(root: Path = REPO_ROOT) -> list[str]:
    """Return the problems of the reference documentation of the CMake modules under ``root``."""
    paths = [root / "csCMake.cmake", *sorted((root / "modules").rglob("*.cmake"))]
    modules = [read_module(path) for path in paths if path.exists()]
    problems: list[str] = []

    def where(module: Module, line: int) -> str:
        return f"{module.path.relative_to(root).as_posix()}:{line}"

    for module in modules:
        documented = {function for _, _, function in module.command_blocks if function}
        for name, line, function in module.command_blocks:
            if function is None:
                problems.append(f"{where(module, line)}: '.. command:: {name}' is not right above its function")
            elif function != name:
                problems.append(f"{where(module, line)}: '.. command:: {name}' documents the function {function}")
        for name, line in module.functions:
            if name.startswith("cs_") and name not in documented:
                problems.append(f"{where(module, line)}: public command {name} has no '.. command::' block above it")
        if module.has_reference_header:
            page = root / "docs" / "reference" / f"{module.path.stem}.rst"
            if not page.exists():
                problems.append(f"{where(module, 1)}: no reference page {page.relative_to(root).as_posix()}")

    entries = [(module, kind, name, line) for module in modules for kind, name, line in module.entries]
    patterns = [(entry_pattern(name), module, kind, name, line) for module, kind, name, line in entries]
    used = [(module, name, line) for module in modules for name, line in module.used_names]
    for module, name, line in used:
        if not any(pattern.match(name) for pattern, *_ in patterns):
            problems.append(f"{where(module, line)}: {name} is not documented (variable, prop_tgt or prop_gbl entry)")
    code = "\n".join(line for module in modules for line in module.code)
    for pattern, module, kind, name, line in patterns:
        if _NAME.fullmatch(_PLACEHOLDER.sub(PLACEHOLDER, name)):
            is_used = any(pattern.match(used_name) for _, used_name, _ in used)
        else:  # a name outside the csCMake naming (e.g. a lowercase variable): used as written
            is_used = re.search(rf"\b{re.escape(name)}\b", code) is not None
        if not is_used:
            problems.append(f"{where(module, line)}: '.. {kind}:: {name}' is not used by the code")
    return sorted(set(problems))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", type=Path, default=REPO_ROOT, help="csCMake checkout (default: this one)")
    args = parser.parse_args(argv)
    problems = check(args.root)
    for problem in problems:
        print(problem)
    if problems:
        print(
            f"cscmake-check-docs: {len(problems)} problem(s), see docs/contributing/documentation.md", file=sys.stderr
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
