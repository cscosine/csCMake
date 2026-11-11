# Getting started

This page sets up a first csCMake project: where csCMake lives, the three files a project needs, and the commands
that configure, build, test and install it.

## Requirements

- **CMake 3.31** or newer (checked when csCMake is included).
- A C++ toolchain:
  - Linux: GCC or Clang;
  - Windows: MSVC or MSVC + LLVM (clang-cl), with the Visual Studio generators, or Ninja / Ninja Multi-Config from a
    Visual Studio developer environment (Developer PowerShell, `vcvars`, or an IDE using its toolset);
  - macOS (Apple Silicon): Apple Clang, with Ninja, Ninja Multi-Config or Xcode.
- Python is not needed to use csCMake: the presets are committed, ready to use.

## Where csCMake lives

csCMake is not installed: a project uses a copy of it, and finds it through its presets. The usual layout is a
*workspace* folder holding csCMake, the projects, and the build and install folders of every project:

```mermaid
flowchart TB
    subgraph ws["workspace/"]
        cs["csCMake/<br/>(this repository)"]
        p1["myLib/"]
        p2["myApp/"]
        build["build/&lt;variant&gt;/&lt;project&gt;/"]
        install["install/&lt;variant&gt;/&lt;project&gt;/"]
    end
    p1 -. "presets, include(csCMake)" .-> cs
    p2 -. "presets, include(csCMake)" .-> cs
    p2 -. "find_package(myLib)" .-> install
```

```text
workspace/
  csCMake/                     csCMake: a release package, or a git clone
  myLib/                       a project
  myApp/                       another project, using myLib
  build/<variant>/<project>/   created by the presets
  install/<variant>/<project>/ created by the presets: other projects find the installed packages here
```

This is the `sibling` *layout*. A project chooses its layout in one file (below); the others are `standalone` (a
workspace inside the project, e.g. for a self-contained application) and `env` (the workspace and csCMake given by
environment variables). See [Presets](presets.md#layouts).

Get csCMake in the workspace in one of two ways:

- **a release** (a fixed version): download `csCMake-<version>.tar.gz` (or `.zip`) from the GitHub Releases of csCMake
  and unpack it in the workspace; it creates `csCMake/`. `SHA256SUMS` lists the checksums of the archives
  (`sha256sum -c SHA256SUMS --ignore-missing`). The documentation of that version is `csCMake-docs-<version>.zip`;
- **a git clone**: `git clone <csCMake repository> csCMake`, on a release tag (`git checkout v<version>`) or on a
  branch (`main`: the latest release, `dev`: the development).

## The files of a project

A minimal project, `myApp/`, with one library and one executable:

```text
myApp/
  CMakeLists.txt
  CMakePresets.json
  csCMakeProjectSetup.json
  myApp/
    CMakeLists.txt
    core/Greeting.hpp
    core/Greeting.cpp
    main.cpp
```

### `CMakePresets.json`

It includes every preset of csCMake: one per supported platform, compiler and generator.

```json
{
    "version": 10,
    "include": ["${sourceParentDir}/csCMake/presets/csv1/cs-presets-all.json"]
}
```

### `csCMakeProjectSetup.json`

It chooses the layout: here the workspace is the parent folder of the project, csCMake one of its folders. The csCMake
presets include it by this name, from the folder of `CMakePresets.json`.

```json
{
    "version": 10,
    "include": ["${sourceParentDir}/csCMake/presets/layout/sibling.json"]
}
```

### `CMakeLists.txt`

```cmake
cmake_minimum_required(VERSION 3.31)
project(myApp VERSION 1.0.0 LANGUAGES CXX)

# found through CMAKE_MODULE_PATH, set by the presets
include(csCMake)

cs_initialize_project(
  NAMESPACE myApp
  CXX_STANDARD 20
  DEFAULT_CONFIG Debug Release)

add_subdirectory(myApp)
```

`cs_initialize_project` sets up the project: the namespace of its installed targets and package
(`myApp::core`, `find_package(myApp)`), the C++ standard, the build configurations. It must follow `project()` with a
`VERSION`: it is the version of the installed package. At the end of this file, csCMake finalizes the project:
it applies the compile profiles of the targets, resolves their runtime dependencies and generates the installed
package.

### `myApp/CMakeLists.txt`

```cmake
cs_add_library(core STATIC)
cs_target_sources(
  core
  PRIVATE core/Greeting.cpp
  PRIVATE_INSTALL core/Greeting.hpp)
cs_target_link_libraries(core PUBLIC myApp::cscmake_base_include)
cs_install_target(core COMPONENT core DEFAULT)

cs_add_executable(myApp main.cpp)
cs_target_link_libraries(myApp PRIVATE core)
cs_install_target(myApp COMPONENT app)
```

- `cs_add_library` / `cs_add_executable` work like `add_library` / `add_executable`, and register the target in the
  project.
- `PRIVATE_INSTALL` adds a source that is also installed with the target (a public header).
- `myApp::cscmake_base_include` is the default target of the project: linking it makes the headers includable relative
  to the project folder, `#include <myApp/core/Greeting.hpp>`, in the build tree and once installed.
- `cs_install_target` installs the target in a *component* of the package (`core`, `app`); `DEFAULT`
  makes the component part of `find_package(myApp)` without `COMPONENTS`.

[Targets and sources](targets.md) explains each command.

## Configure, build, test, install

List the presets available on this machine:

```bash
cmake --list-presets
```

Each preset name describes the platform, the compiler and the generator, e.g.
`csv1-linux-ubuntu24.04-x64-generic-gcc-default-ninjamulticonfig`. The simplest way to do everything is the workflow
preset of the same name, with `workflow-` in front and the configurations at the end: it configures, then builds,
installs and tests each configuration.

```bash
cmake --workflow --preset workflow-csv1-linux-ubuntu24.04-x64-generic-gcc-default-ninjamulticonfig-debug-release
```

or step by step:

```bash
cmake --preset csv1-linux-ubuntu24.04-x64-generic-gcc-default-ninjamulticonfig
cmake --build --preset build-csv1-linux-ubuntu24.04-x64-generic-gcc-default-ninjamulticonfig-debug
cmake --build --preset install-csv1-linux-ubuntu24.04-x64-generic-gcc-default-ninjamulticonfig-debug
ctest --preset test-csv1-linux-ubuntu24.04-x64-generic-gcc-default-ninjamulticonfig-debug
```

(installing is a build of the `install` target: `install-*` are build presets).

The build goes to `workspace/build/<variant>/myApp/`, the installation to `workspace/install/<variant>/myApp/`, where
another project of the workspace finds it with `find_package(myApp)`. [Presets](presets.md) explains the names and
the folders.

## Next

- [Targets and sources](targets.md): libraries, executables, sources and installed headers, links, when the
  project is finalized.
- [Dependencies](dependencies.md): other packages, and other csCMake projects.
- [Installed packages](install.md): components and the generated `<namespace>Config.cmake`.
- [Build configurations](build-configurations.md), [Compile profiles](compile-profiles.md), [Presets](presets.md).
- [Troubleshooting](troubleshooting.md).
