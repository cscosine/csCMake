"""Sphinx configuration of the csCMake documentation (build: sphinx-build -W -n docs docs/_build/html)."""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

from docutils import nodes
from docutils.nodes import Element, Node, TextElement
from sphinx import addnodes
from sphinx.application import Sphinx
from sphinx.environment import BuildEnvironment
from sphinx.ext import intersphinx
from sphinx.util.nodes import make_refnode
from sphinxcontrib.moderncmakedomain.cmake import CMakeObject

from cscmake.devtools.cmake_inventory import docs_url, inventory_path

project = "csCMake"
author = "cscosine"

extensions = [
    "myst_parser",
    "sphinx.ext.intersphinx",
    "sphinxcontrib.mermaid",
    "sphinxcontrib.moderncmakedomain",
]

# hand-written pages in Markdown (MyST), the reference extracted from the #.rst: comments of the CMake modules
source_suffix = {".md": "markdown", ".rst": "restructuredtext"}
root_doc = "index"
# command, variable, prop_tgt, ... without the cmake: prefix
primary_domain = "cmake"
exclude_patterns = ["_build", "_inventories"]
# ```mermaid blocks: diagrams on GitHub and in the built documentation alike
myst_fence_as_directive = ["mermaid"]
# term / ": meaning" lists (troubleshooting)
myst_enable_extensions = ["deflist"]
# GitHub-style heading anchors: page.md#a-heading links work on GitHub and in the site
myst_heading_anchors = 3

# every reference must resolve (CMake commands and variables: the CMake documentation)
nitpicky = True
# CMake's own commands, variables and properties link to the CMake documentation of the minimum CMake version of
# csCMake, through a local copy of its inventory (offline, reproducible builds): to change the version, edit
# CMAKE_DOCS_VERSION in src/cscmake/devtools/cmake_inventory.py and run cscmake-update-cmake-inventory
intersphinx_mapping = {"cmake": (docs_url(), inventory_path())}

html_theme = "alabaster"

# links from the pages to repository files outside docs/ (the smoke projects, ...) go to GitHub, at the commit built
REPOSITORY_URL = "https://github.com/cscosine/csCMake"
REPOSITORY_ROOT = Path(__file__).resolve().parent.parent


def _source_revision() -> str:
    """Return the commit being built: GITHUB_SHA in CI, else git HEAD, else main."""
    if sha := os.environ.get("GITHUB_SHA"):
        return sha
    try:
        return subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=REPOSITORY_ROOT, capture_output=True, text=True, check=True
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return "main"


SOURCE_REVISION = _source_revision()
html_title = "csCMake"


def _resolve_in_cmake_inventory(
    app: Sphinx, env: BuildEnvironment, node: Element, contnode: TextElement
) -> Node | None:
    """Resolve :command:`target_sources` & co. in the CMake inventory: its objects are named <type>:<name>."""
    if node.get("refdomain") != "cmake":
        return None
    prefixed = node.deepcopy()
    target = prefixed["reftarget"]
    if prefixed["reftype"] == "command":
        target = target.split("(")[0].lower()
    prefixed["reftarget"] = f"{prefixed['reftype']}:{target}"
    return intersphinx.missing_reference(app, env, prefixed, contnode)


def _link_code_to_reference(app: Sphinx, doctree: nodes.document, docname: str) -> None:
    """Link inline code naming one documented csCMake object (`cs_install_target`, `CSCMAKE_SOURCE_DIR`, ...).

    The Markdown pages write names as plain inline code, which reads well on GitHub and in editors; in the site, a name
    documented exactly once (a command, a variable or a property) becomes a link to its entry.
    """
    domain = app.env.get_domain("cmake")
    entries: dict[str, list[tuple[str, str]]] = {}
    for target_id, entry in domain.data["objects"].items():
        name = target_id.partition(":")[2]
        entries.setdefault(name, []).append((entry.docname, entry.node_id))
    for literal in list(doctree.findall(nodes.literal)):
        if isinstance(literal.parent, nodes.reference):
            continue
        name = literal.astext().removesuffix("()")
        found = entries.get(name.lower() if name.startswith("cs_") else name, [])
        if len(found) == 1:
            target_doc, node_id = found[0]
            literal.replace_self(make_refnode(app.builder, docname, target_doc, node_id, literal.deepcopy(), name))


def _link_repository_files_to_github(app: Sphinx, doctree: nodes.document) -> None:
    """Turn the links to repository files outside docs/ into links to GitHub (instead of downloads)."""
    docs_dir = Path(app.srcdir).resolve()
    source = Path(app.env.doc2path(app.env.docname)).resolve()
    for download in list(doctree.findall(addnodes.download_reference)):
        target = (source.parent / download["reftarget"]).resolve()
        if docs_dir in target.parents or REPOSITORY_ROOT not in target.parents:
            continue
        relative = target.relative_to(REPOSITORY_ROOT).as_posix()
        link = nodes.reference("", "", *download.children, refuri=f"{REPOSITORY_URL}/blob/{SOURCE_REVISION}/{relative}")
        download.replace_self(link)


def setup(app: Sphinx) -> None:
    """Properties described next to the code that writes them, and links to the CMake documentation."""
    # the domain creates these objects only from one document per property (CMake's own layout)
    for objtype in ("prop_tgt", "prop_gbl"):
        app.add_directive_to_domain("cmake", objtype, CMakeObject)
    app.connect("missing-reference", _resolve_in_cmake_inventory)
    app.connect("doctree-resolved", _link_code_to_reference)
    # before the download collector (priority 500) registers them as downloads
    app.connect("doctree-read", _link_repository_files_to_github, priority=400)
