#!/usr/bin/env python3
"""Smoke test of csCMake on one preset variant: configure, build, install and test real projects.

Lays out a workspace the way csCMake consumers do (the presets expect ``${sourceParentDir}/csCMake``):

    <workspace>/csCMake            copy of csCMake.cmake, utils/, presets/, templates/
    <workspace>/<project>          every project of PROJECTS (see tests/smoke/README.md)
    <workspace>/build, install     created by the presets

then, for the variant and in the order of PROJECTS (each project finds the previous ones in the install
folder), runs the csv1 workflow presets (configure, build, install, ctest) for every build configuration,
runs the installed applications of each configuration, checks the ``find_dependency`` calls of every installed
``<Package>Config.cmake`` (PUBLIC ``cs_find_package`` propagated, PRIVATE not) and lints it with cmake-lint.

Usage:
    python tests/smoke/run_smoke.py --variant csv1-linux-ubuntu24.04-x64-generic-gcc-default-ninjamulticonfig
    python tests/smoke/run_smoke.py --variant <id> --workspace /tmp/ws --no-lint
"""

from __future__ import annotations

import argparse
import json
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

from cscmake.presets.registry import (
    BuildConfig,
    ContextOsArchitectureCompilerGenerator,
    GeneratorType,
    create_context_os_architecture_compiler_generator_string,
    get_supported_build_configs_for_generator_type,
    get_supported_context_os_architecture_list,
)

REPO_ROOT = Path(__file__).resolve().parents[2]
SMOKE_DIR = Path(__file__).resolve().parent
CSCMAKE_CONTENT = ("csCMake.cmake", "utils", "presets", "templates")


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


# build order: every project finds the ones before it in the install folder (tests/smoke/README.md)
PROJECTS = (
    Project("csSmokeBase"),
    Project("csSmokeMidA", find_dependencies=("csSmokeBase",)),
    Project("csSmokeMidB", find_dependencies=("csSmokeBase",)),
    # csSmokeMidB is found PRIVATE: not propagated to the Config
    Project(
        "csSmokeTop",
        find_dependencies=("csSmokeMidA",),
        apps=(App("csSmokeTop", ("mid-a(text(base-core)) mid-b(base-core)",)),),
    ),
)

# default targets created by cs_initialize_project, installed in the <namespace>_cscmake_common component
DEFAULT_TARGETS = (
    "cscmake_base_include",
    "cscmake_compile_options",
    "cscmake_compile_options_strict",
    "cscmake_msvc_parallel_compile",
    "cscmake_strict_warnings",
)
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


def workflow_presets(ctx: ContextOsArchitectureCompilerGenerator) -> list[str]:
    """Return the workflow presets that build every configuration of ``ctx``."""
    variant = create_context_os_architecture_compiler_generator_string(ctx)
    generator_type = ctx.context_compiler_generator.build_generator.generator_type
    if generator_type == GeneratorType.MULTI_CONFIG:
        # a single build tree, all the configurations in one workflow
        all_configs = BuildConfig.DEBUG_RELEASE_RELWITHDEBINFO_PARANOID
        assert all_configs in get_supported_build_configs_for_generator_type(generator_type)
        return [f"workflow-{variant}-{all_configs.value}"]
    return [f"workflow-{variant}-{config.preset}" for config in CONFIGS]


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


def run(cmd: Sequence[str | Path], cwd: Path) -> None:
    printable = " ".join(str(c) for c in cmd)
    print(f"$ {printable}   (in {cwd})", flush=True)
    result = subprocess.run([str(c) for c in cmd], cwd=cwd, check=False)
    if result.returncode != 0:
        raise SmokeError(f"command failed with exit code {result.returncode}: {printable}")


def prepare_workspace(workspace: Path) -> None:
    """(Re)create the workspace: csCMake and the smoke projects as siblings, no build/install leftovers."""
    workspace.mkdir(parents=True, exist_ok=True)
    for name in ("csCMake", *(project.name for project in PROJECTS), "build", "install"):
        shutil.rmtree(workspace / name, ignore_errors=True)
    for item in CSCMAKE_CONTENT:
        source = REPO_ROOT / item
        target = workspace / "csCMake" / item
        if source.is_dir():
            shutil.copytree(source, target)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
    for project in PROJECTS:
        shutil.copytree(SMOKE_DIR / project.name, workspace / project.name)


def install_dir(workspace: Path, variant: str, project: str) -> Path:
    """Install folder of ``project``, as set by csCMakeProjectSetup-base.json."""
    return workspace / "install" / variant / project


def check_installed_apps(workspace: Path, variant: str, project: Project) -> None:
    """Run the installed applications of ``project`` in every configuration and check their output."""
    bin_dir = install_dir(workspace, variant, project.name) / "bin"
    suffix = ".exe" if os.name == "nt" else ""
    for app_spec in project.apps:
        expected = list(app_spec.output)
        for config in CONFIGS:
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
    config_file = install_dir(workspace, variant, name) / "lib" / "cmake" / name / f"{name}Config.cmake"
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
    targets_file = (
        installed_config(workspace, variant, project).parent / "targets" / f"{project.name}_cscmake_commonTargets.cmake"
    )
    if not targets_file.is_file():
        raise SmokeError(f"installed default targets not found: {targets_file}")
    found = set(_ADD_LIBRARY.findall(targets_file.read_text(encoding="utf-8")))
    expected = {f"{project.name}::{target}" for target in DEFAULT_TARGETS}
    print(f"{targets_file.name}: {sorted(found)}", flush=True)
    if found != expected:
        raise SmokeError(f"{targets_file}: imported targets {sorted(found)}, expected {sorted(expected)}")


def lint_installed_config(workspace: Path, variant: str, project: Project) -> None:
    """cmake-lint the installed ``<project>Config.cmake`` with the repository configuration.

    C0103 (naming) and C0301 (line length) are not checked: the names in a package config are dictated by CMake
    (``<Package>_FIND_COMPONENTS``, ...) and by the package/component names chosen by the user.

    The file is written by CMake with the line endings of the build platform: they only have to be
    consistent (checked here), and an LF copy is linted, because cmakelang 0.6.13 cannot lint CRLF
    files (``line_ending: auto`` crashes, ``windows`` flags the last line).
    """
    config_file = installed_config(workspace, variant, project)
    print(f"{config_file.name}: {line_ending(config_file)} line endings", flush=True)
    lint_config = json.loads((REPO_ROOT / ".cmake-format.json").read_text(encoding="utf-8"))
    lint_config.setdefault("lint", {}).setdefault("disabled_codes", []).extend(["C0103", "C0301"])
    with tempfile.TemporaryDirectory() as tmp:
        cfg = Path(tmp) / "cmake-format.json"
        cfg.write_text(json.dumps(lint_config), encoding="utf-8")
        lf_copy = Path(tmp) / config_file.name
        lf_copy.write_bytes(config_file.read_bytes().replace(b"\r\n", b"\n"))
        print(f"linting an LF copy of {config_file}", flush=True)
        # -c last: it takes one or more values and would swallow the input file
        run([sys.executable, "-m", "cmakelang.lint", lf_copy, "-c", cfg], cwd=workspace)


def run_smoke(variant: str, workspace: Path, lint: bool = True) -> None:
    """Run the whole smoke test for ``variant`` in ``workspace``; raise SmokeError on failure."""
    ctx = find_variant(variant)
    with group(f"prepare workspace {workspace}"):
        prepare_workspace(workspace)
    for project in PROJECTS:
        for workflow in workflow_presets(ctx):
            with group(f"{project.name}: cmake --workflow {workflow}"):
                run(["cmake", "--workflow", workflow], cwd=workspace / project.name)
        with group(f"{project.name}: find_dependency in the installed {project.name}Config.cmake"):
            check_installed_config_dependencies(workspace, variant, project)
            check_installed_default_targets(workspace, variant, project)
        if project.apps:
            with group(f"{project.name}: run the installed applications"):
                check_installed_apps(workspace, variant, project)
        if lint:
            with group(f"{project.name}: cmake-lint installed {project.name}Config.cmake"):
                lint_installed_config(workspace, variant, project)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--variant", required=True, help="preset variant id, e.g. csv1-linux-ubuntu24.04-...")
    parser.add_argument("--workspace", type=Path, help="workspace folder (default: a new temporary folder)")
    parser.add_argument("--no-lint", action="store_true", help="skip cmake-lint of the installed configs")
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
