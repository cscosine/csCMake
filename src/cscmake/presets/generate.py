"""Generate the csv1 CMake preset matrix under ``presets/csv1/`` from ``presets/template/``.

Usage (from a csCMake checkout):
    cscmake-generate-presets            # regenerate in place
    cscmake-generate-presets --check    # exit 1 if presets/csv1 is out of date
    python -m cscmake.presets.generate  # same, without the console script

Standard library only. Requires ``cscmake`` installed in editable mode (``./setup.sh``), since the
templates and the output folder are resolved relative to the source checkout.
"""

from __future__ import annotations

import argparse
import json
import sys
import tempfile
from pathlib import Path
from typing import Any

from cscmake.presets.registry import (
    CS_SCHEMA_VERSION,
    CS_SCHEMA_VERSION_SHORT,
    ContextOsArchitectureCompilerGenerator,
    GeneratorType,
    get_supported_build_configs_for_generator_type,
    get_supported_context_os_architecture_list,
    short_architecture,
    short_architecture_variant,
    short_compiler_family,
    short_compiler_version,
    short_generator,
    short_os_name,
    short_os_version,
)
from cscmake.utils.generate_cs_preset_variants import (
    generate_from_template_single_config_generator_all,
    load_template,
    render_template,
)

# the templates and the generated presets live in the csCMake checkout, not in the package:
# src/cscmake/presets/generate.py -> repository root (editable/source installs)
REPO_ROOT = Path(__file__).resolve().parents[3]
TEMPLATE_DIR = REPO_ROOT / "presets" / "template"
OUTPUT_DIR = REPO_ROOT / "presets" / "csv1"
CS_PRESETS_ALL_JSON = "cs-presets-all.json"

_TEMPLATE_PREFIX = {
    GeneratorType.SINGLE_CONFIG: "cs-single-config-generator",
    GeneratorType.MULTI_CONFIG: "cs-multi-config-generator",
}


def build_substitutions(ctx: ContextOsArchitectureCompilerGenerator) -> dict[str, Any]:
    """Return the ``@{var}`` substitutions shared by every template of ``ctx``."""
    osa = ctx.context_os_architecture
    ccg = ctx.context_compiler_generator
    generator = ccg.build_generator.generator
    return {
        "csVersion": CS_SCHEMA_VERSION,
        "host": osa.os.value,
        "osVersion": osa.os_version,
        "architecture": osa.architecture.value,
        "architectureVariant": osa.architecture_variant,
        "generator": generator.value,
        "compiler": ccg.compiler_family.value,
        "compiler_version": ccg.compiler_version,
        # shortened values
        "csVersion_short": CS_SCHEMA_VERSION_SHORT,
        "host_short": short_os_name(osa.os),
        "osVersion_short": short_os_version(osa.os, osa.os_version),
        "architecture_short": short_architecture(osa.architecture),
        "architectureVariant_short": short_architecture_variant(osa.architecture_variant),
        "generator_short": short_generator(generator),
        "compiler_short": short_compiler_family(ccg.compiler_family),
        "compiler_version_short": short_compiler_version(ccg.compiler_version),
    }


def _render(subs: dict[str, Any], template_path: Path, output_dir: Path, suffix: str) -> str:
    return generate_from_template_single_config_generator_all(
        subs, template_path=template_path, output_dir=output_dir, output_filename_suffix=suffix
    )


def generate_all_csv1_presets(template_dir: Path = TEMPLATE_DIR, output_dir: Path = OUTPUT_DIR) -> list[str]:
    """Render the full preset matrix into ``output_dir``; return the generated file names.

    Stale ``*.json`` files in ``output_dir`` that are no longer part of the matrix are removed.
    """
    generated: list[str] = []
    generated_all: list[str] = []

    # one -<config>.json per single build type; the combined multi-config build types
    # (debug-release, ...) are covered by the -ALL presets
    build_configs = get_supported_build_configs_for_generator_type(GeneratorType.SINGLE_CONFIG)

    for ctx in get_supported_context_os_architecture_list():
        subs = build_substitutions(ctx)
        prefix = _TEMPLATE_PREFIX[ctx.context_compiler_generator.build_generator.generator_type]

        all_filename = _render(subs, template_dir / f"{prefix}-ALL.json.template", output_dir, "ALL")
        generated_all.append(all_filename)
        generated.append(all_filename)
        generated.append(_render(subs, template_dir / f"{prefix}-base.json.template", output_dir, "base"))
        for build_config in build_configs:
            generated.append(
                _render(
                    {**subs, "buildConfig": build_config.value},
                    template_dir / f"{prefix}-config.json.template",
                    output_dir,
                    build_config.value.lower(),
                )
            )

    # a single preset file that includes all the *-ALL presets
    include_lines = ",\n".join(f'        "{f}"' for f in sorted(set(generated_all)))
    rendered = render_template(
        load_template(template_dir / f"{CS_PRESETS_ALL_JSON}.template"), {"csIncludeLines": include_lines}
    )
    json.loads(rendered)  # validate
    (output_dir / CS_PRESETS_ALL_JSON).write_text(rendered, encoding="utf-8", newline="\n")
    generated.append(CS_PRESETS_ALL_JSON)

    keep = set(generated)
    for stale in output_dir.glob("*.json"):
        if stale.name not in keep:
            stale.unlink()

    return generated


def check_presets_up_to_date(template_dir: Path = TEMPLATE_DIR, output_dir: Path = OUTPUT_DIR) -> list[str]:
    """Return the file names that differ between a fresh generation and ``output_dir``."""
    with tempfile.TemporaryDirectory() as tmp:
        fresh_dir = Path(tmp)
        generate_all_csv1_presets(template_dir, fresh_dir)
        fresh = {p.name: p.read_bytes() for p in fresh_dir.glob("*.json")}
    current = {p.name: p.read_bytes() for p in output_dir.glob("*.json")}
    return sorted(name for name in fresh.keys() | current.keys() if fresh.get(name) != current.get(name))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--template-dir", type=Path, default=TEMPLATE_DIR, help="templates (default: presets/template)")
    parser.add_argument("--output-dir", type=Path, default=OUTPUT_DIR, help="output folder (default: presets/csv1)")
    parser.add_argument("--check", action="store_true", help="do not write; exit 1 if the output folder is stale")
    parser.add_argument("-q", "--quiet", action="store_true", help="do not list generated files")
    args = parser.parse_args(argv)

    if not args.template_dir.is_dir():
        parser.error(
            f"template folder not found: {args.template_dir} (install csCMake in editable mode or pass --template-dir)"
        )

    if args.check:
        stale = check_presets_up_to_date(args.template_dir, args.output_dir)
        for name in stale:
            print(f"Out of date: {name}")
        if stale:
            print("Run: cscmake-generate-presets")
            return 1
        return 0

    generated = generate_all_csv1_presets(args.template_dir, args.output_dir)
    if not args.quiet:
        for name in generated:
            print(f"Generated: {name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
