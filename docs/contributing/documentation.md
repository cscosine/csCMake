# Contributing to the documentation

This page explains how the csCMake documentation is organised, how to build it, and how to document new or changed
code. Read it before changing a public command, a variable, a property or a page.

## Where the documentation lives

| Part | Source | Format |
|---|---|---|
| Reference (commands, variables, properties) | `#.rst:` comment blocks in `csCMake.cmake` and `modules/`, right above the code they describe | reStructuredText, the format of CMake's own modules |
| Reference pages | `docs/reference/<module>.rst`: one line, `.. cmake-module:: ../../modules/<module>.cmake` | reStructuredText |
| Guides and other pages | `docs/**/*.md` | Markdown (MyST): readable on GitHub too |
| Site configuration | `docs/conf.py` | Python (Sphinx) |
| CMake documentation inventory | `docs/_inventories/cmake-<version>.inv` (see its `README.md`) | Sphinx inventory, never edited by hand |
| README | `README.md` | Markdown (GitHub) |

The reference is written next to the code on purpose: changing a command and its documentation is one edit in one
file, reviewed together.

## Building

Requirements: the dev environment (`./setup.sh`, then `source .venv/bin/activate`). It installs Sphinx and its
extensions (`pyproject.toml`, `dev` extra).

```bash
sphinx-build -W -n docs docs/_build/html
```

then open `docs/_build/html/index.html`. In VS Code, the task **Docs: build** runs the same command and lists the
problems in the Problems panel.

- `-W` turns every warning into an error, `-n` (nitpicky) requires every reference to resolve: a misspelt command,
  variable or property fails the build, as it does in CI.
- `docs/_build/` is ignored by git: the built HTML is never committed.
- The documentation build is not a pre-commit hook: build it before pushing when you changed a `#.rst:` block or a
  page.

### In CI and on GitHub Pages

The `docs` workflow (`.github/workflows/docs.yml`):

- builds the documentation with `-W -n` on every push and pull request, and for release tags as part of the `release`
  workflow;
- uploads the HTML as the artifact `github-pages` of the run: download it from the run page to look at the
  documentation of any branch;
- publishes it on GitHub Pages on pushes to `main` (Settings → Pages → Source: GitHub Actions).

On a release tag, the `release` workflow builds it again and attaches it to the GitHub Release
(`csCMake-docs-<version>.zip`): the documentation of every version stays available. See [Releasing](releasing.md).

### Completeness check

`cscmake-check-docs` (a pre-commit hook, also in CI through pre-commit) checks what the documentation build cannot
see:

- every public `cs_*` function or macro has a `.. command::` block of the same name right above it, and no
  `.. command::` block is left elsewhere;
- every csCMake variable or property the code uses (`CSCMAKE_*`, `_CSCMAKE_*`, `<prefix>_CSCMAKE_*`) has a
  `.. variable::` / `.. prop_tgt::` / `.. prop_gbl::` entry, and every entry is used. A name built from variables
  (`CSCMAKE_${config}_POSTFIX`) matches an entry with placeholders (`CSCMAKE_<CONFIG>_POSTFIX`);
- every documented module has its `docs/reference/<module>.rst` page.

It prints each problem as `<file>:<line>: <message>`.

## Documenting CMake code

### A module

Every documented module starts with a `#.rst:` block before `include_guard`: its title (the module name, underlined
with `-`), what it is for, and a `Commands` section (underlined with `^`) that the command blocks below fill:

```cmake
#.rst:
# csTargetSources
# ---------------
#
# The sources of the targets, and the ones installed with them (headers).
#
# Commands
# ^^^^^^^^
include_guard(GLOBAL)
```

A new documented module needs its page: `docs/reference/<module>.rst` containing
`.. cmake-module:: ../../modules/<module>.cmake`, and an entry in the `Reference` table of contents of `docs/index.md`.
A module without public commands or documented state (`csInternal`) keeps a plain `#` header and has
no page.

### A public command

Each public `cs_*` function or macro has a `#.rst:` block right above it, e.g. `cs_target_sources`:

```cmake
#.rst:
# .. command:: cs_target_sources
#
#   Add sources to a target, like :command:`target_sources`, and queue the ones to install with it.
#
#   .. code-block:: cmake
#
#     cs_target_sources(<target>
#       [PRIVATE|PUBLIC|INTERFACE <file>...]
#       [PRIVATE_INSTALL|PUBLIC_INSTALL|INTERFACE_INSTALL <file>...]
#       [PRIVATE_INSTALL_ABSOLUTE_PATH|PUBLIC_INSTALL_ABSOLUTE_PATH|INTERFACE_INSTALL_ABSOLUTE_PATH <file>...])
#
#   Every file is a source of the target in the build tree, with the given scope. Headers do not need to be
#   ``PUBLIC``: ``PRIVATE`` and ``PRIVATE_INSTALL`` are usual.
#
#   ``<target>``
#     A target of the project.
#
#   ``PRIVATE``, ``PUBLIC``, ``INTERFACE``
#     Sources, as in :command:`target_sources`.
#
#   ``PRIVATE_INSTALL``, ``PUBLIC_INSTALL``, ``INTERFACE_INSTALL``
#     Sources installed with the target by :command:`cs_install_target` (usually headers, relative to the current
#     folder), keeping their path relative to the folder of :command:`cs_initialize_project`.
#
#   ``PRIVATE_INSTALL_ABSOLUTE_PATH``, ``PUBLIC_INSTALL_ABSOLUTE_PATH``, ``INTERFACE_INSTALL_ABSOLUTE_PATH``
#     Sources given by absolute path (e.g. generated headers), installed with the target in the include folder of the
#     current folder.
#
#   :Reads: :variable:`CSCMAKE_SOURCE_DIR`
#   :Writes: :prop_tgt:`CSCMAKE_SOURCES_TO_INSTALL`, :prop_tgt:`CSCMAKE_SOURCES_TO_INSTALL_ABSOLUTE`
function(cs_target_sources target_name)
```

In order:

1. `.. command:: <name>`;
2. a one-sentence summary;
3. the signature in a `.. code-block:: cmake` block: placeholders in `<...>`, optional parts in `[...]`, repetitions
   with `...`; one keyword group per line when it does not fit;
4. details: what it does, when to call it, what fails;
5. the arguments as a definition list: the argument in double backquotes, its meaning on the next line, indented by
   2 more spaces;
6. `:Reads:` and `:Writes:` fields: the variables and properties the command reads and sets, as references (below).

The block is reStructuredText inside comments: directive content is indented by 2 spaces after `# `, and the wrapped
lines of a field are indented 2 more spaces than the field name:

```cmake
#   :Writes: :prop_tgt:`CSCMAKE_COMPONENT`, :prop_gbl:`CSCMAKE_<namespace>_COMPONENTS`,
#     :prop_gbl:`CSCMAKE_<namespace>_DEFAULT_COMPONENTS`
```

cmake-format leaves `#.rst:` blocks exactly as written (`literal_comment_pattern` in `.cmake-format.json`), so wrap
them by hand at 120 columns: cmake-lint checks the line length and takes the block as the docstring of the function.

A changed signature also goes in `.cmake-format.json` (`parse.additional_commands`), so cmake-format lays out the
keyword arguments of the calls.

### Variables and properties

Each variable or property a module sets is described once, in that module, in a `#.rst:` block (usually at the end
of the file), grouped under `Variables`, `Target properties` and `Global properties` headings:

```cmake
#.rst:
# Target properties
# ^^^^^^^^^^^^^^^^^
#
# .. prop_tgt:: CSCMAKE_COMPONENT
#
#   The component of the target (:command:`cs_install_target`).
```

| Entry | Directive | Reference |
|---|---|---|
| command | `.. command:: cs_x` | `` :command:`cs_x` `` |
| variable, cache variable | `.. variable:: CSCMAKE_X` | `` :variable:`CSCMAKE_X` `` |
| target property | `.. prop_tgt:: CSCMAKE_X` | `` :prop_tgt:`CSCMAKE_X` `` |
| global property | `.. prop_gbl:: CSCMAKE_X` | `` :prop_gbl:`CSCMAKE_X` `` |
| environment variable | — | `` :envvar:`X` `` |

- Names with parts that vary are written with placeholders, as CMake does: `CSCMAKE_<namespace>_COMPONENTS`,
  `CSCMAKE_RUNTIME_LIBRARIES_<CONFIG>`.
- Internal entries (a leading `_`, or state no project should read) start their description with "Internal:".
- References to CMake's own commands, variables and properties (`` :command:`target_sources` ``,
  `` :variable:`CMAKE_PREFIX_PATH` ``, `` :prop_tgt:`EXPORT_NAME` ``) link to the CMake documentation of the minimum
  CMake version: see `docs/_inventories/README.md`. A name CMake documents with a placeholder takes an explicit
  target: `` :prop_tgt:`CXX_CLANG_TIDY <<LANG>_CLANG_TIDY>` ``.
- A plain name that should not link (a keyword, an argument, a file) goes in double backquotes: ``` ``PUBLIC`` ```.

### Private functions

Private `_cs_*` functions are not documented in the reference: they keep a plain `#` comment above them, a one-line
summary (plus details), and `Reads:` / `Writes:` when they touch state. cmake-format reflows plain comments: keep an
empty `#` line between paragraphs and before bullet lists.

## Writing pages

Pages are Markdown files (MyST) under `docs/`, listed in a table of contents (`{toctree}` block of `docs/index.md` or
of a section page). Write them so that they also read well on GitHub:

- headings, lists, tables, code blocks: plain Markdown;
- diagrams: ` ```mermaid ` blocks (rendered by GitHub and by the documentation build alike; in VS Code, the
  recommended extension `bierner.markdown-mermaid` renders them in the Markdown preview);
- a command, variable or property: plain inline code, e.g. `cs_install_target`, `CSCMAKE_NAMESPACE`. In the site, inline
  code naming exactly one documented object becomes a link to its entry (`_link_code_to_reference` in `docs/conf.py`);
  a name documented twice (`CSCMAKE_NAMESPACE` is a variable and a target property) stays plain. The MyST role syntax
  (`` {cmake:prop_tgt}`CSCMAKE_NAMESPACE` ``) chooses explicitly, but GitHub and the editors show it as raw text: avoid
  it in pages
- a link to another page: a relative Markdown link to the `.md` file, e.g. [the documentation index](../index.md).
- a link to a repository file outside `docs/` (a smoke project, a template): a relative Markdown link, e.g.
  [the smoke driver](../../tests/smoke/run_smoke.py); on GitHub it opens the file, in the site it links to the file on
  GitHub at the commit built (`_link_repository_files_to_github` in `docs/conf.py`). Not a `.md` file: MyST takes a
  `.md` link for a page of the site (a broken reference);
- code from the repository (the tutorials): include the file, so the page always shows the tested code, with a link to
  the file before it for GitHub, where the include shows as a code block naming the file:

  ````text
  [`tests/smoke/csSmokeMidB/CMakeLists.txt`](../../tests/smoke/csSmokeMidB/CMakeLists.txt):

  ```{literalinclude} ../../tests/smoke/csSmokeMidB/CMakeLists.txt
  :language: cmake
  ```
  ````

Pages describe the current behaviour only: history goes in the `PLAN.md` changelog and in the commit messages,
`MIGRATION.md` maps old to new.

## Checklist: a new or changed public command

1. The `#.rst:` block of the command: summary, signature, details, arguments, `:Reads:` / `:Writes:`.
2. The variables and properties it introduces: an entry in the module that sets them.
3. `.cmake-format.json`: its signature in `parse.additional_commands`.
4. The guides that show it, `README.md` if it appears there, `MIGRATION.md` if it replaces something.
5. `sphinx-build -W -n docs docs/_build/html`, and look at the page.
