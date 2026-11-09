#!/usr/bin/env python3
"""Print the GitHub Actions matrix of the smoke workflow (.github/workflows/smoke.yml).

One entry per variant of the csCMake preset registry, with the GitHub-hosted runner that can build it.
When run inside GitHub Actions, the matrix is also written to ``$GITHUB_OUTPUT`` as ``matrix=<json>``.

Usage:
    python tests/smoke/ci_matrix.py
"""

from __future__ import annotations

import json
import os
import sys

from cscmake.presets.registry import (
    OS,
    Architecture,
    ContextOsArchitectureCompilerGenerator,
    Generator,
    create_context_os_architecture_compiler_generator_string,
    get_supported_context_os_architecture_list,
)

# Visual Studio generator -> Windows runner image shipping that Visual Studio
WINDOWS_RUNNERS = {
    Generator.MSVC_17_2022: "windows-2022",
    Generator.MSVC_18_2026: "windows-2025-vs2026",
}


def runner(ctx: ContextOsArchitectureCompilerGenerator) -> str:
    """Return the GitHub-hosted runner label for ``ctx``; fail for variants with no known runner."""
    osa = ctx.context_os_architecture
    generator = ctx.context_compiler_generator.build_generator.generator
    if osa.os == OS.LINUX and osa.os_version.startswith("ubuntu"):
        label = f"ubuntu-{osa.os_version.removeprefix('ubuntu')}"
        return f"{label}-arm" if osa.architecture == Architecture.ARM64 else label
    if osa.os == OS.WINDOWS and osa.architecture == Architecture.X64 and generator in WINDOWS_RUNNERS:
        return WINDOWS_RUNNERS[generator]
    raise ValueError(f"no GitHub runner known for {create_context_os_architecture_compiler_generator_string(ctx)}")


def matrix() -> dict[str, list[dict[str, str]]]:
    """Return the ``strategy.matrix`` value: one ``include`` entry per registry variant."""
    return {
        "include": [
            {
                "variant": create_context_os_architecture_compiler_generator_string(ctx),
                "runner": runner(ctx),
                "generator_type": ctx.context_compiler_generator.build_generator.generator_type.value,
            }
            for ctx in get_supported_context_os_architecture_list()
        ]
    }


def main() -> int:
    value = matrix()
    print(json.dumps(value, indent=2))
    github_output = os.environ.get("GITHUB_OUTPUT")
    if github_output:
        with open(github_output, "a", encoding="utf-8") as out:
            out.write(f"matrix={json.dumps(value)}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
