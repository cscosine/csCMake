"""Generate the csv1 CMake preset matrix from ``presets/template/``.

Outputs:
- ``presets/csv1/``: the per-variant presets and ``cs-presets-all.json``;
- ``presets/csCMakeProjectSetup-common.json``: ``cscmake-common-project-setup`` (build and install folders, search
  paths from the environment values of a layout) and one ``cscmake-project-setup-<variant>`` preset per variant
  (inherited by the ``-base`` presets of the matrix);
- ``presets/csCMakeProjectSetup.json``: includes ``csCMakeProjectSetup-common.json`` and defines one empty
  ``cscmake-project-setup-<os>`` preset per operating system (inherited by the ``-base`` presets of the matrix,
  before ``cscmake-project-setup``); a project setting values per OS includes the common file and defines them;
- ``presets/layout/<layout>.json``: ``cscmake-project-setup`` for each layout (where csCMake and the workspace are, long
  or short build folder names), included by the ``csCMakeProjectSetup.json`` of a project.

Usage (from a csCMake checkout):
    cscmake-generate-presets            # regenerate in place
    cscmake-generate-presets --check    # exit 1 if any generated file is out of date
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
    OS,
    Architecture,
    ContextOsArchitectureCompilerGenerator,
    GeneratorType,
    create_context_os_architecture_compiler_generator_string,
    create_context_os_architecture_compiler_generator_string_without_schema,
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
from cscmake.presets.render import (
    generate_from_template_single_config_generator_all,
    load_template,
    render_template,
)

# the templates and the generated presets live in the csCMake checkout, not in the package:
# src/cscmake/presets/generate.py -> repository root (editable/source installs)
REPO_ROOT = Path(__file__).resolve().parents[3]
TEMPLATE_DIR = REPO_ROOT / "presets" / "template"
OUTPUT_DIR = REPO_ROOT / "presets" / "csv1"
# the supported variants as data (variants_manifest), next to the presets; not a preset file: nothing includes it
VARIANTS_JSON = "variants.json"
SETUP_OUTPUT_DIR = REPO_ROOT / "presets"
CS_PRESETS_ALL_JSON = "cs-presets-all.json"
PROJECT_SETUP_PRESET = "csCMakeProjectSetup.json"
PROJECT_SETUP_COMMON_PRESET = "csCMakeProjectSetup-common.json"
LAYOUT_TEMPLATE = "layout.json.template"
_LONG = "$env{CSCMAKE_CSV1_SUB_DIR}"
_SHORT = "$env{CSCMAKE_CSV1_SUB_DIR_SHORT}"
_IN_WORKSPACE = "$env{CSCMAKE_WORKSPACE_ROOT}/csCMake"
# layout -> (description, CSCMAKE_WORKSPACE_ROOT, CSCMAKE_ROOT, CSCMAKE_BUILD_SUB_DIR)
LAYOUTS = {
    "sibling": ("csCMake and the project side by side in the workspace", "${sourceParentDir}", _IN_WORKSPACE, _LONG),
    "sibling-short": ("sibling, short build folder names", "${sourceParentDir}", _IN_WORKSPACE, _SHORT),
    "standalone": (
        "the workspace inside the project: <project>/workspace/csCMake",
        "${sourceDir}/workspace",
        _IN_WORKSPACE,
        _LONG,
    ),
    "standalone-short": ("standalone, short build folder names", "${sourceDir}/workspace", _IN_WORKSPACE, _SHORT),
    "env": (
        "workspace and csCMake from the environment variables CSCMAKE_WORKSPACE_ROOT and CSCMAKE_ROOT",
        "$penv{CSCMAKE_WORKSPACE_ROOT}",
        "$penv{CSCMAKE_ROOT}",
        _LONG,
    ),
    "env-short": ("env, short build folder names", "$penv{CSCMAKE_WORKSPACE_ROOT}", "$penv{CSCMAKE_ROOT}", _SHORT),
}
PROJECT_SETUP_PRESETS = (
    PROJECT_SETUP_PRESET,
    PROJECT_SETUP_COMMON_PRESET,
    *(f"layout/{name}.json" for name in LAYOUTS),
)
PROJECT_SETUP_PRESET_PREFIX = "cscmake-project-setup-"

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
        "compiler_version": ccg.compiler_version.lower(),  # lowercase, as in the variant id
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

    generated.append(write_variants_manifest(output_dir))

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


def project_setup_preset_name(ctx: ContextOsArchitectureCompilerGenerator) -> str:
    """Return the name of the project setup preset of ``ctx``, inherited by its ``-base`` preset."""
    return PROJECT_SETUP_PRESET_PREFIX + create_context_os_architecture_compiler_generator_string_without_schema(ctx)


def project_setup_os_preset_name(os: OS) -> str:
    """Return the name of the project setup preset of the operating system ``os``, inherited by the ``-base`` presets
    of its variants."""
    return PROJECT_SETUP_PRESET_PREFIX + os.value


def _preset_list(names: list[str]) -> str:
    """The hidden configure presets ``names``, with nothing else, as the lines of a ``configurePresets`` array (only
    inherited: not in the list of the presets of the host)."""
    return ",\n".join(
        f'        {{\n            "name": "{name}",\n            "hidden": true\n        }}' for name in names
    )


def _project_setup_sort_key(ctx: ContextOsArchitectureCompilerGenerator) -> tuple[str, int, str, str, str]:
    osa = ctx.context_os_architecture
    ccg = ctx.context_compiler_generator
    return (
        osa.os.value,
        list(Architecture).index(osa.architecture),
        osa.os_version,
        ccg.compiler_family.value,
        ccg.build_generator.generator.value,
    )


def generate_project_setup_presets(template_dir: Path = TEMPLATE_DIR, output_dir: Path = SETUP_OUTPUT_DIR) -> list[str]:
    """Render ``csCMakeProjectSetup.json``, ``csCMakeProjectSetup-common.json`` and the ``layout/<layout>.json`` files
    into ``output_dir``; return their names (relative to ``output_dir``)."""
    contexts = sorted(get_supported_context_os_architecture_list(), key=_project_setup_sort_key)
    os_list = sorted({ctx.context_os_architecture.os for ctx in contexts}, key=lambda os: os.value)
    rendered = {
        PROJECT_SETUP_PRESET: render_template(
            load_template(template_dir / f"{PROJECT_SETUP_PRESET}.template"),
            {"csProjectSetupOsPresets": _preset_list([project_setup_os_preset_name(os) for os in os_list])},
        ),
        PROJECT_SETUP_COMMON_PRESET: render_template(
            load_template(template_dir / f"{PROJECT_SETUP_COMMON_PRESET}.template"),
            {"csProjectSetupVariantPresets": _preset_list([project_setup_preset_name(ctx) for ctx in contexts])},
        ),
    }
    layout_template = load_template(template_dir / LAYOUT_TEMPLATE)
    for name, (description, workspace_root, cscmake_root, build_sub_dir) in LAYOUTS.items():
        rendered[f"layout/{name}.json"] = render_template(
            layout_template,
            {
                "layoutName": name,
                "layoutDescription": description,
                "layoutWorkspaceRoot": workspace_root,
                "layoutCsCMakeRoot": cscmake_root,
                "layoutBuildSubDir": build_sub_dir,
            },
        )
    for name, text in rendered.items():
        json.loads(text)  # validate
        path = output_dir / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8", newline="\n")
    return list(PROJECT_SETUP_PRESETS)


def variants_manifest() -> dict[str, Any]:
    """Return the supported variants as data: for tools that must follow the registry without importing csCMake.

    One entry per variant: its id (as in the preset names), every field and its short form (as in the short build
    folders), the generator type and the build configurations of the workflow presets.
    """
    variants = []
    for ctx in get_supported_context_os_architecture_list():
        subs = build_substitutions(ctx)
        generator_type = ctx.context_compiler_generator.build_generator.generator_type
        fields = [
            "host",
            "osVersion",
            "architecture",
            "architectureVariant",
            "compiler",
            "compiler_version",
            "generator",
        ]
        variants.append(
            {
                "id": create_context_os_architecture_compiler_generator_string(ctx),
                **{field: subs[field] for field in fields},
                "generator_type": generator_type.value,
                "short": {field: subs[f"{field}_short"] for field in ["csVersion", *fields]},
                "build_configs": [c.value for c in get_supported_build_configs_for_generator_type(generator_type)],
            }
        )
    return {"schema": CS_SCHEMA_VERSION, "variants": variants}


def write_variants_manifest(output_dir: Path) -> str:
    """Write ``variants.json`` (:func:`variants_manifest`) into ``output_dir``; return its file name."""
    text = json.dumps(variants_manifest(), indent=2) + "\n"
    (output_dir / VARIANTS_JSON).write_text(text, encoding="utf-8", newline="\n")
    return VARIANTS_JSON


def check_presets_up_to_date(
    template_dir: Path = TEMPLATE_DIR, output_dir: Path = OUTPUT_DIR, setup_output_dir: Path = SETUP_OUTPUT_DIR
) -> list[str]:
    """Return the file names that differ between a fresh generation and the output folders."""
    with tempfile.TemporaryDirectory() as tmp:
        fresh_dir = Path(tmp) / "csv1"
        fresh_setup_dir = Path(tmp) / "setup"
        generate_all_csv1_presets(template_dir, fresh_dir)
        generate_project_setup_presets(template_dir, fresh_setup_dir)
        fresh = {p.name: p.read_bytes() for p in fresh_dir.glob("*.json")}
        fresh_setup = {name: (fresh_setup_dir / name).read_bytes() for name in PROJECT_SETUP_PRESETS}
    current = {p.name: p.read_bytes() for p in output_dir.glob("*.json")}
    current_setup = {
        name: (setup_output_dir / name).read_bytes()
        for name in PROJECT_SETUP_PRESETS
        if (setup_output_dir / name).is_file()
    }
    stale = {name for name in fresh.keys() | current.keys() if fresh.get(name) != current.get(name)}
    stale |= {name for name in PROJECT_SETUP_PRESETS if fresh_setup[name] != current_setup.get(name)}
    return sorted(stale)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--template-dir", type=Path, default=TEMPLATE_DIR, help="templates (default: presets/template)")
    parser.add_argument("--output-dir", type=Path, default=OUTPUT_DIR, help="output folder (default: presets/csv1)")
    parser.add_argument(
        "--setup-output-dir",
        type=Path,
        default=SETUP_OUTPUT_DIR,
        help="output folder of csCMakeProjectSetup*.json and layout/ (default: presets)",
    )
    parser.add_argument("--check", action="store_true", help="do not write; exit 1 if the output folder is stale")
    parser.add_argument("-q", "--quiet", action="store_true", help="do not list generated files")
    args = parser.parse_args(argv)

    if not args.template_dir.is_dir():
        parser.error(
            f"template folder not found: {args.template_dir} (install csCMake in editable mode or pass --template-dir)"
        )

    if args.check:
        stale = check_presets_up_to_date(args.template_dir, args.output_dir, args.setup_output_dir)
        for name in stale:
            print(f"Out of date: {name}")
        if stale:
            print("Run: cscmake-generate-presets")
            return 1
        return 0

    generated = generate_all_csv1_presets(args.template_dir, args.output_dir)
    generated += generate_project_setup_presets(args.template_dir, args.setup_output_dir)
    if not args.quiet:
        for name in generated:
            print(f"Generated: {name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
