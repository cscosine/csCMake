from dataclasses import dataclass

from csorchestrator.context.context_compiler_generator import (
    Compiler,
    ContextCompilerGenerator,
    Generator,
    GeneratorType,
)
from csorchestrator.context.context_os_architecture import OS, Architecture, ContextOsArchitecture
from csorchestrator.context.context_os_architecture_compiler_generator import (
    create_context_os_architecture_compiler_generator_string,
)


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
