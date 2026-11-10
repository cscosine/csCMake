# Using a package

Two packages use `csSmokeBase` ([the previous tutorial](package-with-components.md)): `csSmokeMidB` with the simplest
layout, `csSmokeMidA` with the `Sol` layout. Both find it in the install folder of the workspace and propagate it to
their own consumers.

## Flat layout: `csSmokeMidB`

```text
csSmokeMidB/                project folder: project(csSmokeMidB), cs_initialize_project
  csSmokeMidB/              the library: no project()
    tests/
```

[`tests/smoke/csSmokeMidB/CMakeLists.txt`](../../tests/smoke/csSmokeMidB/CMakeLists.txt):

```{literalinclude} ../../tests/smoke/csSmokeMidB/CMakeLists.txt
:language: cmake
```

One `project()`, named like the package and its folder. The configurations are the same as `csSmokeBase`: a project
links the builds of its dependencies of the same configuration (or the mapped one), so a workspace uses the same
configurations everywhere.

[`tests/smoke/csSmokeMidB/csSmokeMidB/CMakeLists.txt`](../../tests/smoke/csSmokeMidB/csSmokeMidB/CMakeLists.txt):

```{literalinclude} ../../tests/smoke/csSmokeMidB/csSmokeMidB/CMakeLists.txt
:language: cmake
```

- `cs_find_package(... PUBLIC csSmokeBase COMPONENTS core REQUIRED CONFIG)`: finds the installed `csSmokeBase`, loading
  only its `core` component. `PUBLIC`: the installed `csSmokeMidBConfig.cmake` calls
  `find_dependency(csSmokeBase COMPONENTS core REQUIRED CONFIG)`, so the consumers of `csSmokeMidB` get `csSmokeBase`
  without finding it themselves.
- The library links `csSmokeBase::core` (from the other package) and `csSmokeMidB::cscmake_base_include` (its own
  default target: `#include <csSmokeMidB/csSmokeMidB.hpp>`).
- `cs_install_target(csSmokeMidB csSmokeMidB DEFAULT)`: one component, named like the package and loaded by default,
  so a consumer only writes `find_package(csSmokeMidB)`.

## `Sol` layout: `csSmokeMidA`

[`tests/smoke/csSmokeMidA/CMakeLists.txt`](../../tests/smoke/csSmokeMidA/CMakeLists.txt) is the same as the flat
layout, with a top project `csSmokeMidASol`; the library folder has its own `project(csSmokeMidA)`:

[`tests/smoke/csSmokeMidA/csSmokeMidA/CMakeLists.txt`](../../tests/smoke/csSmokeMidA/csSmokeMidA/CMakeLists.txt):

```{literalinclude} ../../tests/smoke/csSmokeMidA/csSmokeMidA/CMakeLists.txt
:language: cmake
```

It uses the `text` component of `csSmokeBase`; `csSmokeBase` loads `core` with it, because `text` depends on `core`.

The `Sol` layout suits a repository holding several packages or applications under one top project; the flat one a
repository that is one package. In both, the headers are included by their path from the project folder:
`#include <csSmokeMidA/csSmokeMidA.hpp>`.

Next: [an application using both](application.md).
