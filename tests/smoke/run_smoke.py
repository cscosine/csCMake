#!/usr/bin/env python3
"""Smoke test of csCMake on one preset variant: configure, build, install and test real projects.

Lays out a workspace the way csCMake consumers do (the presets expect ``${sourceParentDir}/csCMake``):

    <workspace>/csCMake            copy of csCMake.cmake, utils/, presets/, templates/
    <workspace>/csSmoke            static lib + app + tests, installed and exported as csSmoke
    <workspace>/csSmokeConsumer    find_package(csSmoke COMPONENTS hellolib) from the install folder
    <workspace>/build, install     created by the presets

then, for the variant, runs the csv1 workflow presets (configure, build, install, ctest) for every build
configuration on both projects, runs the installed ``helloapp`` of each configuration, and lints the
installed ``csSmokeConfig.cmake`` with cmake-lint.

Usage:
    python tests/smoke/run_smoke.py --variant csv1-linux-ubuntu24.04-x64-generic-gcc-default-ninjamulticonfig
    python tests/smoke/run_smoke.py --variant <id> --workspace /tmp/ws --no-lint
"""

from __future__ import annotations

import argparse
import json
import os
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
PRODUCER = "csSmoke"
CONSUMER = "csSmokeConsumer"


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
EXPECTED_APP_OUTPUT = ["hello-lib", "hello-app"]


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
    for name in ("csCMake", PRODUCER, CONSUMER, "build", "install"):
        shutil.rmtree(workspace / name, ignore_errors=True)
    for item in CSCMAKE_CONTENT:
        source = REPO_ROOT / item
        target = workspace / "csCMake" / item
        if source.is_dir():
            shutil.copytree(source, target)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
    for project in (PRODUCER, CONSUMER):
        shutil.copytree(SMOKE_DIR / project, workspace / project)


def install_dir(workspace: Path, variant: str, project: str) -> Path:
    """Install folder of ``project``, as set by csCMakeProjectSetup-base.json."""
    return workspace / "install" / variant / project


def check_installed_apps(workspace: Path, variant: str) -> None:
    """Run the installed helloapp of every configuration and check its output."""
    bin_dir = install_dir(workspace, variant, PRODUCER) / "bin"
    suffix = ".exe" if os.name == "nt" else ""
    for config in CONFIGS:
        app = bin_dir / f"helloapp{config.postfix}{suffix}"
        if not app.is_file():
            raise SmokeError(f"{config.cmake}: installed application not found: {app}")
        result = subprocess.run([str(app)], capture_output=True, text=True, check=False)
        lines = [line.strip() for line in result.stdout.splitlines() if line.strip()]
        print(f"{app.name}: exit code {result.returncode}, output {lines}", flush=True)
        if result.returncode != 0 or lines != EXPECTED_APP_OUTPUT:
            raise SmokeError(
                f"{config.cmake}: {app} printed {lines} (exit code {result.returncode}), expected {EXPECTED_APP_OUTPUT}"
            )


def lint_installed_config(workspace: Path, variant: str) -> None:
    """cmake-lint the installed csSmokeConfig.cmake with the repository configuration.

    C0103 (naming) is not checked: the names in a package config are dictated by CMake
    (``<Package>_FIND_COMPONENTS``, ...) and by the package/export names chosen by the user.
    """
    config_file = install_dir(workspace, variant, PRODUCER) / "lib" / "cmake" / PRODUCER / f"{PRODUCER}Config.cmake"
    if not config_file.is_file():
        raise SmokeError(f"installed config not found: {config_file}")
    lint_config = json.loads((REPO_ROOT / ".cmake-format.json").read_text(encoding="utf-8"))
    lint_config.setdefault("lint", {}).setdefault("disabled_codes", []).append("C0103")
    with tempfile.TemporaryDirectory() as tmp:
        cfg = Path(tmp) / "cmake-format.json"
        cfg.write_text(json.dumps(lint_config), encoding="utf-8")
        # -c last: it takes one or more values and would swallow the input file
        run([sys.executable, "-m", "cmakelang.lint", config_file, "-c", cfg], cwd=workspace)


def run_smoke(variant: str, workspace: Path, lint: bool = True) -> None:
    """Run the whole smoke test for ``variant`` in ``workspace``; raise SmokeError on failure."""
    ctx = find_variant(variant)
    with group(f"prepare workspace {workspace}"):
        prepare_workspace(workspace)
    for project in (PRODUCER, CONSUMER):
        for workflow in workflow_presets(ctx):
            with group(f"{project}: cmake --workflow {workflow}"):
                run(["cmake", "--workflow", workflow], cwd=workspace / project)
        if project == PRODUCER:
            with group("run the installed applications"):
                check_installed_apps(workspace, variant)
            if lint:
                with group(f"cmake-lint installed {PRODUCER}Config.cmake"):
                    lint_installed_config(workspace, variant)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--variant", required=True, help="preset variant id, e.g. csv1-linux-ubuntu24.04-...")
    parser.add_argument("--workspace", type=Path, help="workspace folder (default: a new temporary folder)")
    parser.add_argument("--no-lint", action="store_true", help="skip cmake-lint of the installed config")
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
