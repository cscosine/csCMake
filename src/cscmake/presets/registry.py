"""Built-in registry of the csv1 preset variants.

This module is the single source of truth for the OS x architecture x compiler x generator
matrix rendered into ``presets/csv1/``. It only depends on the Python standard library.

Names, enum values and short forms are part of the preset file names and preset ids consumed
by downstream projects: changing any value here renames generated presets.
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import ClassVar, assert_never

CS_SCHEMA_VERSION = "csv1"
CS_SCHEMA_VERSION_SHORT = "v1"


class OS(Enum):
    WINDOWS = "windows"
    LINUX = "linux"
    MACOS = "macos"


UBUNTU_STRING_PREFIX = "ubuntu"


class UbuntuVersions(Enum):
    UBUNTU_22_04 = UBUNTU_STRING_PREFIX + "22.04"
    UBUNTU_24_04 = UBUNTU_STRING_PREFIX + "24.04"
    UBUNTU_26_04 = UBUNTU_STRING_PREFIX + "26.04"


class WindowsVersions(Enum):
    WIN10 = "v10"


MACOS_STRING_PREFIX = "macos"


class MacOSVersions(Enum):
    MACOS_15 = MACOS_STRING_PREFIX + "15"
    MACOS_26 = MACOS_STRING_PREFIX + "26"


class Architecture(Enum):
    X64 = "x64"
    ARM64 = "arm64"


ARCHITECTURE_VARIANT_GENERIC = "generic"
ARCHITECTURE_VARIANT_ARM64_ORIN = "orin"
ARCHITECTURE_VARIANT_ARM64_XAVIER = "xavier"
ARCHITECTURE_VARIANT_ARM64_NANO = "nano"


class Compiler(Enum):
    MSVC = "msvc"
    MSVC_CLANG = "msvcclang"
    CLANG = "clang"
    GCC = "gcc"
    APPLE_CLANG = "appleclang"


COMPILER_VERSION_DEFAULT = "default"
COMPILER_VERSION_MSVC_2022_17 = "MSVC_2022_17"
COMPILER_VERSION_MSVC_2026_18 = "MSVC_2026_18"


class Generator(Enum):
    NINJA = "ninja"
    NINJA_MULTI = "ninjamulticonfig"
    MSVC_17_2022 = "msvc2022"
    MSVC_18_2026 = "msvc2026"
    XCODE = "xcode"


class GeneratorType(Enum):
    SINGLE_CONFIG = "singleconfig"
    MULTI_CONFIG = "multiconfig"


class BuildConfig(Enum):
    DEBUG = "debug"
    RELEASE = "release"
    PARANOID = "paranoid"
    RELWITHDEBINFO = "relWithDebInfo"
    DEBUG_RELEASE = "debug-release"
    DEBUG_RELEASE_RELWITHDEBINFO_PARANOID = "debug-release-relWithDebInfo-paranoid"


@dataclass(frozen=True)
class GeneratorWithType:
    generator: Generator
    generator_type: GeneratorType

    NINJA: ClassVar[GeneratorWithType]
    NINJA_MULTI: ClassVar[GeneratorWithType]
    MSVC_17_2022: ClassVar[GeneratorWithType]
    MSVC_18_2026: ClassVar[GeneratorWithType]
    XCODE: ClassVar[GeneratorWithType]


GeneratorWithType.NINJA = GeneratorWithType(Generator.NINJA, GeneratorType.SINGLE_CONFIG)
GeneratorWithType.NINJA_MULTI = GeneratorWithType(Generator.NINJA_MULTI, GeneratorType.MULTI_CONFIG)
GeneratorWithType.MSVC_17_2022 = GeneratorWithType(Generator.MSVC_17_2022, GeneratorType.MULTI_CONFIG)
GeneratorWithType.MSVC_18_2026 = GeneratorWithType(Generator.MSVC_18_2026, GeneratorType.MULTI_CONFIG)
GeneratorWithType.XCODE = GeneratorWithType(Generator.XCODE, GeneratorType.MULTI_CONFIG)


@dataclass(frozen=True)
class ContextOsArchitecture:
    os: OS
    os_version: str
    architecture: Architecture
    architecture_variant: str


@dataclass(frozen=True)
class ContextCompilerGenerator:
    compiler_family: Compiler
    compiler_version: str  # COMPILER_VERSION_DEFAULT for the os/generator default compiler
    build_generator: GeneratorWithType


@dataclass(frozen=True)
class ContextOsArchitectureCompilerGenerator:
    context_os_architecture: ContextOsArchitecture
    context_compiler_generator: ContextCompilerGenerator


# =========================================================
# Supported matrix
# =========================================================


def get_supported_os_version_list(os: OS) -> list[str]:
    """Return the supported OS version strings for ``os``."""
    match os:
        case OS.LINUX:
            return [v.value for v in UbuntuVersions]
        case OS.WINDOWS:
            return [WindowsVersions.WIN10.value]
        case OS.MACOS:
            return [v.value for v in MacOSVersions]
        case _:
            assert_never(os)


def get_supported_build_configs_for_generator_type(generator_type: GeneratorType) -> list[BuildConfig]:
    """Return the build configurations usable with a generator of ``generator_type``."""
    single = [BuildConfig.DEBUG, BuildConfig.RELEASE, BuildConfig.RELWITHDEBINFO, BuildConfig.PARANOID]
    match generator_type:
        case GeneratorType.SINGLE_CONFIG:
            return single
        case GeneratorType.MULTI_CONFIG:
            return [*single, BuildConfig.DEBUG_RELEASE, BuildConfig.DEBUG_RELEASE_RELWITHDEBINFO_PARANOID]
        case _:
            assert_never(generator_type)


def get_supported_generators_linux(
    arch: Architecture, use_ninja: bool, use_ninjamulti: bool, generate_all_combinations: bool
) -> list[GeneratorWithType]:
    """Return the Linux generators for ``arch``.

    With ``generate_all_combinations`` both Ninja flavours are returned. Otherwise x64 prefers
    Ninja Multi-Config and arm64 prefers single-config Ninja, falling back to the other one.
    """
    if generate_all_combinations:
        return [GeneratorWithType.NINJA, GeneratorWithType.NINJA_MULTI]
    match arch:
        case Architecture.X64:
            preferred = [(use_ninjamulti, GeneratorWithType.NINJA_MULTI), (use_ninja, GeneratorWithType.NINJA)]
        case Architecture.ARM64:
            preferred = [(use_ninja, GeneratorWithType.NINJA), (use_ninjamulti, GeneratorWithType.NINJA_MULTI)]
        case _:
            assert_never(arch)
    for enabled, generator in preferred:
        if enabled:
            return [generator]
    return []


def get_supported_generators_windows(
    use_ninja_for_windows: bool, use_ninja: bool, use_ninjamulti: bool
) -> list[GeneratorWithType]:
    """Return the Windows generators: Visual Studio by default, Ninja flavours on request."""
    if not use_ninja_for_windows:
        return [GeneratorWithType.MSVC_17_2022, GeneratorWithType.MSVC_18_2026]
    lst: list[GeneratorWithType] = []
    if use_ninja:
        lst.append(GeneratorWithType.NINJA)
    if use_ninjamulti:
        lst.append(GeneratorWithType.NINJA_MULTI)
    return lst


def get_supported_generators_macos(use_ninja: bool, use_ninjamulti: bool) -> list[GeneratorWithType]:
    """Return the macOS generators: the Ninja flavours (on request) and Xcode."""
    lst: list[GeneratorWithType] = []
    if use_ninja:
        lst.append(GeneratorWithType.NINJA)
    if use_ninjamulti:
        lst.append(GeneratorWithType.NINJA_MULTI)
    lst.append(GeneratorWithType.XCODE)
    return lst


def get_supported_architectures_macos() -> list[Architecture]:
    """Return the supported macOS architectures: Apple Silicon only (no Intel Mac sold since 2023)."""
    return [Architecture.ARM64]


def get_supported_compilers_macos() -> list[Compiler]:
    """Return the supported macOS compiler families."""
    return [Compiler.APPLE_CLANG]


def get_supported_compilers_linux() -> list[Compiler]:
    """Return the supported Linux compiler families."""
    return [Compiler.GCC, Compiler.CLANG]


def get_supported_compilers_windows(use_ninja_for_windows: bool) -> list[tuple[Compiler, str]]:
    """Return the supported Windows (compiler, version) pairs.

    Visual Studio generators pick the toolset themselves (default version); Ninja needs an
    explicit MSVC version to select the developer environment.
    """
    if not use_ninja_for_windows:
        return [(Compiler.MSVC, COMPILER_VERSION_DEFAULT), (Compiler.MSVC_CLANG, COMPILER_VERSION_DEFAULT)]
    return [
        (Compiler.MSVC, COMPILER_VERSION_MSVC_2022_17),
        (Compiler.MSVC_CLANG, COMPILER_VERSION_MSVC_2022_17),
        (Compiler.MSVC, COMPILER_VERSION_MSVC_2026_18),
        (Compiler.MSVC_CLANG, COMPILER_VERSION_MSVC_2026_18),
    ]


def get_supported_context_os_architecture_list(
    use_ninja_for_windows: bool = True,
    use_ninja: bool = True,
    use_ninjamulti: bool = True,
    generate_all_combinations: bool = True,
) -> list[ContextOsArchitectureCompilerGenerator]:
    """Return every supported OS/architecture/compiler/generator combination.

    The defaults produce the full csv1 matrix committed under ``presets/csv1/``.
    """
    ret: list[ContextOsArchitectureCompilerGenerator] = []

    for os_version in get_supported_os_version_list(OS.LINUX):
        for arch in [Architecture.X64, Architecture.ARM64]:
            os_arch = ContextOsArchitecture(OS.LINUX, os_version, arch, ARCHITECTURE_VARIANT_GENERIC)
            generators = get_supported_generators_linux(arch, use_ninja, use_ninjamulti, generate_all_combinations)
            for compiler in get_supported_compilers_linux():
                for generator in generators:
                    ccg = ContextCompilerGenerator(compiler, COMPILER_VERSION_DEFAULT, generator)
                    ret.append(ContextOsArchitectureCompilerGenerator(os_arch, ccg))

    for os_version in get_supported_os_version_list(OS.WINDOWS):
        os_arch = ContextOsArchitecture(OS.WINDOWS, os_version, Architecture.X64, ARCHITECTURE_VARIANT_GENERIC)
        # Visual Studio generators, then (use_ninja_for_windows) the Ninja ones with an explicit MSVC version
        for ninja in [False, True] if use_ninja_for_windows else [False]:
            generators = get_supported_generators_windows(ninja, use_ninja, use_ninjamulti)
            for compiler, version in get_supported_compilers_windows(ninja):
                for generator in generators:
                    ccg = ContextCompilerGenerator(compiler, version, generator)
                    ret.append(ContextOsArchitectureCompilerGenerator(os_arch, ccg))

    for os_version in get_supported_os_version_list(OS.MACOS):
        for arch in get_supported_architectures_macos():
            os_arch = ContextOsArchitecture(OS.MACOS, os_version, arch, ARCHITECTURE_VARIANT_GENERIC)
            for compiler in get_supported_compilers_macos():
                for generator in get_supported_generators_macos(use_ninja, use_ninjamulti):
                    ccg = ContextCompilerGenerator(compiler, COMPILER_VERSION_DEFAULT, generator)
                    ret.append(ContextOsArchitectureCompilerGenerator(os_arch, ccg))

    return ret


def create_context_os_architecture_compiler_generator_string_without_schema(
    ctx: ContextOsArchitectureCompilerGenerator,
) -> str:
    """Return the id of ``ctx`` without the schema version, e.g. ``linux-ubuntu24.04-x64-generic-gcc-default-ninja``."""
    osa = ctx.context_os_architecture
    ccg = ctx.context_compiler_generator
    parts = [
        osa.os.value,
        osa.os_version,
        osa.architecture.value,
        osa.architecture_variant,
        ccg.compiler_family.value,
        ccg.compiler_version,
        ccg.build_generator.generator.value,
    ]
    return "-".join(p.lower() for p in parts)


def create_context_os_architecture_compiler_generator_string(ctx: ContextOsArchitectureCompilerGenerator) -> str:
    """Return the canonical id of ``ctx``, e.g. ``csv1-linux-ubuntu24.04-x64-generic-gcc-default-ninja``."""
    return f"{CS_SCHEMA_VERSION}-{create_context_os_architecture_compiler_generator_string_without_schema(ctx)}"


# =========================================================
# Short forms (used to keep build/install paths short)
# =========================================================


def short_os_name(os: OS) -> str:
    return os.value[0]


def short_os_version(os: OS, version: str) -> str:
    if os == OS.LINUX:
        return version.replace(UBUNTU_STRING_PREFIX, UBUNTU_STRING_PREFIX[0])
    if os == OS.MACOS:
        return version.replace(MACOS_STRING_PREFIX, MACOS_STRING_PREFIX[0])
    return version


def short_architecture(arch: Architecture) -> str:
    match arch:
        case Architecture.X64:
            return "x64"
        case Architecture.ARM64:
            return "a64"
        case _:
            assert_never(arch)


_SHORT_ARCHITECTURE_VARIANT = {
    ARCHITECTURE_VARIANT_GENERIC: "g",
    ARCHITECTURE_VARIANT_ARM64_ORIN: "o",
    ARCHITECTURE_VARIANT_ARM64_XAVIER: "x",
    ARCHITECTURE_VARIANT_ARM64_NANO: "n",
}


def short_architecture_variant(variant: str) -> str:
    return _SHORT_ARCHITECTURE_VARIANT.get(variant, variant)


_SHORT_GENERATOR = {
    Generator.NINJA: "n",
    Generator.NINJA_MULTI: "nm",
    Generator.MSVC_17_2022: "ms22",
    Generator.MSVC_18_2026: "ms26",
    Generator.XCODE: "xc",
}


def short_generator(g: Generator) -> str:
    return _SHORT_GENERATOR[g]


_SHORT_COMPILER = {
    Compiler.MSVC: "m",
    Compiler.MSVC_CLANG: "mc",
    Compiler.CLANG: "c",
    Compiler.GCC: "g",
    Compiler.APPLE_CLANG: "ac",
}


def short_compiler_family(c: Compiler) -> str:
    return _SHORT_COMPILER[c]


_SHORT_COMPILER_VERSION = {
    COMPILER_VERSION_DEFAULT: "d",
    COMPILER_VERSION_MSVC_2022_17: "22",
    COMPILER_VERSION_MSVC_2026_18: "26",
}


def short_compiler_version(v: str) -> str:
    return _SHORT_COMPILER_VERSION.get(v, v)
