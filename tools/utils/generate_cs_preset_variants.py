from __future__ import annotations

import argparse
import json
from pathlib import Path
from string import Template
from typing import Any, Dict, Iterable, Mapping


TEMPLATE_NAME = "cs-single-config-generator-ALL.json.template"

DEFAULT_TEMPLATE_PATH = Path(__file__).resolve().parents[1] / "presets" / "template" / TEMPLATE_NAME
DEFAULT_OUTPUT_DIR = Path(__file__).resolve().parents[1] / "presets" / "csv1"

REQUIRED_SUBSTITUTIONS = [
    "csVersion",
    "host",
    "os",
    "architecture",
    "architectureVariant",
    "compiler",
    "generator",
]


def load_template(path: Path | str = None) -> str:
    path = Path(path or DEFAULT_TEMPLATE_PATH)
    return path.read_text(encoding="utf-8")


def render_template(template_text: str, substitutions: Mapping[str, Any]) -> str:
    data: Dict[str, str] = {k: str(v) for k, v in substitutions.items()}
    data.setdefault("csVersion_upper", data.get("csVersion", "").upper())
    return Template(template_text).substitute(data)


def build_output_filename(substitutions: Mapping[str, Any], suffix: str = "ALL") -> str:
    values = {k: str(substitutions.get(k, "")) for k in REQUIRED_SUBSTITUTIONS}
    return (
        f"{values['csVersion']}-{values['host']}-{values['os']}-"
        f"{values['architecture']}-{values['architectureVariant']}-"
        f"{values['compiler']}-{values['generator']}-{suffix}.json"
    )


def validate_substitutions(substitutions: Mapping[str, Any]) -> None:
    missing = [key for key in REQUIRED_SUBSTITUTIONS if key not in substitutions or substitutions[key] is None]
    if missing:
        raise ValueError(f"Missing required substitution keys: {', '.join(missing)}")


def generate_from_template_single_config_generator_all(
    substitutions: Mapping[str, Any],
    template_path: Path | str = None,
    output_dir: Path | str = None,
) -> Path:
    validate_substitutions(substitutions)
    template_text = load_template(template_path)
    rendered = render_template(template_text, substitutions)

    # Validate that the template produced valid JSON.
    json.loads(rendered)

    output_dir = Path(output_dir or DEFAULT_OUTPUT_DIR)
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / build_output_filename(substitutions, suffix="ALL")

    output_path.write_text(rendered, encoding="utf-8")
    return output_path


