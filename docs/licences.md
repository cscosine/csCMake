# Licences

## csCMake

csCMake is distributed under the MIT licence:

```{literalinclude} ../LICENSE
:language: text
```

## What each part contains

| Part | Third-party content |
|---|---|
| the csCMake package (`csCMake-<version>.tar.gz` / `.zip`): CMake modules, templates, presets, the formatter configuration | none: csCMake's own files only. The presets name compilers, generators and tools, they do not contain them. The `gersemi/` folder is a configuration of the formatter gersemi (MPL-2.0), which a project installs itself |
| this documentation (the site and `csCMake-docs-<version>.zip`) | files of the tools that build it: Sphinx (BSD-2-Clause: search, base styles), Furo (MIT: the theme; it contains normalize.css and gumshoe, MIT, with their notices in its files), sphinx-design (MIT), Pygments (BSD-2-Clause: highlighting styles), Snowball (BSD-3-Clause: the English stemmer of the search); their licences are below. The diagrams are drawn by Mermaid (MIT), loaded by the browser from a CDN: not in the zip (offline, the zip shows them as text; the Markdown pages, `docs/` of the repository, show them on GitHub, and in VS Code with the extension Markdown Preview Mermaid Support, `bierner.markdown-mermaid`) |
| the links to the CMake documentation | built from the inventory of the CMake documentation (`docs/_inventories`, BSD-3-Clause, Kitware, its notice next to it in `CMake-Copyright.txt`), used to build the documentation, not shipped |

The tools used to develop csCMake are not shipped: pytest, pytest-cov, mypy, ruff, pre-commit (MIT), import-linter
(BSD-2-Clause), gersemi (MPL-2.0), myst-parser (MIT), sphinxcontrib-mermaid (BSD-2-Clause),
sphinxcontrib-moderncmakedomain (BSD-3-Clause).

## Third-party licences of this documentation

The versions that built this documentation.

<!-- third-party licences: filled in by docs/conf.py when the documentation is built -->
