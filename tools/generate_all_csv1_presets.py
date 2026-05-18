from __future__ import annotations

import sys
from pathlib import Path
from typing import Iterable

ROOT_DIR = Path(__file__).resolve().parents[2]
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from csCMake.tools.utils.generate_cs_preset_variants import generate_from_template_single_config_generator_all

from csorchestrator.context.context_os_architecture_compiler_generator import cs_orchestrator_schema_version, get_supported_context_os_architecture_list
from csorchestrator.context.context_compiler_generator import    GeneratorType


def generate_all_csv1_presets() -> list[Path]:
    TEMPLATE_FOLDER_PATH_ = ROOT_DIR / "csCMake" / "presets" / "template" 
    OUTPUT_DIR = ROOT_DIR / "csCMake" / "presets" / "csv1"
    
    generated: list[Path] = []

    build_configs = ["debug", "release", "paranoid", "relWithDebInfo"]

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
        generated.append(generate_from_template_single_config_generator_all(subs, template_path=TEMPLATE_FOLDER_PATH_ / "cs-single-config-generator-ALL.json.template", output_dir=OUTPUT_DIR, output_filename_suffix="ALL"))
        # -base
        generated.append(generate_from_template_single_config_generator_all(subs, template_path=TEMPLATE_FOLDER_PATH_ / "cs-single-config-generator-base.json.template", output_dir=OUTPUT_DIR, output_filename_suffix="base"))
        # -configs
        for buildConfig in build_configs:
            generated.append(generate_from_template_single_config_generator_all({**subs, "buildConfig": buildConfig}, template_path=TEMPLATE_FOLDER_PATH_ / "cs-single-config-generator-config.json.template", output_dir=OUTPUT_DIR, output_filename_suffix=buildConfig.lower()))

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
        generated.append(generate_from_template_single_config_generator_all({**subs}, template_path=TEMPLATE_FOLDER_PATH_ / "cs-multi-config-generator-ALL.json.template", output_dir=OUTPUT_DIR, output_filename_suffix="ALL"))
        # -base
        generated.append(generate_from_template_single_config_generator_all({**subs}, template_path=TEMPLATE_FOLDER_PATH_ / "cs-multi-config-generator-base.json.template", output_dir=OUTPUT_DIR, output_filename_suffix="base"))
        # -configs
        for buildConfig in build_configs:
            generated.append(generate_from_template_single_config_generator_all({**subs, "buildConfig": buildConfig}, template_path=TEMPLATE_FOLDER_PATH_ / "cs-multi-config-generator-config.json.template", output_dir=OUTPUT_DIR, output_filename_suffix=buildConfig.lower()))

    return generated


def main() -> None:
    generated = generate_all_csv1_presets()
    for path in generated:
        print(f"Generated: {path}")


if __name__ == "__main__":
    main()
