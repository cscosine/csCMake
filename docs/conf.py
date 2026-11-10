"""Sphinx configuration of the csCMake documentation (build: sphinx-build -W -n docs docs/_build/html)."""

from __future__ import annotations

from docutils.nodes import Element, Node, TextElement
from sphinx.application import Sphinx
from sphinx.environment import BuildEnvironment
from sphinx.ext import intersphinx
from sphinxcontrib.moderncmakedomain.cmake import CMakeObject

from cscmake.devtools.cmake_inventory import docs_url, inventory_path

project = "csCMake"
author = "cscosine"

extensions = [
    "myst_parser",
    "sphinx.ext.intersphinx",
    "sphinxcontrib.moderncmakedomain",
]

# hand-written pages in Markdown (MyST), the reference extracted from the #.rst: comments of the CMake modules
source_suffix = {".md": "markdown", ".rst": "restructuredtext"}
root_doc = "index"
# command, variable, prop_tgt, ... without the cmake: prefix
primary_domain = "cmake"
exclude_patterns = ["_build", "_inventories"]

# every reference must resolve (CMake commands and variables: the CMake documentation)
nitpicky = True
# CMake's own commands, variables and properties link to the CMake documentation of the minimum CMake version of
# csCMake, through a local copy of its inventory (offline, reproducible builds): to change the version, edit
# CMAKE_DOCS_VERSION in src/cscmake/devtools/cmake_inventory.py and run cscmake-update-cmake-inventory
intersphinx_mapping = {"cmake": (docs_url(), inventory_path())}

html_theme = "alabaster"
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


def setup(app: Sphinx) -> None:
    """Properties described next to the code that writes them, and links to the CMake documentation."""
    # the domain creates these objects only from one document per property (CMake's own layout)
    for objtype in ("prop_tgt", "prop_gbl"):
        app.add_directive_to_domain("cmake", objtype, CMakeObject)
    app.connect("missing-reference", _resolve_in_cmake_inventory)
