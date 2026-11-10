# csCMake

A set of utilities and wrappers over CMake to create and manage C++ projects.

csCMake provides an opinionated layer on top of CMake that standardizes how
projects are created, configured, built, installed and exported. It is made of
two parts:

1. A **CMake utility library** (`csCMake.cmake` + `utils/`) that turns a plain
   `CMakeLists.txt` into a well-structured project: custom build configurations,
   consistent output layout, MSVC handling, recursive dependency analysis,
   namespace-based install/export and more.
2. A **Python preset generator** (`src/cscmake/`) that renders a full matrix of
   CMake Presets (OS × architecture × compiler × generator × build type) from
   small templates, so every supported platform is one `cmake --preset` away.

> **Status:** under active development. `main` is tagged `v0.1.0`; new features
> land on the `dev` branch.

---

## Table of contents

- [Repository layout](#repository-layout)
- [Requirements](#requirements)
- [Quick start](#quick-start)
  - [Wiring csCMake into a project](#wiring-cscmake-into-a-project)
  - [Adding targets](#adding-targets)
  - [Build configurations](#build-configurations)
  - [Dependencies](#dependencies)
  - [Default targets](#default-targets)
  - [Install and export](#install-and-export)
- [CMake Presets](#cmake-presets)
  - [Using the generated presets](#using-the-generated-presets)
  - [Regenerating the preset matrix](#regenerating-the-preset-matrix)
- [Project setup presets](#project-setup-presets)
- [Development](#development)
- [License](#license)

---

## Repository layout

```
csCMake.cmake                       # main entry point: include(csCMake)
utils/                              # the CMake utility modules (public cs_* API)
presets/
  common/                           # reusable preset building blocks (generators,
                                    #   compilers, build types, hosts, targets...)
  csv1/                             # generated preset matrix (do not edit by hand)
  template/                         # templates used to generate the matrix
  csCMakeProjectSetup-base*.json    # base "project setup" presets (hand-written)
  csCMakeProjectSetup-{default,default-standalone,shortBuildPath}.json
                                    # project setup + one preset per variant (generated)
src/cscmake/                        # Python package (preset generation)
  presets/registry.py               #   supported variant matrix (single source of truth)
  presets/generate.py               #   preset generator (cscmake-generate-presets)
templates/csTemplateConfig.cmake.in # template of the installed <Ns>Config.cmake
tests/                              # pytest suite
  smoke/                            #   smoke projects + run_smoke.py driver (see its README.md)
```

## Requirements

- **CMake ≥ 3.31** (checked when `csCMake.cmake` is included; the csv1 presets use schema version 10)
- **Python ≥ 3.11** — only needed for the preset generator and development tooling
- A C++ toolchain for the target platform:
  - Linux: GCC or Clang
  - Windows: MSVC or MSVC + LLVM (ClangCL), with the Visual Studio generators or Ninja / Ninja Multi-Config; the
    Ninja presets are configured from a Visual Studio developer environment (Developer PowerShell, vcvars, or an IDE
    using their external toolset and architecture)
  - macOS (Apple Silicon): Apple Clang, with Ninja, Ninja Multi-Config or Xcode

## Quick start

### Wiring csCMake into a project

The top-level `CMakeLists.txt` is reduced to the essential steps:

```cmake
cmake_minimum_required(VERSION 3.31)
project(myApp VERSION 1.0.0 LANGUAGES CXX)

# make the csCMake directory visible to include()
include(csCMake)

cs_initialize_project(
    # namespace of the installed targets (myApp::...) and package name (find_package(myApp))
    NAMESPACE myApp
    CXX_STANDARD 17
    # select the default configurations supported by this project
    DEFAULT_CONFIG Debug Release
    # map a CMake build-type name onto an existing default configuration,
    # with a fallback list used when the exact mapping is unavailable
    DEFAULT_CONFIG_MAPPED RelWithDebInfo MAPPED_TO "RelWithDebInfo,Release,"
    # define a custom configuration, cloned from Debug; artifacts get postfix "d"
    CUSTOM_CONFIG MyCustomConfig BASED_ON Debug POSTFIX "d"
    # enable strict compilation (warnings-as-errors) for one configuration only
    STRICT_COMPILATION_ON_CONFIG Debug
)

# add libraries, executables...
add_subdirectory(src)

# mandatory, at the end of the CMakeLists.txt of cs_initialize_project (checked at the end of the file)
cs_finalize_project()
```

> When configuring through the csCMake presets, `CMAKE_MODULE_PATH` is set to the
> csCMake root automatically (see [Project setup presets](#project-setup-presets)),
> so `include(csCMake)` works out of the box. If you configure by hand, add the
> csCMake root to `CMAKE_MODULE_PATH` yourself.

### Adding targets

```cmake
# drop-in replacements for add_library / add_executable that also track
# configurations, output postfixes and the project target list
cs_add_library(mylib)                       # STATIC / SHARED / INTERFACE / ...
cs_add_library(myApp::mylib ALIAS mylib)    # namespaced alias
cs_add_executable(mytool)

# sources: standard keywords plus *__INSTALL variants that also queue files
# for installation (useful for headers)
cs_target_sources(mylib
    PRIVATE
        impl.cpp
    PRIVATE_INSTALL
        mylib.h
)

# links and performs the dependency analysis (aliases and imported targets
# are resolved automatically)
cs_target_link_libraries(mylib
    PUBLIC
        myApp::cscmake_base_include              # project root include dir
        myApp::cscmake_compile_options_strict
)

# optional helpers
cs_target_use_openmp(mylib PUBLIC)
cs_target_enable_clang_tidy(mylib)                     # clang-tidy as a build step (Linux/Clang)
cs_target_check_installed_headers(mylib mylib)   # compile every installed header standalone

# export the target within the given components; pass DEFAULT to include it in
# the default component list
cs_install_target(mylib myApp DEFAULT)

# mandatory for every target, after its links (dependency analysis; cs_finalize_project checks it)
cs_finalize_target(mylib)
```

### Build configurations

csCMake supports any number of named build configurations, not only the stock
CMake ones:

| Configuration    | How to add                                 | Artifact postfix |
| ---------------- | ------------------------------------------ | ---------------- |
| `Debug`          | `DEFAULT_CONFIG Debug`                     | `d`              |
| `Release`        | `DEFAULT_CONFIG Release`                   | *(none)*         |
| `RelWithDebInfo` | `DEFAULT_CONFIG_MAPPED RelWithDebInfo MAPPED_TO "..."` | `rd`  |
| any custom       | `CUSTOM_CONFIG <Name> BASED_ON <Base> POSTFIX "<suffix>"` | your choice |

Details:

- Postfixes (defaults `d`, `""`, `rd` for the stock configurations) are applied
  to the produced files, so artifacts of different configurations can coexist.
- The exact `CMAKE_MAP_IMPORTED_CONFIG_*` mapping is generated for imported
  dependencies.
- The MSVC runtime library is selected per configuration
  (`CSCMAKE_MSVC_RUNTIME_LIBRARY_<CONFIG>` cache variables, overridable with `-D`) and propagated to
  every target as a generator expression.
- Output is kept in a single predictable layout:
  - multi-config generators: `<build>/bin/<CONFIG>`, `<build>/lib/<CONFIG>`
  - single-config generators: `<build>/bin`, `<build>/lib`

#### MSVC runtime library

The runtime of each configuration is the cache variable `CSCMAKE_MSVC_RUNTIME_LIBRARY_<CONFIG>` (values of CMake's
`MSVC_RUNTIME_LIBRARY`): `MultiThreadedDebugDLL` for Debug, `MultiThreadedDLL` for Release and RelWithDebInfo; a custom
configuration copies the one of the configuration it is based on. The static runtime, for example:

```bash
cmake --preset <preset> -DCSCMAKE_MSVC_RUNTIME_LIBRARY_DEBUG=MultiThreadedDebug \
      -DCSCMAKE_MSVC_RUNTIME_LIBRARY_RELEASE=MultiThreaded -DCSCMAKE_MSVC_RUNTIME_LIBRARY_RELWITHDEBINFO=MultiThreaded
```

(or the same values in the `cacheVariables` of a preset of the project). Every library linked into one executable
(the project's packages and the third-party ones) must use the same runtime: build them all with the same values.

### Dependencies

Wrap `find_package` so that transitive requirements are recorded and replayed
for consumers of the installed project:

```cmake
# PUBLIC:  the same find_package line is reproduced in the installed <Ns>Config.cmake
# PRIVATE: resolved locally, not propagated
cs_find_package(mylib PUBLIC Eigen3 REQUIRED)
```

### Default targets

`cs_initialize_project` creates a few convenience targets, installed in the
`cscmake_common` component. They have the same name in the build
tree and once installed:

- `<namespace>::cscmake_base_include` — includes the project root and the
  generated folders (build-interface and install-interface aware).
- `<namespace>::cscmake_compile_options` — common flags (e.g. MSVC parallel
  compilation).
- `<namespace>::cscmake_compile_options_strict` — default flags plus strict
  compilation; if `STRICT_COMPILATION_ON_CONFIG` is set, the corresponding
  configuration also gets sanitizer flags (GCC/Clang on non-Windows).
- `<namespace>::cscmake_msvc_parallel_compile`,
  `<namespace>::cscmake_strict_warnings` — the building blocks of the two above.

### Nested csCMake projects

A csCMake project can be added with `add_subdirectory` to another one (e.g. a library developed together with the
application using it), in one build tree:

- each project has its own namespace, targets, components, debug option and installed package;
- the build configurations belong to the build tree: the first csCMake project defines them, a nested project uses
  some of them, defined the same way (configure fails otherwise);
- a target linking a target of the other project makes its component `find_dependency()` that package in the
  installed `<namespace>Config.cmake`.

### Install and export

`cs_finalize_project()` finalizes the whole project (namespace from `cs_initialize_project`):

- checks that every target of `cs_add_library` / `cs_add_executable` was finalized with
  `cs_finalize_target`, and that no link was added after it;
- recurses through targets to compute runtime dependencies (DLLs/libs) per
  configuration;
- sets the Visual Studio debugger environment variables for those dependencies;
- generates an installable `<Ns>Config.cmake` from
  `templates/csTemplateConfig.cmake.in`, supporting **components**,
  transitive `find_dependency` calls and cyclic-dependency checks.

Consumers then just do:

```cmake
find_package(MyNamespace COMPONENTS mylib REQUIRED)
target_link_libraries(app PRIVATE MyNamespace::mylib)
```

## CMake Presets

`presets/csv1/` contains a generated matrix of presets covering every supported
combination, e.g.:

```
csv1-linux-ubuntu24.04-x64-generic-gcc-default-ninja(-debug|release|...).json
csv1-windows-v10-x64-generic-msvc-default-msvc2026(-debug|...).json
... + -base / -ALL / -paranoid / -relwithdebinfo variants
cs-presets-all.json      # single preset that includes every -ALL preset
```

Preset names follow the scheme
`csv1-<os>-<version>-<arch>-<variant>-<compiler>-<version>-<generator>`, with
`build-` / `install-` / `test-` / `workflow-` prefixed variants for each
build type.

### Using the generated presets

A project simply includes the matrix in its `CMakePresets.json`:

```json
{
    "version": 10,
    "include": [
        "${sourceParentDir}/csCMake/presets/csv1/cs-presets-all.json"
    ]
}
```

and builds any supported target platform with:

```bash
cmake --preset csv1-linux-ubuntu24.04-x64-generic-gcc-default-ninja
cmake --build --preset build-csv1-linux-ubuntu24.04-x64-generic-gcc-default-ninja-debug
cmake --install --preset install-csv1-linux-ubuntu24.04-x64-generic-gcc-default-ninja-debug
ctest --preset test-csv1-linux-ubuntu24.04-x64-generic-gcc-default-ninja-debug
```

### Regenerating the preset matrix

The matrix is generated from the `@VAR@` templates in `presets/template/`.
Regenerate it after editing the templates or when the supported platform and
variant list changes:

```bash
cscmake-generate-presets           # regenerate in place (needs the dev venv, see Development)
cscmake-generate-presets --check   # exit 1 if presets/csv1 is stale
```

The supported OS/architecture/compiler/generator matrix is defined in
`src/cscmake/presets/registry.py` and rendered by `src/cscmake/presets/generate.py`.
The generator only needs the Python standard
library (no third-party dependency) and runs without
installing the package.

> **Note:** generated files under `presets/csv1/` and the
> `presets/csCMakeProjectSetup-{default,default-standalone,shortBuildPath}.json`
> files are committed and are not meant to be edited by hand. The `generate-csv1-presets` pre-commit hook
> regenerates them whenever the templates, the registry or the generator
> change; if it rewrites files, stage them and commit again.

## Project setup presets

The `presets/csCMakeProjectSetup*.json` files define a hidden
`cscmake-project-setup` (base) preset inherited by every generated preset. It
centralizes the workspace layout and paths through environment variables:

| Variable | Meaning |
| -------- | ------- |
| `CSCMAKE_WORKSPACE_ROOT` | root folder of the sources (`${sourceParentDir}`) |
| `CSCMAKE_ROOT` | path to the csCMake clone (`$env{CSCMAKE_WORKSPACE_ROOT}/csCMake`) |
| `CSCMAKE_PREFIX_PATH_HEAD` / `CSCMAKE_PREFIX_PATH_TAIL` | extra paths prepended/appended to `CMAKE_PREFIX_PATH` by `cs_initialize_project`: environment variables (passed by the presets) or `-D` |
| `CSCMAKE_MODULE_PATH_HEAD` / `CSCMAKE_MODULE_PATH_TAIL` | the same for `CMAKE_MODULE_PATH` |
| `CSCMAKE_CSV1_SUB_DIR` / `_SHORT` | sub-folder used to keep build/install paths short |
| `CSCMAKE_CSV1_SINGLE_CONFIG_SUB_DIR` | per-build-type sub-folder inside the build dir (`debug`, `release`, ...) |

Build and install folders follow a common layout:

```
$CSCMAKE_WORKSPACE_ROOT/build/<variant>/<sourceDirName>/...     # build output
$CSCMAKE_WORKSPACE_ROOT/install/<variant>/<sourceDirName>       # install output
```

`csCMakeProjectSetup-shortBuildPath.json` provides an alternative base that uses
shorter path components (useful on Windows to stay clear of the 260-character
path limit).

## Development

Set up the environment with the provided scripts (creates a `.venv`, installs
the package in editable mode plus dev dependencies, and installs pre-commit):

```bash
./setup.sh          # Linux/macOS (uses python3, or pass one: ./setup.sh python3.12)
./setup.ps1         # Windows (uses python, or pass one)
```

Keep the venv active when committing: the `generate-csv1-presets` and
`import-linter` hooks, and the template cmake-format / cmake-lint hooks, run tools installed in it.

Quality gates, driven by **pre-commit**:

- `ruff` (lint + format, configured in `pyproject.toml`)
- `mypy` in strict mode (the package ships `py.typed`)
- `import-linter`: layer contracts in `pyproject.toml` (`presets` → `utils`)
- `actionlint` for the GitHub workflows
- `cmake-format` and `cmake-lint` for the CMake sources (`.cmake-format.json`,
  120 columns, docstring comment required on every function/macro)
- `cmake-format` / `cmake-lint` for the `templates/*.cmake.in` files too, through
  `cscmake-cmake-template` (the `@VAR@` placeholders are swapped for parseable
  stand-ins and restored afterwards)
- `generate-csv1-presets`: regenerates `presets/csv1/` from the templates
- generic hygiene checks (YAML/JSON validity, trailing whitespace, private
  keys, ...) plus a local hook that **fails on unstaged changes**

Run the tests and checks with:

```bash
python -m pytest                    # fast tests (incl. configure-only CMake tests in tests/cmake/)
python -m pytest --run-all          # + CMake smoke builds for the variants of this machine
python tests/smoke/run_smoke.py --variant csv1-linux-ubuntu24.04-x64-generic-gcc-default-ninjamulticonfig
python -m pytest --cov=cscmake
pre-commit run --all-files
```

### Smoke tests

`tests/cmake/` holds configure-only CMake tests: pytest writes a small project
using csCMake (`LANGUAGES NONE`, no compiler needed), configures it and checks
the values it reports (target and global properties set by csCMake).

`tests/smoke/` holds small projects that use csCMake exactly like real
projects (through the presets, csCMake as a sibling folder): a chain of
packages (`csSmokeBase` → `csSmokeMidA` /
`csSmokeMidB` → `csSmokeTop`). `tests/smoke/run_smoke.py --variant <id>` builds, installs and
tests them in order, runs the installed applications, checks and lints the
installed `<Package>Config.cmake` files; `.github/workflows/smoke.yml` runs it for every
variant of the preset registry. What is tested, with diagrams:
[tests/smoke/README.md](tests/smoke/README.md).

## License

[MIT](LICENSE) — Copyright (c) 2026 cscosine.
