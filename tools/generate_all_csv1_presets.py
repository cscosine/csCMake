from __future__ import annotations

import json
import sys
from pathlib import Path

from csorchestrator.context.context_os_architecture_compiler_generator import cs_orchestrator_schema_version
from csorchestrator.utils.presets.supported_variants import GeneratorType, get_supported_context_os_architecture_list

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

    # TODO: FIX this is returning multiple time the same config,
    # bc the ContextOsArchitectureCompilerGeneratorConfig contains also BuildConfig

    single_configs = get_supported_context_os_architecture_list(generator_type=GeneratorType.SINGLE_CONFIG)

    for config in single_configs:
        subs = {
            "csVersion": cs_orchestrator_schema_version,
            "host": config.context_os_architecture.os.value,
            "osVersion": config.context_os_architecture.os_version,
            "architecture": config.context_os_architecture.architecture.value,
            "architectureVariant": config.context_os_architecture.architecture_variant,
            "generator": config.context_compiler_generator.build_generator.value,
            "compiler": config.context_compiler_generator.compiler_family.value,
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

    # multi config generator presets in linux
    multi_configs = get_supported_context_os_architecture_list(generator_type=GeneratorType.MULTI_CONFIG)

    for config in multi_configs:
        subs = {
            "csVersion": cs_orchestrator_schema_version,
            "host": config.context_os_architecture.os.value,
            "osVersion": config.context_os_architecture.os_version,
            "architecture": config.context_os_architecture.architecture.value,
            "architectureVariant": config.context_os_architecture.architecture_variant,
            "generator": config.context_compiler_generator.build_generator.value,
            "compiler": config.context_compiler_generator.compiler_family.value,
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

    # generate a sigle presets that includes all the *-ALL presets

    # TODO when fixed get_supported_context_os_architecture_list,
    # no need for set here, but can be kept
    generated_ALL_set = list(set(generated_ALL))
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
