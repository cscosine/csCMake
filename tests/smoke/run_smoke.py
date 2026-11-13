#!/usr/bin/env python3
"""Smoke test of csCMake on one preset variant: configure, build, install and test real projects.

Lays out a workspace the way csCMake consumers do (the presets expect ``${sourceParentDir}/csCMake``):

    <workspace>/csCMake            the content of the release package (PACKAGE_CONTENT of cscmake-release)
    <workspace>/<project>          every project of PROJECTS (see tests/smoke/README.md)
    <workspace>/build, install     created by the presets

then, for the variant and in the order of PROJECTS (each project finds the previous ones in the install
folder), runs the csv1 workflow presets (configure, build, install, ctest) for every build configuration,
runs the installed applications of each configuration, checks the ``find_dependency`` calls of every installed
``<Package>Config.cmake`` (PUBLIC ``cs_find_package`` propagated, PRIVATE not) and lints it with cscmake-lint.
Then it moves the install folder (relocation): the installed applications run from there, and two consumers are built
again against it. Last, it checks the deployments (cs_deployment) the installs made: their files and, on Linux, their
applications run with an empty environment (the install folder moved away: nothing found from there).

Usage:
    python tests/smoke/run_smoke.py --variant csv1-linux-ubuntu24.04-x64-generic-gcc-default-ninjamulticonfig
    python tests/smoke/run_smoke.py --variant <id> --workspace /tmp/ws --no-lint
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
from collections.abc import Iterator, Sequence
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path
from xml.etree import ElementTree

from cscmake.devtools.release import PACKAGE_CONTENT
from cscmake.presets.registry import (
    BuildConfig,
    ContextOsArchitectureCompilerGenerator,
    Generator,
    GeneratorType,
    create_context_os_architecture_compiler_generator_string,
    get_supported_build_configs_for_generator_type,
    get_supported_context_os_architecture_list,
)

REPO_ROOT = Path(__file__).resolve().parents[2]
SMOKE_DIR = Path(__file__).resolve().parent


@dataclass(frozen=True)
class Config:
    preset: str  # name used by the presets (debug, relWithDebInfo, ...)
    cmake: str  # CMake configuration name (Debug, RelWithDebInfo, ...)
    postfix: str  # artifact postfix set by cs_initialize_project in the smoke projects


# the build configurations of the csv1 presets, with the postfixes of the smoke projects
CONFIGS = (
    Config(BuildConfig.DEBUG.value, "Debug", "d"),
    Config(BuildConfig.RELEASE.value, "Release", ""),
    Config(BuildConfig.RELWITHDEBINFO.value, "RelWithDebInfo", "rd"),
    Config(BuildConfig.PARANOID.value, "Paranoid", "dp"),
)


@dataclass(frozen=True)
class App:
    name: str  # installed executable, without postfix and suffix
    output: tuple[str, ...]  # expected non-empty stdout lines


@dataclass(frozen=True)
class Project:
    name: str  # folder name = package name = export namespace (find_package searches <prefix>/<name>*/...)
    find_dependencies: tuple[str, ...] = ()  # exactly the packages of find_dependency() in its installed Config
    apps: tuple[App, ...] = ()  # installed applications to run
    standalone: bool = False  # standalone layout: its own workspace, <project>/workspace (csCMake copied there)
    # a consumer without csCMake: plain CMake, Debug and Release only (the configurations CMake knows), no installed
    # package to check
    plain: bool = False
    debug_release: bool = False  # its configurations are Debug and Release only (always for a plain project)

    @property
    def configs(self) -> tuple[Config, ...]:
        """The configurations the project builds."""
        return CONFIGS[:2] if self.plain or self.debug_release else CONFIGS


# build order: every project finds the ones before it in the install folder (tests/smoke/README.md)
PROJECTS = (
    # the example of the getting started page (docs/user/getting-started.md) and of README.md
    Project("myApp", apps=(App("myApp", ("Hello from myApp",)),), debug_release=True),
    Project("csSmokeBase"),
    Project("csSmokeMidA", find_dependencies=("csSmokeBase",)),
    Project("csSmokeMidB", find_dependencies=("csSmokeBase",)),
    # csSmokeMidB is found PRIVATE: not propagated to the Config
    Project(
        "csSmokeTop",
        find_dependencies=("csSmokeMidA",),
        apps=(App("csSmokeTop", ("mid-a(text(base-core)) mid-b(base-core)",)),),
    ),
    # env layout: workspace and csCMake from CSCMAKE_WORKSPACE_ROOT / CSCMAKE_ROOT (cmake_environment)
    Project(
        "csSmokeEnv",
        find_dependencies=("csSmokeBase",),
        apps=(App("csSmokeEnvApp", ("env(text(base-core))",)),),
    ),
    Project("csSmokeStandalone", apps=(App("csSmokeStandaloneApp", ("standalone",)),), standalone=True),
    # shared libraries: the installed application runs from the install folder
    Project("csSmokeShared", apps=(App("csSmokeSharedApp", ("shared-text(shared-core)",)),)),
    # plain CMake consumer of csSmokeShared (its ctest checks the output)
    Project("csSmokePlainConsumer", plain=True),
    # deployments: its own shared library and the ones of csSmokeShared shipped with the applications (DEPLOYMENTS)
    Project("csSmokeDeploy"),
)


@dataclass(frozen=True)
class Deployment:
    project: str
    name: str  # cs_deployment(<name> ...): made in <build folder>/deploy/<name>-<config>
    configs: tuple[str, ...]  # the CMake configurations it is made in (none in the others)
    app: App  # the deployed application (in bin/)
    files: tuple[str, ...] = ()  # other files of the deployment, relative to its folder
    libraries: tuple[str, ...] = ()  # Linux: the shared libraries shipped (path prefixes, e.g. lib/libsharedCore)
    not_installed: tuple[str, ...] = ()  # names (glob) deployed but not in the install folder of the project


# the shared libraries of the deployments of csSmokeDeploy: its own, and the ones of csSmokeShared (another package)
SMOKE_DEPLOY_LIBRARIES = ("lib/libdeployCore", "lib/libsharedText", "lib/libsharedCore")
# the deployments of the smoke projects, made by the install step of the workflow presets
DEPLOYMENTS = (
    # the one of the quick start: the application alone (static libraries)
    Deployment("myApp", "app", ("Release",), App("myApp", ("Hello from myApp",))),
    Deployment(
        "csSmokeDeploy",
        "app",
        ("Release",),
        App("csSmokeDeployApp", ("deploy(shared-text(shared-core))",)),
        ("share/csSmokeDeploy/readme.txt",),
        SMOKE_DEPLOY_LIBRARIES,
        ("readme.txt",),
    ),
    Deployment(
        "csSmokeDeploy",
        "sample",
        ("Release", "RelWithDebInfo"),
        App("csSmokeDeploySample", ("sample deploy(shared-text(shared-core))",)),
        libraries=SMOKE_DEPLOY_LIBRARIES,
        not_installed=("csSmokeDeploySample*",),
    ),
)
# never in a deployment: headers, static and import libraries, CMake package files, PDB files
NOT_DEPLOYED_SUFFIXES = (".h", ".hpp", ".a", ".lib", ".cmake", ".pdb")

VISUAL_STUDIO = (Generator.MSVC_17_2022, Generator.MSVC_18_2026)

# relocation: the install folder is moved after every project is built; the installed applications run from there, and
# these consumers are built again against it (a csCMake one: find_dependency chain csSmokeTop -> csSmokeMidA ->
# csSmokeBase; a plain CMake one: the DLLs of csSmokeShared copied from there on Windows)
RELOCATED_INSTALL = "install-relocated"
RELOCATION_CONSUMERS = ("csSmokeTop", "csSmokePlainConsumer")

# default targets created by cs_initialize_project, installed in the cscmake_common component
DEFAULT_TARGETS = ("cscmake_base_include",)
_ADD_LIBRARY = re.compile(r"^add_library\(\s*([^\s)]+)", re.MULTILINE)
_FIND_DEPENDENCY = re.compile(r"^\s*find_dependency\(\s*([^\s)]+)", re.MULTILINE)


class SmokeError(RuntimeError):
    """A smoke check failed."""


def find_variant(variant: str) -> ContextOsArchitectureCompilerGenerator:
    """Return the registry context whose canonical id is ``variant``."""
    for ctx in get_supported_context_os_architecture_list():
        if create_context_os_architecture_compiler_generator_string(ctx) == variant:
            return ctx
    raise SmokeError(f"unknown variant {variant!r} (not in the csCMake preset registry)")


def workflow_presets(ctx: ContextOsArchitectureCompilerGenerator, debug_release: bool = False) -> list[str]:
    """Return the workflow presets that build every configuration of ``ctx`` (Debug and Release only with
    ``debug_release``)."""
    variant = create_context_os_architecture_compiler_generator_string(ctx)
    generator_type = ctx.context_compiler_generator.build_generator.generator_type
    configs = CONFIGS[:2] if debug_release else CONFIGS
    if generator_type == GeneratorType.MULTI_CONFIG:
        # a single build tree, all the configurations in one workflow
        all_configs = BuildConfig.DEBUG_RELEASE if debug_release else BuildConfig.DEBUG_RELEASE_RELWITHDEBINFO_PARANOID
        assert all_configs in get_supported_build_configs_for_generator_type(generator_type)
        return [f"workflow-{variant}-{all_configs.value}"]
    return [f"workflow-{variant}-{config.preset}" for config in configs]


@contextmanager
def group(title: str) -> Iterator[None]:
    """Collapsible log group on GitHub Actions, a plain header elsewhere."""
    on_github = os.environ.get("GITHUB_ACTIONS") == "true"
    print(f"::group::{title}" if on_github else f"\n=== {title}", flush=True)
    try:
        yield
    finally:
        if on_github:
            print("::endgroup::", flush=True)


def cmake_environment(workspace: Path) -> dict[str, str]:
    """Process environment of the cmake calls: the workspace and csCMake for the projects using the env layout."""
    return {
        **os.environ,
        "CSCMAKE_WORKSPACE_ROOT": workspace.as_posix(),
        "CSCMAKE_ROOT": (workspace / "csCMake").as_posix(),
    }


def run(cmd: Sequence[str | Path], cwd: Path, env: dict[str, str] | None = None) -> None:
    printable = " ".join(str(c) for c in cmd)
    print(f"$ {printable}   (in {cwd})", flush=True)
    result = subprocess.run([str(c) for c in cmd], cwd=cwd, env=env, check=False)
    if result.returncode != 0:
        raise SmokeError(f"command failed with exit code {result.returncode}: {printable}")


def prepare_workspace(workspace: Path) -> None:
    """(Re)create the workspace: csCMake and the smoke projects as siblings, no build/install leftovers."""
    workspace.mkdir(parents=True, exist_ok=True)
    for name in ("csCMake", *(project.name for project in PROJECTS), "build", "install", "deploy", RELOCATED_INSTALL):
        shutil.rmtree(workspace / name, ignore_errors=True)
    copy_cscmake(workspace / "csCMake")
    for project in PROJECTS:
        shutil.copytree(SMOKE_DIR / project.name, workspace / project.name)
        if project.standalone:
            copy_cscmake(workspace / project.name / "workspace" / "csCMake")


def copy_cscmake(target_dir: Path) -> None:
    """Copy into ``target_dir`` what the release package contains (``PACKAGE_CONTENT``): the projects build against
    the files of a release, laid out as in the package."""
    for item in PACKAGE_CONTENT:
        source = REPO_ROOT / item
        target = target_dir / item
        if source.is_dir():
            shutil.copytree(source, target)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)


def install_dir(workspace: Path, variant: str, project: Project) -> Path:
    """Install folder of ``project``: install/<variant>/<project> of its workspace (csCMakeProjectSetup.json)."""
    project_workspace = workspace / project.name / "workspace" if project.standalone else workspace
    return project_workspace / "install" / variant / project.name


def check_installed_apps(project_install_dir: Path, project: Project) -> None:
    """Run the installed applications of ``project`` (installed in ``project_install_dir``) in every configuration and
    check their output."""
    bin_dir = project_install_dir / "bin"
    suffix = ".exe" if os.name == "nt" else ""
    for app_spec in project.apps:
        expected = list(app_spec.output)
        for config in project.configs:
            app = bin_dir / f"{app_spec.name}{config.postfix}{suffix}"
            if not app.is_file():
                raise SmokeError(f"{config.cmake}: installed application not found: {app}")
            result = subprocess.run([str(app)], capture_output=True, text=True, check=False)
            lines = [line.strip() for line in result.stdout.splitlines() if line.strip()]
            print(f"{app.name}: exit code {result.returncode}, output {lines}", flush=True)
            if result.returncode != 0 or lines != expected:
                raise SmokeError(
                    f"{config.cmake}: {app} printed {lines} (exit code {result.returncode}), expected {expected}"
                )


def relocate_install(workspace: Path) -> Path:
    """Move ``<workspace>/install`` to ``<workspace>/install-relocated`` and return it; fail if an installed CMake file
    names the folder it was installed in (an absolute path: the package could not be moved)."""
    source, target = workspace / "install", workspace / RELOCATED_INSTALL
    shutil.rmtree(target, ignore_errors=True)
    shutil.move(source, target)
    old = source.as_posix().lower()
    for path in sorted(target.rglob("*.cmake")):
        if old in path.read_text(encoding="utf-8", errors="replace").replace("\\", "/").lower():
            raise SmokeError(f"{path} names the folder the package was installed in, {source}: it cannot be moved")
    print(f"moved {source} to {target}: no installed CMake file names {source}", flush=True)
    return target


def relocated_prefixes(relocated: Path) -> list[Path]:
    """The install prefix of every package in the relocated install folder (``<prefix>/lib/cmake/<Package>``)."""
    return sorted({config.parents[3] for config in relocated.rglob("lib/cmake/*/*Config.cmake")})


def rebuild_against_relocated_install(
    ctx: ContextOsArchitectureCompilerGenerator, workspace: Path, relocated: Path
) -> None:
    """Build RELOCATION_CONSUMERS again from new build folders, finding the packages they use in the relocated install
    folder only (the ``CMAKE_PREFIX_PATH`` environment variable: searched by find_package, csCMake or not)."""
    prefixes = relocated_prefixes(relocated)
    env = {**cmake_environment(workspace), "CMAKE_PREFIX_PATH": os.pathsep.join(p.as_posix() for p in prefixes)}
    print(f"CMAKE_PREFIX_PATH (environment): {env['CMAKE_PREFIX_PATH']}", flush=True)
    for name in RELOCATION_CONSUMERS:
        project = next(p for p in PROJECTS if p.name == name)
        # build/<variant>/<project>[/<config>]: the build folders of every configuration
        for build_dir in [
            d for d in (workspace / "build").rglob(name) if d.is_dir() and any(d.rglob("CMakeCache.txt"))
        ]:
            shutil.rmtree(build_dir)
        for workflow in workflow_presets(ctx, project.plain or project.debug_release):
            run(["cmake", "--workflow", workflow], cwd=workspace / name, env=env)


_DEBUGGER_CONFIG = re.compile(r"==\s*'([^|']+)\|")


def debugger_environments(vcxproj: Path) -> dict[str, str]:
    """Return the ``LocalDebuggerEnvironment`` of each configuration of a Visual Studio project file."""
    environments: dict[str, str] = {}
    for group_element in ElementTree.parse(vcxproj).getroot().iter():
        for child in group_element:
            if not child.tag.endswith("LocalDebuggerEnvironment"):
                continue
            condition = child.get("Condition") or group_element.get("Condition") or ""
            if match := _DEBUGGER_CONFIG.search(condition):
                environments[match.group(1)] = child.text or ""
    return environments


def check_debugger_environment(workspace: Path, variant: str) -> None:
    """Visual Studio: the debugger environment of csSmokeSharedApp (cs_target_runtime_environment), for each
    configuration: the line CSSMOKE_CONFIG=<config>, then a PATH line with its runtime/<config> folder first, then the
    folder of the DLLs it links (bin/<config> of the build), then %PATH%."""
    projects = sorted((workspace / "build").rglob("csSmokeSharedApp.vcxproj"))
    if not projects:
        raise SmokeError(f"csSmokeSharedApp.vcxproj not found in {workspace / 'build'}")
    environments = debugger_environments(projects[0])
    print(f"{projects[0].name}: LocalDebuggerEnvironment {environments}", flush=True)
    for config in CONFIGS:
        lines = [line.strip() for line in environments.get(config.cmake, "").splitlines() if line.strip()]
        variable = f"CSSMOKE_CONFIG={config.cmake}"
        if len(lines) != 2 or lines[0] != variable:
            raise SmokeError(f"{config.cmake}: debugger environment {lines}, expected {variable} then a PATH line")
        path = lines[1].replace("\\", "/").lower()
        runtime, dlls = f"/runtime/{config.cmake}".lower(), f"/bin/{config.cmake}".lower()
        if not (path.startswith("path=") and runtime in path and dlls in path and path.endswith(";%path%")):
            raise SmokeError(f"{config.cmake}: debugger {path!r}, expected PATH=...{runtime};...{dlls};%PATH%")
        if path.index(runtime) > path.index(dlls):
            raise SmokeError(f"{config.cmake}: {runtime} must come before {dlls} in {path!r}")


_ENV_CONFIGS = re.compile(r'^set "_cs_env_configs=(.*)"\s*$', re.MULTILINE)
_ENV_REPORT = re.compile(r"^(CSSMOKE_CONFIG|PATH)=(.*?)\s*$", re.MULTILINE)
# run a run-time environment script, then print what it set; the arguments of the wrapper go to the script
_ENV_WRAPPERS = {
    "cs-env.bat": (
        '@echo off\ncall "{script}" %*\nif errorlevel 1 exit /b 1\n'
        "echo CSSMOKE_CONFIG=%CSSMOKE_CONFIG%\necho PATH=%PATH%\n"
    ),
    "cs-env.ps1": (
        "$ErrorActionPreference = 'Stop'\n& '{script}' @args\n"
        '"CSSMOKE_CONFIG=$env:CSSMOKE_CONFIG"\n"PATH=$env:PATH"\n'
    ),
}


def run_environment_script(script: Path, args: Sequence[str]) -> subprocess.CompletedProcess[str]:
    """Run ``script`` (cs-env.bat or cs-env.ps1) with ``args`` through a wrapper that prints CSSMOKE_CONFIG and PATH
    afterwards (a wrapper, not a command line: cs-env.bat takes a command line naming it for a double-click)."""
    wrapper = script.parent / f"smoke-{script.name}"
    wrapper.write_text(_ENV_WRAPPERS[script.name].format(script=script), encoding="utf-8")
    if script.suffix == ".bat":
        command = ["cmd", "/d", "/c", str(wrapper), *args]
    else:
        command = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(wrapper), *args]
    try:
        return subprocess.run(command, capture_output=True, text=True, check=False)
    finally:
        wrapper.unlink()


def check_environment_script_output(script: Path, config: str, output: str) -> None:
    """The variable of csSmokeSharedApp for ``config``, then PATH: its runtime/<config> folder, then the folder of the
    DLLs of the build (bin, bin/<config> with a multi-config generator), then the PATH before."""
    values = dict(_ENV_REPORT.findall(output))
    if values.get("CSSMOKE_CONFIG") != config:
        raise SmokeError(f"{script.name} {config}: CSSMOKE_CONFIG={values.get('CSSMOKE_CONFIG')!r}, expected {config}")
    entries = [entry.replace("\\", "/").lower().rstrip("/") for entry in values.get("PATH", "").split(";")]
    runtime, bin_dir = f"/runtime/{config}".lower(), (script.parent / "bin").as_posix().lower()
    if len(entries) < 3 or not entries[0].endswith(runtime) or not entries[1].startswith(bin_dir):
        raise SmokeError(f"{script.name} {config}: PATH {entries[:3]}..., expected ...{runtime};{bin_dir}...;%PATH%")


def check_environment_scripts(workspace: Path, variant: str) -> None:
    """Windows: the run-time environment scripts of every build folder of csSmokeShared (one with a multi-config
    generator, ``<project>/<config>`` each with a single-config one)."""
    scripts = sorted(path for path in (workspace / "build").rglob("cs-env.bat") if "csSmokeShared" in path.parts)
    if not scripts:
        raise SmokeError(f"no cs-env.bat in the build folders of csSmokeShared in {workspace / 'build'}")
    for script in scripts:
        check_environment_scripts_of(script.parent)


def check_environment_scripts_of(build_dir: Path) -> None:
    """cs-env.bat and cs-env.ps1 of ``build_dir``, for each configuration they list; without a configuration: the only
    one, or an error (the configurations give different environments: CSSMOKE_CONFIG=$<CONFIG>)."""
    match = _ENV_CONFIGS.search((build_dir / "cs-env.bat").read_text(encoding="utf-8"))
    configs = match.group(1).split() if match else []
    print(f"{build_dir}: configurations {configs}", flush=True)
    for name in _ENV_WRAPPERS:
        script = build_dir / name
        for config in configs:
            result = run_environment_script(script, [config])
            if result.returncode != 0:
                raise SmokeError(f"{name} {config}: exit code {result.returncode}\n{result.stdout}{result.stderr}")
            check_environment_script_output(script, config, result.stdout)
        result = run_environment_script(script, [])
        print(f"{name} without configuration: exit code {result.returncode} {result.stderr.strip()}", flush=True)
        if len(configs) == 1:
            if result.returncode != 0:
                raise SmokeError(f"{name}: exit code {result.returncode}\n{result.stdout}{result.stderr}")
            check_environment_script_output(script, configs[0], result.stdout)
        elif result.returncode == 0 or "give one" not in result.stderr:
            raise SmokeError(f"{name} without configuration: expected an error, got {result.returncode}")


def line_ending(path: Path) -> str:
    """Return the line ending of ``path`` ("unix" or "windows"); fail on mixed line endings."""
    data = path.read_bytes()
    crlf = data.count(b"\r\n")
    lf_only = data.count(b"\n") - crlf
    if crlf and lf_only:
        raise SmokeError(f"mixed line endings in {path}: {crlf} CRLF and {lf_only} LF")
    return "windows" if crlf else "unix"


def installed_config(workspace: Path, variant: str, project: Project) -> Path:
    """Return the installed ``<project>Config.cmake``; fail if it is missing."""
    name = project.name
    config_file = install_dir(workspace, variant, project) / "lib" / "cmake" / name / f"{name}Config.cmake"
    if not config_file.is_file():
        raise SmokeError(f"installed config not found: {config_file}")
    return config_file


def config_find_dependencies(text: str) -> set[str]:
    """Return the packages of the ``find_dependency(<package> ...)`` calls in a Config text."""
    return set(_FIND_DEPENDENCY.findall(text))


def check_installed_config_dependencies(workspace: Path, variant: str, project: Project) -> None:
    """The installed Config propagates exactly the PUBLIC ``cs_find_package`` of the project (PRIVATE ones not)."""
    config_file = installed_config(workspace, variant, project)
    found = config_find_dependencies(config_file.read_text(encoding="utf-8"))
    print(f"{config_file.name}: find_dependency {sorted(found)}", flush=True)
    if found != set(project.find_dependencies):
        raise SmokeError(
            f"{config_file}: find_dependency of {sorted(found)}, expected {sorted(project.find_dependencies)}"
        )


def check_installed_default_targets(workspace: Path, variant: str, project: Project) -> None:
    """The default targets are installed as ``<namespace>::cscmake_*``: the same names used in the build tree."""
    targets_file = installed_config(workspace, variant, project).parent / "targets" / "cscmake_commonTargets.cmake"
    if not targets_file.is_file():
        raise SmokeError(f"installed default targets not found: {targets_file}")
    found = set(_ADD_LIBRARY.findall(targets_file.read_text(encoding="utf-8")))
    expected = {f"{project.name}::{target}" for target in DEFAULT_TARGETS}
    print(f"{targets_file.name}: {sorted(found)}", flush=True)
    if found != expected:
        raise SmokeError(f"{targets_file}: imported targets {sorted(found)}, expected {sorted(expected)}")


def lint_installed_config(workspace: Path, variant: str, project: Project) -> None:
    """cscmake-lint the installed ``<project>Config.cmake`` (comments, complexity).

    The naming rules and the line length are not checked: the names in a package config are dictated by CMake
    (``<Package>_FIND_COMPONENTS``, ...) and by the package and component names chosen by the user. The file is written
    with the line endings of the build platform: they only have to be consistent (checked here).
    """
    config_file = installed_config(workspace, variant, project)
    print(f"{config_file.name}: {line_ending(config_file)} line endings", flush=True)
    run(
        [sys.executable, "-m", "cscmake.devtools.cmake_lint", "--disable", "CS101,CS102,CS103,CS108", config_file],
        cwd=workspace,
    )


def run_smoke(variant: str, workspace: Path, lint: bool = True) -> None:
    """Run the whole smoke test for ``variant`` in ``workspace``; raise SmokeError on failure."""
    ctx = find_variant(variant)
    with group(f"prepare workspace {workspace}"):
        prepare_workspace(workspace)
    for project in PROJECTS:
        for workflow in workflow_presets(ctx, project.plain or project.debug_release):
            with group(f"{project.name}: cmake --workflow {workflow}"):
                run(["cmake", "--workflow", workflow], cwd=workspace / project.name, env=cmake_environment(workspace))
        if project.plain:
            continue
        with group(f"{project.name}: find_dependency in the installed {project.name}Config.cmake"):
            check_installed_config_dependencies(workspace, variant, project)
            check_installed_default_targets(workspace, variant, project)
        if project.apps:
            with group(f"{project.name}: run the installed applications"):
                check_installed_apps(install_dir(workspace, variant, project), project)
        if (
            project.name == "csSmokeShared"
            and ctx.context_compiler_generator.build_generator.generator in VISUAL_STUDIO
        ):
            with group(f"{project.name}: Visual Studio debugger environment"):
                check_debugger_environment(workspace, variant)
        if project.name == "csSmokeShared" and os.name == "nt":
            with group(f"{project.name}: run-time environment scripts"):
                check_environment_scripts(workspace, variant)
        if lint:
            with group(f"{project.name}: cscmake-lint installed {project.name}Config.cmake"):
                lint_installed_config(workspace, variant, project)
    check_relocation(ctx, variant, workspace)
    with group("deployments: their folders, their applications run with an empty environment"):
        check_deployments(workspace, variant)


def deployment_folder(workspace: Path, variant: str, deployment: Deployment, config: str) -> Path:
    """The folder of ``deployment`` in ``config``: ``deploy/<variant>/<project>/<name>-<config>`` of the workspace
    (CSCMAKE_DEPLOY_DIR of the project setup presets, next to ``install/<variant>/<project>``)."""
    return workspace / "deploy" / variant / deployment.project / f"{deployment.name}-{config}"


def check_deployment_files(folder: Path, deployment: Deployment, config: Config) -> None:
    """The application and the files of the deployment are in ``folder``, nothing that is not run time; on Linux, the
    shared libraries it ships too, and system-requirements.txt (libc among them)."""
    suffix = ".exe" if os.name == "nt" else ""
    files = {path.relative_to(folder).as_posix() for path in folder.rglob("*") if path.is_file()}
    print(f"{folder}: {sorted(files)}", flush=True)
    expected = {f"bin/{deployment.app.name}{config.postfix}{suffix}", *deployment.files}
    if sys.platform == "linux":
        libraries = [name for name in files if name.startswith("lib/")]
        for prefix in deployment.libraries:
            if not any(name.startswith(prefix) for name in libraries):
                raise SmokeError(f"{folder}: no {prefix}* in the shared libraries {sorted(libraries)}")
        report = folder / "system-requirements.txt"
        if not report.is_file() or "libc.so.6 " not in report.read_text(encoding="utf-8"):
            raise SmokeError(f"{report}: missing, or without libc.so.6")
    if missing := expected - files:
        raise SmokeError(f"{folder}: missing {sorted(missing)}")
    if unexpected := sorted(name for name in files if name.endswith(NOT_DEPLOYED_SUFFIXES)):
        raise SmokeError(f"{folder}: not run time, never deployed: {unexpected}")


def run_deployed_app(folder: Path, deployment: Deployment, config: Config) -> None:
    """Run the application of the deployment with an empty environment and check its output."""
    app = folder / "bin" / f"{deployment.app.name}{config.postfix}"
    result = subprocess.run([str(app)], capture_output=True, text=True, env={}, check=False)
    lines = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    print(f"{app}: exit code {result.returncode}, output {lines}", flush=True)
    if result.returncode != 0 or lines != list(deployment.app.output):
        raise SmokeError(
            f"{app} printed {lines} (exit code {result.returncode}), expected {list(deployment.app.output)}\n"
            f"{result.stderr}"
        )


def check_deployments(workspace: Path, variant: str) -> None:
    """Each deployment of DEPLOYMENTS: in the deploy/ folder of the workspace, one folder per configuration it lists,
    none in the others, none in the build folders; its files; on Linux, its application runs from it with an empty
    environment. Nothing of a deployment in the install folders (a sample: not installed)."""
    if in_build := sorted(path for path in (workspace / "build").rglob("deploy") if path.is_dir()):
        raise SmokeError(f"deployments in the build folders, expected in {workspace / 'deploy'}: {in_build}")
    for deployment in DEPLOYMENTS:
        project = next(p for p in PROJECTS if p.name == deployment.project)
        for config in project.configs:
            folder = deployment_folder(workspace, variant, deployment, config.cmake)
            if config.cmake not in deployment.configs:
                if folder.exists():
                    raise SmokeError(f"{deployment.name} is not made in {config.cmake}: {folder}")
                continue
            if not folder.is_dir():
                raise SmokeError(f"{deployment.name} {config.cmake}: {folder} not found")
            check_deployment_files(folder, deployment, config)
            if sys.platform == "linux":
                run_deployed_app(folder, deployment, config)
            else:
                print(f"{deployment.name} {config.cmake}: not run (other packages shipped on Linux only)", flush=True)
        installed = workspace / RELOCATED_INSTALL / variant / deployment.project
        if found := [path for pattern in deployment.not_installed for path in installed.rglob(pattern)]:
            raise SmokeError(f"{installed}: deployed, not installed: {found}")


def check_relocation(ctx: ContextOsArchitectureCompilerGenerator, variant: str, workspace: Path) -> None:
    """The installed packages can be moved: no installed CMake file names the install folder, the installed
    applications run from the new folder (install RPATH relative to the binary; DLLs in bin/), and consumers build
    against it (relative paths in the Config files)."""
    with group(f"relocation: move {workspace / 'install'}"):
        relocated = relocate_install(workspace)
    with group("relocation: run the installed applications from the moved folder"):
        for project in PROJECTS:
            if project.apps and not project.standalone:
                moved = relocated / install_dir(workspace, variant, project).relative_to(workspace / "install")
                check_installed_apps(moved, project)
    with group(f"relocation: build {', '.join(RELOCATION_CONSUMERS)} against the moved folder"):
        rebuild_against_relocated_install(ctx, workspace, relocated)
    with group("relocation: run the applications of the consumers built against the moved folder"):
        for project in PROJECTS:
            if project.name in RELOCATION_CONSUMERS and project.apps:
                check_installed_apps(install_dir(workspace, variant, project), project)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--variant", required=True, help="preset variant id, e.g. csv1-linux-ubuntu24.04-...")
    parser.add_argument("--workspace", type=Path, help="workspace folder (default: a new temporary folder)")
    parser.add_argument("--no-lint", action="store_true", help="skip cscmake-lint of the installed configs")
    args = parser.parse_args(argv)

    workspace = args.workspace or Path(tempfile.mkdtemp(prefix="cscmake-smoke-"))
    try:
        run_smoke(args.variant, workspace.resolve(), lint=not args.no_lint)
    except SmokeError as exc:
        print(f"SMOKE FAILED [{args.variant}]: {exc}", file=sys.stderr, flush=True)
        return 1
    print(f"SMOKE OK [{args.variant}] (workspace {workspace})", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
