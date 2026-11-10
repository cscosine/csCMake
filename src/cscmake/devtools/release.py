"""Build the assets of a csCMake release.

Run by the ``release`` workflow on a ``v*.*.*`` tag (see ``docs/contributing/releasing.md``), or locally to check a
release before tagging it. From the tag ``v<version>[-<pre-release>]`` and the built documentation it writes, in the
output folder:

- ``csCMake-<tag version>.tar.gz`` and ``.zip``: what a project needs (``PACKAGE_CONTENT``), in a ``csCMake/`` folder,
  to unpack in the workspace next to the projects (the sibling layout of the presets);
- ``csCMake-docs-<tag version>.zip``: the built documentation, in a ``csCMake-docs-<tag version>/`` folder;
- ``SHA256SUMS``: the checksums of the archives (``sha256sum -c SHA256SUMS``);
- ``release-notes.md``: the section ``## v<version>`` of ``CHANGELOG.md``.

The version of the tag without its pre-release part (``v0.2.0-rc1`` → ``0.2.0``) must be the version of
``pyproject.toml``, and ``CHANGELOG.md`` must have its section.

Usage (from the dev venv):
    cscmake-release --tag v0.2.0 --docs docs/_build/html --output dist
"""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
import tarfile
import tomllib
import zipfile
from collections.abc import Iterator
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]

# the files and folders of the package, relative to the repository root
PACKAGE_CONTENT = [
    "csCMake.cmake",
    "utils",
    "templates",
    "presets/csCMakeProjectSetup.json",
    "presets/common",
    "presets/csv1",
    "presets/layout",
    ".cmake-format.json",
    "README.md",
    "MIGRATION.md",
    "CHANGELOG.md",
    "LICENSE",
]
PACKAGE_FOLDER = "csCMake"

_TAG = re.compile(r"^v(?P<version>\d+\.\d+\.\d+)(?:-(?P<pre_release>[0-9A-Za-z.-]+))?$")
_SECTION = re.compile(r"^## ", re.MULTILINE)


class ReleaseError(Exception):
    """A release cannot be built: wrong tag, version or changelog."""


def parse_tag(tag: str) -> tuple[str, bool]:
    """Return the version of a release tag (``v0.2.0-rc1`` → ``0.2.0``) and whether it is a pre-release."""
    match = _TAG.match(tag)
    if not match:
        raise ReleaseError(f"tag {tag!r} is not a release tag v<major>.<minor>.<patch>[-<pre-release>]")
    return match["version"], match["pre_release"] is not None


def project_version(root: Path) -> str:
    """Return the version of ``pyproject.toml``."""
    with (root / "pyproject.toml").open("rb") as file:
        version: str = tomllib.load(file)["project"]["version"]
    return version


def release_notes(root: Path, version: str) -> str:
    """Return the section ``## v<version>`` of ``CHANGELOG.md``, without its heading."""
    text = (root / "CHANGELOG.md").read_text(encoding="utf-8")
    sections = _SECTION.split(text)[1:]
    for section in sections:
        heading, _, body = section.partition("\n")
        if heading.split()[0] == f"v{version}":
            return body.strip() + "\n"
    raise ReleaseError(f"CHANGELOG.md has no section '## v{version}'")


def package_files(root: Path) -> Iterator[tuple[Path, str]]:
    """Yield the files of the package and their path in the archive, sorted."""
    for entry in PACKAGE_CONTENT:
        path = root / entry
        if not path.exists():
            raise ReleaseError(f"{entry} is missing")
        files = sorted(p for p in path.rglob("*") if p.is_file()) if path.is_dir() else [path]
        for file in files:
            relative = file.relative_to(root)
            if "__pycache__" in relative.parts:
                continue
            yield file, f"{PACKAGE_FOLDER}/{relative.as_posix()}"


def write_archives(files: list[tuple[Path, str]], base: Path) -> list[Path]:
    """Write ``<base>.tar.gz`` and ``<base>.zip`` with the files, at their archive paths."""
    tar_path = base.with_name(base.name + ".tar.gz")
    with tarfile.open(tar_path, "w:gz") as tar:
        for file, name in files:
            tar.add(file, arcname=name)
    zip_path = base.with_name(base.name + ".zip")
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as archive:
        for file, name in files:
            archive.write(file, name)
    return [tar_path, zip_path]


def write_docs_archive(docs: Path, path: Path) -> Path:
    """Write the zip of the built documentation, in a folder named after the archive."""
    if not (docs / "index.html").is_file():
        raise ReleaseError(f"{docs} is not a built documentation (no index.html): run sphinx-build first")
    folder = path.name.removesuffix(".zip")
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as archive:
        for file in sorted(p for p in docs.rglob("*") if p.is_file()):
            archive.write(file, f"{folder}/{file.relative_to(docs).as_posix()}")
    return path


def write_checksums(paths: list[Path], path: Path) -> Path:
    """Write the SHA-256 checksums of the files, in the ``sha256sum`` format."""
    lines = [f"{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}\n" for p in paths]
    path.write_text("".join(lines), encoding="utf-8")
    return path


def build_release(tag: str, docs: Path, output: Path, root: Path = REPO_ROOT) -> list[Path]:
    """Check the tag against the project and build the release assets in ``output``; return their paths."""
    version, _ = parse_tag(tag)
    if version != project_version(root):
        raise ReleaseError(f"tag {tag} does not match the version {project_version(root)} of pyproject.toml")
    notes = release_notes(root, version)
    tag_version = tag.removeprefix("v")
    output.mkdir(parents=True, exist_ok=True)
    archives = write_archives(list(package_files(root)), output / f"csCMake-{tag_version}")
    archives.append(write_docs_archive(docs, output / f"csCMake-docs-{tag_version}.zip"))
    checksums = write_checksums(archives, output / "SHA256SUMS")
    notes_path = output / "release-notes.md"
    notes_path.write_text(notes, encoding="utf-8")
    return [*archives, checksums, notes_path]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--tag", required=True, help="release tag, v<major>.<minor>.<patch>[-<pre-release>]")
    parser.add_argument("--docs", type=Path, required=True, help="built documentation (sphinx-build output)")
    parser.add_argument("--output", type=Path, required=True, help="folder of the release assets")
    parser.add_argument("--root", type=Path, default=REPO_ROOT, help="csCMake checkout (default: this one)")
    args = parser.parse_args(argv)
    try:
        paths = build_release(args.tag, args.docs, args.output, args.root)
    except ReleaseError as error:
        print(f"cscmake-release: {error}", file=sys.stderr)
        return 1
    for path in paths:
        print(path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
