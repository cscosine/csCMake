from __future__ import annotations

import sys
from pathlib import Path
from typing import Iterable

ROOT_DIR = Path(__file__).resolve().parents[2]
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from csCMake.tools.utils.generate_cs_preset_variants import generate_from_template_single_config_generator_all





def generate_all_csv1_presets() -> list[Path]:
    TEMPLATE_FOLDER_PATH_ = ROOT_DIR / "csCMake" / "presets" / "template" 
    OUTPUT_DIR = ROOT_DIR / "csCMake" / "presets" / "csv1"

    DEFAULT_SUBSTITUTIONS = {
        "csVersion": "csv1",
        "host": "linux",
        "osVersion": "ubuntu24.04",
        "architecture": "x64",
        "architectureVariant": "generic"
    }

    ## -- single config generator presets --    
    SINGLE_CONFIG_DEFAULT_SUBSTITUTIONS = {
        **DEFAULT_SUBSTITUTIONS,
        "generator": "ninja",
    }

    generated: list[Path] = []
    for compiler in ["gcc", "clang"]:
        # -ALL
        generated.append(generate_from_template_single_config_generator_all({**SINGLE_CONFIG_DEFAULT_SUBSTITUTIONS, "compiler": compiler}, template_path=TEMPLATE_FOLDER_PATH_ / "cs-single-config-generator-ALL.json.template", output_dir=OUTPUT_DIR, output_filename_suffix="ALL"))
        # -base
        generated.append(generate_from_template_single_config_generator_all({**SINGLE_CONFIG_DEFAULT_SUBSTITUTIONS, "compiler": compiler}, template_path=TEMPLATE_FOLDER_PATH_ / "cs-single-config-generator-base.json.template", output_dir=OUTPUT_DIR, output_filename_suffix="base"))
        # -configs
        for buildConfig in ["debug", "release", "paranoid", "relWithDebInfo"]:
            generated.append(generate_from_template_single_config_generator_all({**SINGLE_CONFIG_DEFAULT_SUBSTITUTIONS, "compiler": compiler, "buildConfig": buildConfig}, template_path=TEMPLATE_FOLDER_PATH_ / "cs-single-config-generator-config.json.template", output_dir=OUTPUT_DIR, output_filename_suffix=buildConfig.lower()))

    # multi config genreator presets
    MULTI_CONFIG_DEFAULT_SUBSTITUTIONS = {
        **DEFAULT_SUBSTITUTIONS,
        "generator": "ninjamulticonfig",
    }

    for compiler in ["gcc", "clang"]:
        # -ALL
        generated.append(generate_from_template_single_config_generator_all({**MULTI_CONFIG_DEFAULT_SUBSTITUTIONS, "compiler": compiler}, template_path=TEMPLATE_FOLDER_PATH_ / "cs-multi-config-generator-ALL.json.template", output_dir=OUTPUT_DIR, output_filename_suffix="ALL"))
        # -base
        generated.append(generate_from_template_single_config_generator_all({**MULTI_CONFIG_DEFAULT_SUBSTITUTIONS, "compiler": compiler}, template_path=TEMPLATE_FOLDER_PATH_ / "cs-multi-config-generator-base.json.template", output_dir=OUTPUT_DIR, output_filename_suffix="base"))
        # -configs
        for buildConfig in ["debug", "release", "paranoid", "relWithDebInfo"]:
            generated.append(generate_from_template_single_config_generator_all({**MULTI_CONFIG_DEFAULT_SUBSTITUTIONS, "compiler": compiler, "buildConfig": buildConfig}, template_path=TEMPLATE_FOLDER_PATH_ / "cs-multi-config-generator-config.json.template", output_dir=OUTPUT_DIR, output_filename_suffix=buildConfig.lower()))

    return generated


def main() -> None:
    generated = generate_all_csv1_presets()
    for path in generated:
        print(f"Generated: {path}")


if __name__ == "__main__":
    main()
