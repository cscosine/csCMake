#!/usr/bin/env python3

from __future__ import annotations

import json
import sys
from pathlib import Path

from csorchestrator.domain.context.context_os_architecture_compiler_generator import CS_ORCHESTRATOR_SCHEMA_VERSION
from csorchestrator.domain.context.context_shortened_str import (
    CS_ORCHESTRATOR_SCHEMA_VERSION_SHORT,
    short_architecture,
    short_architecture_variant,
    short_compiler_family,
    short_compiler_version,
    short_generator,
    short_os_name,
    short_os_version,
)
from csorchestrator.frontend.cscmake_presets.supported_variants import (
    GeneratorType,
    get_supported_context_os_architecture_list,
)

from cscmake.utils.generate_cs_preset_variants import (
    generate_from_template_single_config_generator_all,
    load_template,
    render_template,
)

ROOT_DIR = Path(__file__).resolve().parents[2]
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))


def generate_all_csv1_presets() -> list[str]:
    TEMPLATE_FOLDER_PATH_ = ROOT_DIR / "csCMake" / "presets" / "template"
    OUTPUT_DIR = ROOT_DIR / "csCMake" / "presets" / "csv1"

    generated: list[str] = []
    generated_ALL: list[str] = []

    build_configs = ["debug", "release", "paranoid", "relWithDebInfo"]

    configs = get_supported_context_os_architecture_list(
        use_ninja_for_windows=False,
        use_ninja=True,
        use_ninjamulti=True,
        generate_all_combinations=True,
    )

    for config in configs:
        generator_type = config.context_compiler_generator.build_generator.generator_type
        if generator_type == GeneratorType.SINGLE_CONFIG:
            subs = {
                "csVersion": CS_ORCHESTRATOR_SCHEMA_VERSION,
                "host": config.context_os_architecture.os.value,
                "osVersion": config.context_os_architecture.os_version,
                "architecture": config.context_os_architecture.architecture.value,
                "architectureVariant": config.context_os_architecture.architecture_variant,
                "generator": config.context_compiler_generator.build_generator.generator.value,
                "compiler": config.context_compiler_generator.compiler_family.value,
                "compiler_version": config.context_compiler_generator.compiler_version,
                # shortened values
                "csVersion_short": CS_ORCHESTRATOR_SCHEMA_VERSION_SHORT,
                "host_short": short_os_name(config.context_os_architecture.os),
                "osVersion_short": short_os_version(
                    config.context_os_architecture.os, config.context_os_architecture.os_version
                ),
                "architecture_short": short_architecture(config.context_os_architecture.architecture),
                "architectureVariant_short": short_architecture_variant(
                    config.context_os_architecture.architecture, config.context_os_architecture.architecture_variant
                ),
                "generator_short": short_generator(config.context_compiler_generator.build_generator.generator),
                "compiler_short": short_compiler_family(config.context_compiler_generator.compiler_family),
                "compiler_version_short": short_compiler_version(
                    config.context_compiler_generator.compiler_family,
                    config.context_compiler_generator.compiler_version,
                ),
            }
            # -ALL
            all_filename = generate_from_template_single_config_generator_all(
                subs,
                template_path=TEMPLATE_FOLDER_PATH_ / "cs-single-config-generator-ALL.json.template",
                output_dir=OUTPUT_DIR,
                output_filename_suffix="ALL",
            )
            generated.append(all_filename)
            generated_ALL.append(all_filename)

            # -base
            generated.append(
                generate_from_template_single_config_generator_all(
                    subs,
                    template_path=TEMPLATE_FOLDER_PATH_ / "cs-single-config-generator-base.json.template",
                    output_dir=OUTPUT_DIR,
                    output_filename_suffix="base",
                )
            )
            # -configs
            for buildConfig in build_configs:
                generated.append(
                    generate_from_template_single_config_generator_all(
                        {**subs, "buildConfig": buildConfig},
                        template_path=TEMPLATE_FOLDER_PATH_ / "cs-single-config-generator-config.json.template",
                        output_dir=OUTPUT_DIR,
                        output_filename_suffix=buildConfig.lower(),
                    )
                )
        elif generator_type == GeneratorType.MULTI_CONFIG:
            subs = {
                "csVersion": CS_ORCHESTRATOR_SCHEMA_VERSION,
                "host": config.context_os_architecture.os.value,
                "osVersion": config.context_os_architecture.os_version,
                "architecture": config.context_os_architecture.architecture.value,
                "architectureVariant": config.context_os_architecture.architecture_variant,
                "generator": config.context_compiler_generator.build_generator.generator.value,
                "compiler": config.context_compiler_generator.compiler_family.value,
                "compiler_version": config.context_compiler_generator.compiler_version,
                # shortened values
                "csVersion_short": CS_ORCHESTRATOR_SCHEMA_VERSION_SHORT,
                "host_short": short_os_name(config.context_os_architecture.os),
                "osVersion_short": short_os_version(
                    config.context_os_architecture.os, config.context_os_architecture.os_version
                ),
                "architecture_short": short_architecture(config.context_os_architecture.architecture),
                "architectureVariant_short": short_architecture_variant(
                    config.context_os_architecture.architecture, config.context_os_architecture.architecture_variant
                ),
                "generator_short": short_generator(config.context_compiler_generator.build_generator.generator),
                "compiler_short": short_compiler_family(config.context_compiler_generator.compiler_family),
                "compiler_version_short": short_compiler_version(
                    config.context_compiler_generator.compiler_family,
                    config.context_compiler_generator.compiler_version,
                ),
            }
            # -ALL
            all_filename = generate_from_template_single_config_generator_all(
                {**subs},
                template_path=TEMPLATE_FOLDER_PATH_ / "cs-multi-config-generator-ALL.json.template",
                output_dir=OUTPUT_DIR,
                output_filename_suffix="ALL",
            )
            generated.append(all_filename)
            generated_ALL.append(all_filename)

            # -base
            generated.append(
                generate_from_template_single_config_generator_all(
                    {**subs},
                    template_path=TEMPLATE_FOLDER_PATH_ / "cs-multi-config-generator-base.json.template",
                    output_dir=OUTPUT_DIR,
                    output_filename_suffix="base",
                )
            )
            # -configs
            for buildConfig in build_configs:
                generated.append(
                    generate_from_template_single_config_generator_all(
                        {**subs, "buildConfig": buildConfig},
                        template_path=TEMPLATE_FOLDER_PATH_ / "cs-multi-config-generator-config.json.template",
                        output_dir=OUTPUT_DIR,
                        output_filename_suffix=buildConfig.lower(),
                    )
                )
        else:
            raise ValueError(f"unsupported GeneratorType {generator_type.value}")

    # generate a sigle presets that includes all the *-ALL presets

    # no need for set here, is a single list, but let be defensive
    generated_ALL_set = sorted(list(set(generated_ALL)))

    csIncludeLines = ""
    for i in range(len(generated_ALL_set) - 1):
        filename = generated_ALL_set[i]
        csIncludeLines += f'        "{filename}",\n'
    if len(generated_ALL_set) > 0:
        csIncludeLines += f'        "{generated_ALL_set[-1]}"'

    cs_presets_all_json = "cs-presets-all.json"
    template_path = TEMPLATE_FOLDER_PATH_ / str(cs_presets_all_json + ".template")
    template_text = load_template(template_path)
    rendered = render_template(template_text, {"csIncludeLines": csIncludeLines})

    # Validate that the template produced valid JSON.
    json.loads(rendered)

    output_path = OUTPUT_DIR / cs_presets_all_json

    output_path.write_text(rendered, encoding="utf-8")
    generated.append(cs_presets_all_json)

    return generated


def main() -> None:
    generated = generate_all_csv1_presets()
    for path in generated:
        print(f"Generated: {path}")


if __name__ == "__main__":
    main()
