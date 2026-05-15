from __future__ import annotations

import sys
from pathlib import Path
from typing import Iterable

ROOT_DIR = Path(__file__).resolve().parents[2]
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from csCMake.tools.utils.generate_cs_preset_variants import generate_from_template_single_config_generator_all

TEMPLATE_PATH = ROOT_DIR / "csCMake" / "presets" / "template" / "cs-single-config-generator-ALL.json.template"
OUTPUT_DIR = ROOT_DIR / "csCMake" / "presets" / "csv1"




def generate_all_csv1_presets(
    template_path: Path | str | None = TEMPLATE_PATH,
    output_dir: Path | str | None = OUTPUT_DIR,
) -> list[Path]:
    ## -- single config generator ALL presets --    
    DEFAULT_SUBSTITUTIONS = {
        "csVersion": "csv1",
        "host": "linux",
        "os": "ubuntu24.04",
        "architecture": "x64",
        "architectureVariant": "generic",
        "generator": "ninja",
    }

    generated: list[Path] = []
    generated.append(generate_from_template_single_config_generator_all({**DEFAULT_SUBSTITUTIONS, "compiler": "gcc"}, template_path=template_path, output_dir=output_dir))
    generated.append(generate_from_template_single_config_generator_all({**DEFAULT_SUBSTITUTIONS, "compiler": "clang"}, template_path=template_path, output_dir=output_dir))
    return generated


def main() -> None:
    generated = generate_all_csv1_presets()
    for path in generated:
        print(f"Generated: {path}")


if __name__ == "__main__":
    main()
