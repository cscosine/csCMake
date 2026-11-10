import pytest

from cscmake.presets.generate import OUTPUT_DIR, check_presets_up_to_date
from cscmake.presets.registry import (
    CS_SCHEMA_VERSION,
    OS,
    Architecture,
    Generator,
    GeneratorType,
    GeneratorWithType,
    create_context_os_architecture_compiler_generator_string,
    create_context_os_architecture_compiler_generator_string_without_schema,
    get_supported_context_os_architecture_list,
    get_supported_generators_linux,
    short_generator,
    short_os_name,
    short_os_version,
)


def test_default_matrix_matches_committed_presets() -> None:
    ids = {
        create_context_os_architecture_compiler_generator_string(c)
        for c in get_supported_context_os_architecture_list()
    }
    # filter by name, not glob("*-ALL.json"): globbing is case-insensitive on Windows (matches cs-presets-all.json)
    committed = {p.name.removesuffix("-ALL.json") for p in OUTPUT_DIR.glob("*.json") if p.name.endswith("-ALL.json")}
    assert ids == committed
    assert len(ids) == 42


def test_committed_presets_are_up_to_date() -> None:
    assert check_presets_up_to_date() == []


def test_canonical_id_is_schema_plus_id_without_schema() -> None:
    for ctx in get_supported_context_os_architecture_list():
        full = create_context_os_architecture_compiler_generator_string(ctx)
        assert (
            full
            == f"{CS_SCHEMA_VERSION}-{create_context_os_architecture_compiler_generator_string_without_schema(ctx)}"
        )


def test_macos_variants_are_arm64_apple_clang_with_three_generators() -> None:
    macos = [c for c in get_supported_context_os_architecture_list() if c.context_os_architecture.os == OS.MACOS]
    ids = {create_context_os_architecture_compiler_generator_string(c) for c in macos}

    assert ids == {
        f"csv1-macos-{version}-arm64-generic-appleclang-default-{generator}"
        for version in ("macos15", "macos26")
        for generator in ("ninja", "ninjamulticonfig", "xcode")
    }
    assert {c.context_os_architecture.architecture for c in macos} == {Architecture.ARM64}
    xcode = [c for c in macos if c.context_compiler_generator.build_generator.generator == Generator.XCODE]
    assert {c.context_compiler_generator.build_generator.generator_type for c in xcode} == {GeneratorType.MULTI_CONFIG}


def test_macos_short_forms() -> None:
    assert short_os_name(OS.MACOS) == "m"
    assert short_os_version(OS.MACOS, "macos26") == "m26"
    assert short_generator(Generator.XCODE) == "xc"


def test_macos_without_ninja_has_only_xcode() -> None:
    macos = [
        c
        for c in get_supported_context_os_architecture_list(use_ninja=False, use_ninjamulti=False)
        if c.context_os_architecture.os == OS.MACOS
    ]
    assert {c.context_compiler_generator.build_generator.generator for c in macos} == {Generator.XCODE}


def test_windows_variants_visual_studio_and_ninja() -> None:
    windows = {
        create_context_os_architecture_compiler_generator_string(c)
        for c in get_supported_context_os_architecture_list()
        if c.context_os_architecture.os == OS.WINDOWS
    }
    ninja = {
        f"csv1-windows-v10-x64-generic-{compiler}-{version}-{generator}"
        for compiler in ("msvc", "msvcclang")
        for version in ("msvc_2022_17", "msvc_2026_18")
        for generator in ("ninja", "ninjamulticonfig")
    }
    visual_studio = {
        f"csv1-windows-v10-x64-generic-{compiler}-default-{generator}"
        for compiler in ("msvc", "msvcclang")
        for generator in ("msvc2022", "msvc2026")
    }
    assert windows == ninja | visual_studio
    without_ninja = {
        create_context_os_architecture_compiler_generator_string(c)
        for c in get_supported_context_os_architecture_list(use_ninja_for_windows=False)
        if c.context_os_architecture.os == OS.WINDOWS
    }
    assert without_ninja == visual_studio


@pytest.mark.parametrize(
    ("arch", "use_ninja", "use_ninjamulti", "expected"),
    [
        (Architecture.X64, True, True, [GeneratorWithType.NINJA_MULTI]),
        (Architecture.X64, True, False, [GeneratorWithType.NINJA]),
        (Architecture.ARM64, True, True, [GeneratorWithType.NINJA]),
        (Architecture.ARM64, False, True, [GeneratorWithType.NINJA_MULTI]),
        (Architecture.X64, False, False, []),
    ],
)
def test_linux_generator_preference(
    arch: Architecture, use_ninja: bool, use_ninjamulti: bool, expected: list[GeneratorWithType]
) -> None:
    assert get_supported_generators_linux(arch, use_ninja, use_ninjamulti, generate_all_combinations=False) == expected
