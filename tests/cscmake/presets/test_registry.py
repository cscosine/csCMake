from cscmake.presets.generate import OUTPUT_DIR, check_presets_up_to_date
from cscmake.presets.registry import (
    create_context_os_architecture_compiler_generator_string,
    get_supported_context_os_architecture_list,
)


def test_default_matrix_matches_committed_presets() -> None:
    ids = {
        create_context_os_architecture_compiler_generator_string(c)
        for c in get_supported_context_os_architecture_list()
    }
    # filter by name, not glob("*-ALL.json"): globbing is case-insensitive on Windows (matches cs-presets-all.json)
    committed = {p.name.removesuffix("-ALL.json") for p in OUTPUT_DIR.glob("*.json") if p.name.endswith("-ALL.json")}
    assert ids == committed
    assert len(ids) == 20


def test_committed_presets_are_up_to_date() -> None:
    assert check_presets_up_to_date() == []
