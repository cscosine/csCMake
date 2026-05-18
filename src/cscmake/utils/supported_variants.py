from dataclasses import dataclass
from enum import Enum
from typing import FrozenSet, Iterable

from csorchestrator.context.context_compiler_generator import (
    Compiler,
    ContextCompilerGenerator,
    Generator,
)
from csorchestrator.context.context_os_architecture import OS, Architecture, ContextOsArchitecture
from csorchestrator.context.context_os_architecture_compiler_generator import (
    create_context_os_architecture_compiler_generator_string,
)
from csorchestrator.core.expected import Expected


class GeneratorType(Enum):
    SINGLE_CONFIG = "singleconfig"
    MULTI_CONFIG = "multiconfig"


@dataclass
class ContextOsArchitectureCompilerGenerator:
    context_os_architecture: ContextOsArchitecture
    context_compiler_generator: ContextCompilerGenerator


def get_supported_context_os_architecture_list(
    generator_type: GeneratorType | None = None,
) -> list[ContextOsArchitectureCompilerGenerator]:

    retList: list[ContextOsArchitectureCompilerGenerator] = []

    ## LINUX
    for os_version in ["ubuntu24.04"]:  # TODO add "ubuntu22.04" and/or "ubuntu26.04",
        linux_ubuntu2404_x64_generic = ContextOsArchitecture(
            os=OS.LINUX,
            os_version=os_version,
            architecture=Architecture.X64,
            architecture_variant=ContextOsArchitecture.ARCHITECTURE_VARIANT_GENERIC,
        )

        if generator_type is None:
            generators = [Generator.NINJA, Generator.NINJA_MULTI]
        elif generator_type == GeneratorType.SINGLE_CONFIG:
            generators = [Generator.NINJA]
        elif generator_type == GeneratorType.MULTI_CONFIG:
            generators = [Generator.NINJA_MULTI]
        else:
            generators = []

        for compiler in [Compiler.CLANG, Compiler.GCC]:
            for generator in generators:
                ccg = ContextCompilerGenerator(compiler_family=compiler, build_generator=generator)
                retList.append(
                    ContextOsArchitectureCompilerGenerator(
                        context_os_architecture=linux_ubuntu2404_x64_generic, context_compiler_generator=ccg
                    )
                )

    ## WINDOWS

    for os_version in ["v10", "v11"]:
        windows_x64_generic = ContextOsArchitecture(
            os=OS.WINDOWS,
            os_version=os_version,
            architecture=Architecture.X64,
            architecture_variant=ContextOsArchitecture.ARCHITECTURE_VARIANT_GENERIC,
        )
        if generator_type is None:
            generators = [Generator.MSVC_17_2022, Generator.MSVC_18_2026]
        elif generator_type == GeneratorType.SINGLE_CONFIG:
            generators = []
        elif generator_type == GeneratorType.MULTI_CONFIG:
            generators = [Generator.MSVC_17_2022, Generator.MSVC_18_2026]
        else:
            generators = []

        for compiler in [Compiler.MSVC, Compiler.MSVC_CLANG]:
            for generator in generators:
                ccg = ContextCompilerGenerator(compiler_family=compiler, build_generator=generator)
                retList.append(
                    ContextOsArchitectureCompilerGenerator(
                        context_os_architecture=windows_x64_generic, context_compiler_generator=ccg
                    )
                )

    return retList


def get_supported_context_os_architecture_list_string(generator_type: GeneratorType | None = None) -> list[str]:
    retlist: list[str] = []
    for ccg in get_supported_context_os_architecture_list(generator_type):
        retlist.append(
            create_context_os_architecture_compiler_generator_string(
                ccg.context_os_architecture, ccg.context_compiler_generator
            )
        )
    return retlist


class BuildConfig(Enum):
    DEBUG = "debug"
    RELEASE = "release"
    PARANOID = "paranoid"
    RELWITHDEBINFO = "relWithDebInfo"


ALLOWED_BUILD_CONFIG_COMBINATIONS: set[FrozenSet[BuildConfig]] = {
    frozenset({BuildConfig.DEBUG}),
    frozenset({BuildConfig.RELEASE}),
    frozenset({BuildConfig.RELWITHDEBINFO}),
    frozenset({BuildConfig.PARANOID}),
    frozenset({BuildConfig.DEBUG, BuildConfig.RELEASE}),
    frozenset({BuildConfig.RELWITHDEBINFO, BuildConfig.DEBUG, BuildConfig.RELEASE, BuildConfig.PARANOID}),
}


def get_supported_combined_workflow_for_multi_config_generators(configs: Iterable[BuildConfig]) -> Expected[str, str]:
    config_set = frozenset(configs)
    if config_set not in ALLOWED_BUILD_CONFIG_COMBINATIONS:
        return Expected[str, str].make_error(f"Unsupported build configs: {config_set}")

    ordered = [
        BuildConfig.DEBUG,
        BuildConfig.RELEASE,
        BuildConfig.RELWITHDEBINFO,
        BuildConfig.PARANOID,
    ]

    return Expected[str, str].make_value("-".join(config.value for config in ordered if config in config_set))


def get_all_supported_workflow_names_list(configs: Iterable[BuildConfig]) -> list[str]:
    workflow_names: list[str] = []
    for supported_build_config in get_supported_context_os_architecture_list_string(GeneratorType.SINGLE_CONFIG):
        for config in configs:
            config_string = config.value
            workflow_name = f"workflow-{supported_build_config}-{config_string}"
            workflow_names.append(workflow_name)

    for supported_build_config in get_supported_context_os_architecture_list_string(GeneratorType.MULTI_CONFIG):
        config_string = get_supported_combined_workflow_for_multi_config_generators(configs).value
        workflow_name = f"workflow-{supported_build_config}-{config_string}"
        workflow_names.append(workflow_name)

    return workflow_names
