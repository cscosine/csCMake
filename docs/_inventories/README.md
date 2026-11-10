# CMake documentation inventory

`cmake-<version>.inv` is an unmodified copy of `https://cmake.org/cmake/help/v<version>/objects.inv`, the Sphinx
inventory of the CMake documentation: the list of CMake's commands, variables, properties, ... and of their pages.

The csCMake documentation uses it through Sphinx intersphinx (`intersphinx_mapping` in `docs/conf.py`): a reference such
as `` :command:`target_sources` `` or `` :variable:`CMAKE_PREFIX_PATH` `` in a `#.rst:` block of a CMake module becomes a
link to the CMake documentation, and `sphinx-build -n` fails on a CMake name that does not exist. The build reads this
local copy instead of downloading it: no network needed, the same links on every build.

`<version>` is `CMAKE_DOCS_VERSION` of `src/cscmake/devtools/cmake_inventory.py`, the minimum CMake version of csCMake
(`docs/conf.py` reads the same constant).

## Updating it

When the minimum CMake version of csCMake changes:

1. set `CMAKE_DOCS_VERSION` in `src/cscmake/devtools/cmake_inventory.py`;
2. run `cscmake-update-cmake-inventory` (or the VS Code task **Docs: update CMake inventory**): it downloads the
   inventory of that version, checks it, writes `cmake-<version>.inv` and removes the other versions;
3. build the documentation (`sphinx-build -W -n docs docs/_build/html`): a CMake name that no longer exists in that
   version fails the build;
4. commit the new inventory with the version change.

The inventory of a released CMake version does not change: there is nothing to update otherwise.
