from __future__ import annotations

import json
from pathlib import Path
from string import Template
from typing import Any, Dict, Mapping

TEMPLATE_NAME = "cs-single-config-generator-ALL.json.template"

REQUIRED_SUBSTITUTIONS = [
    "csVersion",
    "host",
    "osVersion",
    "architecture",
    "architectureVariant",
    "compiler",
    "generator",
]


class AtTemplate(Template):
    delimiter = "@"


def load_template(path: Path | str) -> str:
    path = Path(path)
    return path.read_text(encoding="utf-8")


def render_template(template_text: str, substitutions: Mapping[str, Any]) -> str:
    data: Dict[str, str] = {k: str(v) for k, v in substitutions.items()}
    return AtTemplate(template_text).substitute(data)


def build_output_filename(substitutions: Mapping[str, Any], suffix: str = "ALL") -> str:
    values = {k: str(substitutions.get(k, "")) for k in REQUIRED_SUBSTITUTIONS}
    return (
        f"{values['csVersion']}-{values['host']}-{values['osVersion']}-"
        f"{values['architecture']}-{values['architectureVariant']}-"
        f"{values['compiler']}-{values['generator']}-{suffix}.json"
    )


def validate_substitutions(substitutions: Mapping[str, Any]) -> None:
    missing = [key for key in REQUIRED_SUBSTITUTIONS if key not in substitutions or substitutions[key] is None]
    if missing:
        raise ValueError(f"Missing required substitution keys: {', '.join(missing)}")


def generate_from_template_single_config_generator_all(
    substitutions: Mapping[str, Any],
    template_path: Path,
    output_dir: Path,
    output_filename_suffix: str,
) -> str:
    validate_substitutions(substitutions)
    template_text = load_template(template_path)
    rendered = render_template(template_text, substitutions)

    # Validate that the template produced valid JSON.
    json.loads(rendered)

    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    filename = build_output_filename(substitutions, suffix=output_filename_suffix)
    output_path = output_dir / filename

    output_path.write_text(rendered, encoding="utf-8")
    return filename
