# A package with components

`csSmokeBase` is a library package with three components: `csSmokeBase` (the root of the package), `core` (header-only)
and `text` (a static library using `core`). It shows the `Sol` layout, components, installed headers, a unit test, the
installed-header check and project compile profiles.

```text
csSmokeBase/                          project folder (cs_initialize_project)
  CMakeLists.txt                      top project csSmokeBaseSol
  CMakePresets.json
  csCMakeProjectSetup.json
  .clang-tidy
  csSmokeBase/                        the package, its own project()
    CMakeLists.txt                    component csSmokeBase
    core/                             component core: Core.hpp
    text/                             component text: Text.hpp, Text.cpp, tests/
```

## The top project

[`tests/smoke/csSmokeBase/CMakeLists.txt`](../../tests/smoke/csSmokeBase/CMakeLists.txt):

```{literalinclude} ../../tests/smoke/csSmokeBase/CMakeLists.txt
:language: cmake
```

- **`Sol` layout**: the top project (`csSmokeBaseSol`) is not the package; the package is the folder
  `csSmokeBase/csSmokeBase/` with its own `project()`. The namespace, `csSmokeBase`, is the package name: it is also the
  name of the project folder, so that `find_package(csSmokeBase)` finds it in the workspace.
- **Configurations**: Debug and Release, RelWithDebInfo using the RelWithDebInfo builds of the dependencies or else
  their Release ones, and a custom `Paranoid` configuration based on Debug (postfix `dp`). See
  [Build configurations](../user/build-configurations.md).
- **Compile profiles**: `csSmokeBase_checks` is defined before `cs_initialize_project` and made a default profile of
  every target: every standard library check in Debug and Paranoid, the cheap ones in Release and RelWithDebInfo,
  UndefinedBehaviorSanitizer and clang-tidy in Paranoid (clang-tidy only with Clang on Linux, with the checks of the
  `.clang-tidy` of the project): one rule per set of conditions. See [Compile profiles](../user/compile-profiles.md).

## The package

[`tests/smoke/csSmokeBase/csSmokeBase/CMakeLists.txt`](../../tests/smoke/csSmokeBase/csSmokeBase/CMakeLists.txt):

```{literalinclude} ../../tests/smoke/csSmokeBase/csSmokeBase/CMakeLists.txt
:language: cmake
```

The INTERFACE target `csSmokeBase` links the default target `csSmokeBase::cscmake_base_include`: every component links
it in turn, so they all include headers relative to the project folder. Each target gets a namespaced alias, the same
name the consumers use once the package is installed.

## A header-only component

[`tests/smoke/csSmokeBase/csSmokeBase/core/CMakeLists.txt`](../../tests/smoke/csSmokeBase/csSmokeBase/core/CMakeLists.txt):

```{literalinclude} ../../tests/smoke/csSmokeBase/csSmokeBase/core/CMakeLists.txt
:language: cmake
```

- `PRIVATE_INSTALL Core.hpp`: the header is installed with the component, at
  `include/[<CONFIG>/]csSmokeBase/core/Core.hpp`, and included as `#include <csSmokeBase/core/Core.hpp>`.
- `cs_target_check_installed_headers` builds a small library `core_installed_headers` from a file that only
  includes `Core.hpp`, with the strict warnings: the header must compile on its own.

## A static component using another one

[`tests/smoke/csSmokeBase/csSmokeBase/text/CMakeLists.txt`](../../tests/smoke/csSmokeBase/csSmokeBase/text/CMakeLists.txt):

```{literalinclude} ../../tests/smoke/csSmokeBase/csSmokeBase/text/CMakeLists.txt
:language: cmake
```

`text` links `csSmokeBase::core`, so the component `text` depends on the component `core`: a consumer asking for
`COMPONENTS text` gets `core` loaded too. The sources include the headers by their path from the project folder:

```{literalinclude} ../../tests/smoke/csSmokeBase/csSmokeBase/text/Text.cpp
:language: cpp
```

## A unit test

[`tests/smoke/csSmokeBase/csSmokeBase/text/tests/CMakeLists.txt`](../../tests/smoke/csSmokeBase/csSmokeBase/text/tests/CMakeLists.txt):

```{literalinclude} ../../tests/smoke/csSmokeBase/csSmokeBase/text/tests/CMakeLists.txt
:language: cmake
```

A test executable is a target of the project like any other: it is finalized too. It is not installed: no
`cs_install_target`. The test presets run it with `ctest`.

## What gets installed

```text
install/<variant>/csSmokeBase/
  include/[<CONFIG>/]csSmokeBase/core/Core.hpp
  include/[<CONFIG>/]csSmokeBase/text/Text.hpp
  lib/libtext<postfix>.a
  lib/cmake/csSmokeBase/csSmokeBaseConfig.cmake
  lib/cmake/csSmokeBase/targets/{csSmokeBase,core,text,cscmake_common}Targets.cmake
```

No component is `DEFAULT` except `cscmake_common`: consumers ask for the components they use. Next:
[using this package](using-a-package.md).
