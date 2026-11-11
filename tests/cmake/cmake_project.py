"""Configure-only CMake tests of csCMake: write a small project, configure it, read what it reports.

The project includes csCMake from this checkout (``CMAKE_MODULE_PATH``), uses ``LANGUAGES NONE`` (no compiler
needed) and reports values with ``cstest_report(<key> <value>)``, printed as ``-- CSTEST <key>=<value>``.
"""

from __future__ import annotations

import re
import subprocess
from dataclasses import dataclass
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]

HEADER = """cmake_minimum_required(VERSION 3.31)
project(cstest VERSION 1.0.0 LANGUAGES NONE)
include(csCMake)
function(cstest_report key value)
  message(STATUS "CSTEST ${key}=${value}")
endfunction()
"""

_REPORT = re.compile(r"^-- CSTEST ([^=]+)=(.*)$", re.MULTILINE)


@dataclass(frozen=True)
class Configured:
    returncode: int
    output: str  # stdout + stderr

    @property
    def reports(self) -> dict[str, str]:
        """The ``cstest_report`` values, by key."""
        return dict(_REPORT.findall(self.output))

    def report_list(self, key: str) -> list[str]:
        """A reported CMake list, as a Python list."""
        value = self.reports[key]
        return value.split(";") if value else []


def after_finalize(code: str) -> str:
    """CMake ``code`` run after csCMake finalized the project: deferred to the end of the CMakeLists.txt, after the
    finalization (deferred before it, by ``cs_initialize_project``); evaluated once, then, in the folder's scope."""
    return f"cmake_language(DEFER CALL cmake_language EVAL CODE [==[\n{code}]==])\n"


def configure(
    project_dir: Path,
    body: str,
    files: dict[str, str] | None = None,
    args: list[str] | None = None,
    timeout: float | None = None,
) -> Configured:
    """Write ``HEADER + body`` as ``project_dir/CMakeLists.txt`` (plus ``files``), configure it with Ninja/Debug.

    ``args`` are extra ``cmake`` arguments (e.g. ``-D<var>=<value>``); ``timeout`` (seconds) fails a configure that
    takes longer (``subprocess.TimeoutExpired``)."""
    project_dir.mkdir(parents=True, exist_ok=True)
    (project_dir / "CMakeLists.txt").write_text(HEADER + body, encoding="utf-8")
    for name, content in (files or {}).items():
        path = project_dir / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
    result = subprocess.run(
        [
            "cmake",
            "-S",
            str(project_dir),
            "-B",
            str(project_dir / "build"),
            "-G",
            "Ninja",
            "-DCMAKE_BUILD_TYPE=Debug",
            f"-DCMAKE_MODULE_PATH={REPO_ROOT.as_posix()}",
            *(args or []),
        ],
        capture_output=True,
        text=True,
        check=False,
        timeout=timeout,
    )
    return Configured(result.returncode, result.stdout + result.stderr)


def install(project_dir: Path, body: str, prefix: Path, files: dict[str, str] | None = None) -> Configured:
    """Configure ``HEADER + body`` (``files`` too), build and install it into ``prefix``; return the first failure."""
    configured = configure(project_dir, body, files, args=[f"-DCMAKE_INSTALL_PREFIX={prefix.as_posix()}"])
    if configured.returncode != 0:
        return configured
    output = configured.output
    for command in (["--build", "."], ["--install", "."]):
        result = subprocess.run(
            ["cmake", *command], cwd=project_dir / "build", capture_output=True, text=True, check=False
        )
        output += result.stdout + result.stderr
        if result.returncode != 0:
            return Configured(result.returncode, output)
    return Configured(0, output)
