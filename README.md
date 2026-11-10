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
  - [Compile profiles](#compile-profiles)
  - [Nested csCMake projects](#nested-cscmake-projects)
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
  csCMakeProjectSetup.json          # common project setup + one preset per variant (generated)
  layout/                           # project setup of each layout (generated)
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
    # compile profiles of every target (default: cscmake_default), see "Compile profiles"
    DEFAULT_COMPILE_PROFILES cscmake_default cscmake_strict_warnings
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
)

# optional helpers
cs_target_use_compile_profiles(mylib myApp_paranoid)   # more compile profiles for this target
cs_target_use_openmp(mylib PUBLIC)
cs_target_check_installed_headers(mylib COMPILE_PROFILES cscmake_strict_warnings)  # each header compiles alone

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

`cs_initialize_project` creates `<namespace>::cscmake_base_include` (the project root and the generated folders as
include folders, build-interface and install-interface aware), installed in the `cscmake_common` component, with the
same name in the build tree and once installed. Compile options come from the compile profiles.

### Compile profiles

A compile profile is a named set of rules; a rule adds compile options, compile definitions, link options, clang-tidy
or other profiles, under conditions on the configuration, the compiler, its command-line style and the platform
(every condition is optional):

```cmake
cs_add_compile_profile_rule(
  PROFILE myApp_paranoid
  CONFIGS Paranoid                          # build configurations
  COMPILERS GNU Clang                       # CMAKE_CXX_COMPILER_ID
  FRONTENDS GNU                             # command-line style: GNU, or MSVC (cl, clang-cl)
  PLATFORMS Linux                           # CMAKE_SYSTEM_NAME
  COMPILE_OPTIONS -fno-inline
  COMPILE_DEFINITIONS MY_CHECKS=1
  LINK_OPTIONS ...
  PROFILES cscmake_sanitize_undefined cscmake_clang_tidy)   # other profiles, under the same conditions
```

`cs_finalize_target` applies to each target the default profiles of the project (`DEFAULT_COMPILE_PROFILES` of
`cs_initialize_project`, `cscmake_default` if not given, `NONE` for none) and the ones given to
`cs_target_use_compile_profiles(<target> <profile>...)`. Compile options and definitions are private to the target
(consumers never get them); the link options of static and object libraries are also part of their interface (e.g.
the sanitizer runtime). `CLANG_TIDY` runs clang-tidy with the checks of the project's `.clang-tidy`: where such a rule
matches the build, configure fails without clang-tidy (`CLANG_TIDY_EXE`); the Visual Studio and Xcode generators do
not run it (warning).

Profiles shipped with csCMake:

| Profile | Contents |
|---|---|
| `cscmake_default` | MSVC: `/MP` (parallel compilation), `/Zc:__cplusplus` |
| `cscmake_warnings` | high warning level, the same checks on every compiler (table below) |
| `cscmake_warnings_as_errors` | `-Werror` / `/WX` |
| `cscmake_strict_warnings` | `cscmake_warnings` + `cscmake_warnings_as_errors` |
| `cscmake_sanitize_undefined` | UndefinedBehaviorSanitizer (GCC, Clang, AppleClang on Linux / macOS) |
| `cscmake_sanitize_address` | AddressSanitizer (GCC, Clang, AppleClang on Linux / macOS; MSVC `/fsanitize=address`) |
| `cscmake_hardening_fast` | cheap standard library checks, usable in release builds: `_GLIBCXX_ASSERTIONS` (libstdc++), `_LIBCPP_HARDENING_MODE_FAST` (libc++) |
| `cscmake_hardening_debug` | every standard library check, expensive, for test configurations: `_GLIBCXX_ASSERTIONS` (libstdc++), `_LIBCPP_HARDENING_MODE_DEBUG` (libc++) |
| `cscmake_clang_tidy` | clang-tidy |

`cscmake_warnings`:

| Check | GCC / Clang / AppleClang | MSVC (`cl`) |
|---|---|---|
| warning level | `-Wall -Wextra -Wpedantic` | `/W4 /permissive-` (also clang-cl) |
| data member initialization order | `-Wreorder` | `/w15038` |
| non-virtual destructor with virtual functions | `-Wnon-virtual-dtor` | `/w14265` |
| function hiding a virtual one | `-Woverloaded-virtual` | `/w14263 /w14264` |
| narrowing and sign conversions | `-Wconversion -Wsign-conversion -Wdouble-promotion` | `/w14242 /w14254 /w14826` |
| enumerator not handled in a switch | (`-Wall`) | `/w14062` |
| implicit fallthrough in a switch | `-Wimplicit-fallthrough` | |
| shadowed variables | `-Wshadow` | (`/W4`) |
| old-style casts, `0` / `NULL` as pointer | `-Wold-style-cast -Wzero-as-null-pointer-constant` | |
| uninitialized, unused, format | `-Winit-self -Wuninitialized -Wunused -Wformat=2` | |
| other | `-Wfloat-equal -Wcast-align -Wnull-dereference`; GCC: `-Wlogical-op -Wduplicated-cond -Wduplicated-branches -Wmisleading-indentation -Wstrict-null-sentinel` | `/w14296 /w14905 /w14906 /w14928 /w14640` |

A project adds its own checks with more rules on its own profile (or on a shipped one), and silences one with a rule
adding `-Wno-...` / `/wd....`.

The standard library checks (*hardening*) turn undefined behaviour in the use of the standard library (`v[i]` out of
range, `front()` of an empty container, an empty `optional` dereferenced, ...) into an immediate stop of the program.
The MSVC standard library has them in the Debug runtime. They change the behaviour of a program with such a bug, so no
default profile has them: a project chooses where, e.g. every check while developing and the cheap ones in what it
ships (Release and RelWithDebInfo alike, so that RelWithDebInfo profiles and debugs the code of Release):

```cmake
cs_add_compile_profile_rule(PROFILE myApp_checks CONFIGS Debug Paranoid PROFILES cscmake_hardening_debug)
cs_add_compile_profile_rule(PROFILE myApp_checks CONFIGS Release RelWithDebInfo PROFILES cscmake_hardening_fast)
cs_initialize_project(... DEFAULT_COMPILE_PROFILES cscmake_default myApp_checks)
```

With Xcode, its setting `CLANG_CXX_STANDARD_LIBRARY_HARDENING` defines `_LIBCPP_HARDENING_MODE` too: in the targets
with a hardening profile, the definition of the profile wins (the hardening profiles add `-Wno-macro-redefined` with
Xcode); the other targets keep the Xcode setting.

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
> `presets/csCMakeProjectSetup.json` and `presets/layout/*.json`
> files are committed and are not meant to be edited by hand. The `generate-csv1-presets` pre-commit hook
> regenerates them whenever the templates, the registry or the generator
> change; if it rewrites files, stage them and commit again.

## Project setup presets

Every generated preset inherits `cscmake-project-setup`, defined by a **layout**: where the workspace and csCMake are,
and long or short build folder names. A project chooses it in its `csCMakeProjectSetup.json`, next to its
`CMakePresets.json`, by including one of the layouts of `presets/layout/`:

| Layout | Workspace (`CSCMAKE_WORKSPACE_ROOT`) | csCMake (`CSCMAKE_ROOT`) | Build folder names |
|---|---|---|---|
| `sibling` | the parent folder of the project | `<workspace>/csCMake` | long (variant id) |
| `sibling-short` | the parent folder of the project | `<workspace>/csCMake` | short |
| `standalone` | `<project>/workspace` | `<workspace>/csCMake` | long |
| `standalone-short` | `<project>/workspace` | `<workspace>/csCMake` | short |
| `env` | environment variable `CSCMAKE_WORKSPACE_ROOT` | environment variable `CSCMAKE_ROOT` | long |
| `env-short` | environment variable `CSCMAKE_WORKSPACE_ROOT` | environment variable `CSCMAKE_ROOT` | short |

Short build folder names keep Visual Studio builds clear of the 260-character path limit. For example, csCMake next to
the project:

```jsonc
// CMakePresets.json
{ "version": 10, "include": ["${sourceParentDir}/csCMake/presets/csv1/cs-presets-all.json"] }
// csCMakeProjectSetup.json
{ "version": 10, "include": ["${sourceParentDir}/csCMake/presets/layout/sibling-short.json"] }
```

With the `env` layouts both includes start with `$penv{CSCMAKE_ROOT}/presets/...`; with the `standalone` ones with
`${sourceDir}/workspace/csCMake/presets/...`. A project can also define its own `cscmake-project-setup`: include
`presets/csCMakeProjectSetup.json`, inherit `cscmake-common-project-setup` and set the three environment values
`CSCMAKE_WORKSPACE_ROOT`, `CSCMAKE_ROOT` and `CSCMAKE_BUILD_SUB_DIR` (as the files of `presets/layout/` do).

Build and install folders:

```
$CSCMAKE_WORKSPACE_ROOT/build/<variant id or short form>/<sourceDirName>/...   # build output
$CSCMAKE_WORKSPACE_ROOT/install/<variant id>/<sourceDirName>                   # install output
```

`CMAKE_PREFIX_PATH` contains `$CSCMAKE_WORKSPACE_ROOT/install/<variant id>` and `.../libs/<variant id>`. Other
variables of the setup:

| Variable | Meaning |
| -------- | ------- |
| `CSCMAKE_PREFIX_PATH_HEAD` / `CSCMAKE_PREFIX_PATH_TAIL` | extra paths prepended/appended to `CMAKE_PREFIX_PATH` by `cs_initialize_project`: environment variables (passed by the presets) or `-D` |
| `CSCMAKE_MODULE_PATH_HEAD` / `CSCMAKE_MODULE_PATH_TAIL` | the same for `CMAKE_MODULE_PATH` |
| `CSCMAKE_CSV1_SUB_DIR` / `_SHORT` | variant folder names, long and short (set by the variant presets) |
| `CSCMAKE_CSV1_SINGLE_CONFIG_SUB_DIR` | per-build-type sub-folder inside the build dir (`debug`, `release`, ...) |

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
  120 columns, docstring comment required on every function/macro: a `#.rst:` block for the public ones, see
  "Documentation")
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

### Documentation

The documentation is built with [Sphinx](https://www.sphinx-doc.org) and published on GitHub Pages by the `docs`
workflow (`.github/workflows/docs.yml`: every push and pull request builds it and uploads it as an artifact; pushes to
`main` publish it). The built HTML is not committed.

- **Reference**: generated from the CMake modules. Each module, public command, variable and property is documented
  in a `#.rst:` comment block of the `.cmake` file (reStructuredText, the format of CMake's own modules), right above
  the code it describes; `docs/reference/<module>.rst` includes the module with `.. cmake-module::`. The
  `sphinxcontrib-moderncmakedomain` extension provides the `command`, `variable`, `prop_tgt` and `prop_gbl` entries and
  the `:command:` / `:variable:` / ... references; references to CMake's own commands and variables link to the
  CMake documentation of the minimum CMake version (3.31), through a local copy of its inventory: see
  [`docs/_inventories/README.md`](docs/_inventories/README.md) (updated with `cscmake-update-cmake-inventory`, or the
  VS Code task **Docs: update CMake inventory**, when the minimum CMake version changes).
- **Pages**: Markdown (MyST) in `docs/`, starting from `docs/index.md`.

Build it locally (or run the VS Code task **Docs: build**), then open `docs/_build/html/index.html`:

```bash
sphinx-build -W -n docs docs/_build/html    # -W: warnings are errors, -n: every reference must resolve
```

To change the reference, edit the `#.rst:` block in the `.cmake` file and rebuild. cmake-format leaves `#.rst:` blocks
as written (`literal_comment_pattern` in `.cmake-format.json`): wrap them by hand at 120 columns.

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
