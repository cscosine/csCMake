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

## Choosing the project setup

`csCMakeProjectSetup.json`, next to `CMakePresets.json`, is the project setup: the csCMake presets include it by this
name and inherit the presets it defines. Choose the first level that covers what the project needs:

| Level | When | The setup of the project |
|---|---|---|
| 1. A layout | the usual case: say where the workspace and csCMake are | includes a layout |
| 2. Values for every variant | cache variables or environment values of the project, the same on every platform | includes `presets/csCMakeProjectSetup.json`, defines `cscmake-project-setup` |
| 3. Values per operating system | values that differ between Linux, Windows and macOS (e.g. the paths of a toolkit) | includes `presets/csCMakeProjectSetup-common.json`, defines `cscmake-project-setup` and the three OS presets |
| 4. Folders and search paths of the project | the build and install folders, `CMAKE_PREFIX_PATH`, elsewhere than in a csCMake workspace | as level 2 or 3, `cscmake-project-setup` without `cscmake-common-project-setup` |
| 5. No csCMake presets | the project chooses the generator, compiler and folders itself | no setup ([Without the presets](#without-the-presets)) |

Whatever the level, csCMake defines the presets of the variants (`cscmake-project-setup-<variant>`) and
`presets/csCMakeProjectSetup.json` the empty OS presets: a project defining one of them again next to them gets a
duplicate preset error. A preset can only inherit presets of its own file or of the files it includes, hence the
includes of each level.

### 1. A layout

The setup includes one of the layouts of the table above, and nothing else:

```json
{
    "version": 10,
    "include": ["${sourceParentDir}/csCMake/presets/layout/sibling.json"]
}
```

### 2. Values for every variant

The setup defines `cscmake-project-setup` itself, as a layout does: it inherits `cscmake-common-project-setup` (the
folders and search paths of the workspace), sets the environment values `CSCMAKE_WORKSPACE_ROOT`, `CSCMAKE_ROOT` and
`CSCMAKE_BUILD_SUB_DIR` (here those of the `sibling` layout; the files of `presets/layout/` have the others), and adds
the values of the project. They apply to every variant.

```json
{
    "version": 10,
    "include": ["${sourceParentDir}/csCMake/presets/csCMakeProjectSetup.json"],
    "configurePresets": [
        {
            "name": "cscmake-project-setup",
            "hidden": true,
            "inherits": "cscmake-common-project-setup",
            "environment": {
                "CSCMAKE_WORKSPACE_ROOT": "${sourceParentDir}",
                "CSCMAKE_ROOT": "$env{CSCMAKE_WORKSPACE_ROOT}/csCMake",
                "CSCMAKE_BUILD_SUB_DIR": "$env{CSCMAKE_CSV1_SUB_DIR}"
            },
            "cacheVariables": {
                "BUILD_TESTS": "OFF",
                "BUILD_SHARED_LIBS": "ON"
            }
        }
    ]
}
```

### 3. Values per operating system

The configure preset of a variant also inherits the preset of its operating system, `cscmake-project-setup-linux`,
`cscmake-project-setup-windows` or `cscmake-project-setup-macos`, before `cscmake-project-setup`: its values win over
those of the setup, including `CMAKE_PREFIX_PATH` and the folders of `cscmake-common-project-setup`.
`presets/csCMakeProjectSetup.json` defines them empty. A project that sets values per operating system includes
`presets/csCMakeProjectSetup-common.json` instead, which has everything else, and defines the three of them, the empty
ones too:

```json
{
    "version": 10,
    "include": ["${sourceParentDir}/csCMake/presets/csCMakeProjectSetup-common.json"],
    "configurePresets": [
        {
            "name": "cscmake-project-setup",
            "hidden": true,
            "inherits": "cscmake-common-project-setup",
            "environment": {
                "CSCMAKE_WORKSPACE_ROOT": "${sourceParentDir}",
                "CSCMAKE_ROOT": "$env{CSCMAKE_WORKSPACE_ROOT}/csCMake",
                "CSCMAKE_BUILD_SUB_DIR": "$env{CSCMAKE_CSV1_SUB_DIR}"
            }
        },
        {
            "name": "cscmake-project-setup-linux",
            "hidden": true,
            "cacheVariables": {"TOOLKIT_ROOT": "/opt/toolkit"}
        },
        {
            "name": "cscmake-project-setup-windows",
            "hidden": true,
            "cacheVariables": {"TOOLKIT_ROOT": "C:/Program Files/Toolkit"}
        },
        {
            "name": "cscmake-project-setup-macos",
            "hidden": true
        }
    ]
}
```

A value of the setup that only one operating system replaces goes in `cscmake-project-setup` and in that OS preset.

### 4. Folders and search paths of the project

The presets of the variants still choose the host, generator and compiler, but `cscmake-project-setup` does not inherit
`cscmake-common-project-setup`: it sets the build and install folders and the search paths itself (and
`CSCMAKE_DEPLOY_DIR`, else the deployments go to the build folder). The variant presets
give their names in the environment: `CSCMAKE_CSV1_SUB_DIR` (the variant id), `CSCMAKE_CSV1_SUB_DIR_SHORT` (its short
form) and `CSCMAKE_CSV1_SINGLE_CONFIG_SUB_DIR` (the configuration of a single-config generator, empty otherwise: keep
it in `binaryDir`, or the configurations share one build folder). `CMAKE_MODULE_PATH` must contain csCMake for
`include(csCMake)`.

```json
{
    "version": 10,
    "include": ["${sourceParentDir}/csCMake/presets/csCMakeProjectSetup.json"],
    "configurePresets": [
        {
            "name": "cscmake-project-setup",
            "hidden": true,
            "binaryDir": "${sourceDir}/out/build/$env{CSCMAKE_CSV1_SUB_DIR}/$env{CSCMAKE_CSV1_SINGLE_CONFIG_SUB_DIR}",
            "installDir": "${sourceDir}/out/install/$env{CSCMAKE_CSV1_SUB_DIR}",
            "cacheVariables": {
                "CMAKE_MODULE_PATH": "${sourceParentDir}/csCMake",
                "CMAKE_PREFIX_PATH": "/opt/dependencies/$env{CSCMAKE_CSV1_SUB_DIR}"
            }
        }
    ]
}
```

The [folders](#folders) and [search paths](#search-paths) below are then those of the project: the other projects
of a csCMake workspace find its packages only if their search paths contain its install folder, and the
`CSCMAKE_{PREFIX,MODULE}_PATH_{HEAD,TAIL}` environment variables reach `cs_initialize_project` only if the setup passes
them as cache variables. With values per
operating system, include `presets/csCMakeProjectSetup-common.json` and define the OS presets as in level 3.

### 5. No csCMake presets

See [Without the presets](#without-the-presets).

## Folders

```text
$CSCMAKE_WORKSPACE_ROOT/build/<variant id or short form>/<project folder>/   build
$CSCMAKE_WORKSPACE_ROOT/install/<variant id>/<project folder>/               install prefix
$CSCMAKE_WORKSPACE_ROOT/deploy/<variant id>/<project folder>/                deployments (CSCMAKE_DEPLOY_DIR)
```

The deployments of a project (`cs_deployment`) go to `<name>-<config>` in its deploy folder, made by the install:
outside `CMAKE_PREFIX_PATH`, never found by `find_package`.

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
