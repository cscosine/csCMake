# Presets

csCMake ships CMake presets for every supported platform, compiler and generator. A project includes them all and
chooses where its workspace and csCMake are (its *layout*); the presets then set the compiler, the generator, the build
and install folders and the search paths.

## Including the presets

`CMakePresets.json`, at the root of the project:

```json
{
    "version": 10,
    "include": ["${sourceParentDir}/csCMake/presets/csv1/cs-presets-all.json"]
}
```

The csCMake presets include `csCMakeProjectSetup.json` from the same folder: it chooses the layout (below). The path of
the first include depends on the layout too: `${sourceParentDir}/csCMake/...` for the `sibling` layouts,
`${sourceDir}/workspace/csCMake/...` for the `standalone` ones, `$penv{CSCMAKE_ROOT}/...` for the `env` ones.

## Preset names

```text
csv1-<os>-<os version>-<arch>-generic-<compiler>-<compiler version>-<generator>
```

| Part | Values |
|---|---|
| `<os>-<os version>` | `linux-ubuntu22.04`, `linux-ubuntu24.04`, `linux-ubuntu26.04`, `windows-v10`, `macos-macos15`, `macos-macos26` |
| `<arch>` | `x64`, `arm64` |
| `<compiler>` | `gcc`, `clang` (Linux); `msvc`, `msvcclang` (MSVC, MSVC + clang-cl); `appleclang` |
| `<compiler version>` | `default` (the one of the platform); with Ninja on Windows, the MSVC toolset: `msvc_2022_17`, `msvc_2026_18` |
| `<generator>` | `ninja`, `ninjamulticonfig`; `msvc2022`, `msvc2026` (Visual Studio); `xcode` |

`cmake --list-presets` lists the ones of the current machine. From the name of a variant:

| Generator | Configure | Build, install, test (per configuration) | Workflow |
|---|---|---|---|
| multi-config (Ninja Multi-Config, Visual Studio, Xcode) | `<variant>` | `build-<variant>-<config>`, `install-<variant>-<config>`, `test-<variant>-<config>` | `workflow-<variant>-<config>`, and `-debug-release`, `-debug-release-relWithDebInfo-paranoid` |
| single-config (Ninja) | `<variant>-<config>` | `build-<variant>-<config>`, `install-...`, `test-...` | `workflow-<variant>-<config>` |

`<config>` is `debug`, `release`, `relWithDebInfo` or `paranoid`: use the ones of the configurations of the project
(see [Build configurations](build-configurations.md)). A workflow preset configures, then builds, installs and tests.

```bash
cmake --workflow --preset workflow-csv1-linux-ubuntu24.04-x64-generic-gcc-default-ninjamulticonfig-debug-release
```

## Layouts

The layout says where the workspace (the folder of the build and install folders) and csCMake are, and how long the
build folder names are. A project includes one layout in its `csCMakeProjectSetup.json`:

```json
{
    "version": 10,
    "include": ["${sourceParentDir}/csCMake/presets/layout/sibling.json"]
}
```

| Layout | Workspace (`CSCMAKE_WORKSPACE_ROOT`) | csCMake (`CSCMAKE_ROOT`) | Build folder names |
|---|---|---|---|
| `sibling` | the parent folder of the project | `<workspace>/csCMake` | long (variant id) |
| `sibling-short` | the parent folder of the project | `<workspace>/csCMake` | short |
| `standalone` | `<project>/workspace` | `<workspace>/csCMake` | long |
| `standalone-short` | `<project>/workspace` | `<workspace>/csCMake` | short |
| `env` | environment variable `CSCMAKE_WORKSPACE_ROOT` | environment variable `CSCMAKE_ROOT` | long |
| `env-short` | environment variable `CSCMAKE_WORKSPACE_ROOT` | environment variable `CSCMAKE_ROOT` | short |

- `sibling`: projects and csCMake side by side in a workspace folder; the usual choice.
- `standalone`: a self-contained project, with its own workspace (and copy of csCMake) inside it.
- `env`: the workspace and csCMake anywhere, e.g. set by a CI job or a shell profile.
- The short build folder names keep Visual Studio builds clear of the 260-character path limit of Windows.

A project can also define its own setup: include `presets/csCMakeProjectSetup.json`, define a configure preset
`cscmake-project-setup` inheriting `cscmake-common-project-setup`, and set the environment values
`CSCMAKE_WORKSPACE_ROOT`, `CSCMAKE_ROOT` and `CSCMAKE_BUILD_SUB_DIR` (as the files of `presets/layout/` do).

## Folders

```text
$CSCMAKE_WORKSPACE_ROOT/build/<variant id or short form>/<project folder>/   build
$CSCMAKE_WORKSPACE_ROOT/install/<variant id>/<project folder>/               install prefix
```

`CMAKE_PREFIX_PATH` contains `$CSCMAKE_WORKSPACE_ROOT/install/<variant id>` and
`$CSCMAKE_WORKSPACE_ROOT/libs/<variant id>` (third-party libraries built for the variant), so the projects of the
workspace find each other: `find_package(<name>)` looks in the folders whose name starts with `<name>`, hence **a
project folder is named like its package**.

## Search paths

| Variable | Meaning |
|---|---|
| `CSCMAKE_PREFIX_PATH_HEAD` / `CSCMAKE_PREFIX_PATH_TAIL` | paths added before / after `CMAKE_PREFIX_PATH` by `cs_initialize_project`: environment variables of the same name (passed by the presets), or `-D` |
| `CSCMAKE_MODULE_PATH_HEAD` / `CSCMAKE_MODULE_PATH_TAIL` | the same for `CMAKE_MODULE_PATH` |

`CMAKE_MODULE_PATH` contains csCMake: this is how `include(csCMake)` finds it.

## Without the presets

The presets are a convenience: a project configures without them by adding csCMake to `CMAKE_MODULE_PATH` and choosing
the generator, the compiler and `CMAKE_BUILD_TYPE` itself:

```bash
cmake -S myApp -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_MODULE_PATH=/path/to/csCMake
```
