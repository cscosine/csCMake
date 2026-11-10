# Build configurations

A csCMake project lists the build configurations it supports in `cs_initialize_project`: the CMake ones, and custom
ones based on them.

```cmake
cs_initialize_project(
  NAMESPACE myApp
  CXX_STANDARD 20
  DEFAULT_CONFIG Debug Release
  DEFAULT_CONFIG_MAPPED RelWithDebInfo
  MAPPED_TO "RelWithDebInfo,Release,"
  CUSTOM_CONFIG Paranoid
  BASED_ON "Debug,Release,"
  POSTFIX "dp")
```

| Configuration | Argument | Output name postfix |
|---|---|---|
| `Debug` | `DEFAULT_CONFIG Debug` | `d` |
| `Release` | `DEFAULT_CONFIG Release` | none |
| `RelWithDebInfo` | `DEFAULT_CONFIG RelWithDebInfo`, or `DEFAULT_CONFIG_MAPPED` (below) | `rd` |
| a custom one | `CUSTOM_CONFIG <name> BASED_ON <config> POSTFIX "<postfix>"` | `<postfix>` |

`DEFAULT_CONFIG` takes the CMake configurations among `Debug`, `Release` and `RelWithDebInfo`.

- **`DEFAULT_CONFIG_MAPPED <config> MAPPED_TO "<config>,<fallback>,..."`**: one of them, with the configurations of
  the *imported* targets (the installed packages it uses) to link, in order of preference. Here a RelWithDebInfo build
  links the RelWithDebInfo build of a dependency, or its Release build when there is none
  (`CMAKE_MAP_IMPORTED_CONFIG_RELWITHDEBINFO`).
- **`CUSTOM_CONFIG <name> BASED_ON "<config>,<fallback>,..." POSTFIX "<postfix>"`**: a new configuration, a copy of
  the first one listed (its compiler and linker flags, its MSVC runtime), which must be a `DEFAULT_CONFIG` of the
  project, with its own postfix (`""` for none). The
  list also maps the imported targets: a Paranoid build links the Debug build of a dependency, or its Release build.
  `BASED_ON Debug` alone is enough when no fallback is needed.

`DEFAULT_CONFIG_MAPPED` and `CUSTOM_CONFIG` can be repeated.

The mapping chooses both the libraries and the headers of a csCMake package (see
[Installed packages](install.md#using-an-installed-package)).

## Postfixes

The output files of a target get the postfix of the configuration (`libcored.a`, `libcore.a`, `libcorerd.a`,
`libcoredp.a`), so the files of every configuration can sit in the same folder and be installed in the same prefix.
The postfixes of the CMake configurations are cache variables: `CSCMAKE_DEBUG_POSTFIX`,
`CSCMAKE_RELEASE_POSTFIX`, `CSCMAKE_RELWITHDEBINFO_POSTFIX`.

## Output folders

Executables and DLLs go to `<build>/bin`, libraries to `<build>/lib`; with a multi-config generator (Visual Studio,
Xcode, Ninja Multi-Config) in a sub-folder per configuration, `<build>/bin/<CONFIG>`. A project setting
`CMAKE_RUNTIME_OUTPUT_DIRECTORY` & co. before `cs_initialize_project` keeps its own folders.

## Choosing the configuration to build

- Multi-config generators: csCMake sets `CMAKE_CONFIGURATION_TYPES` to the configurations of the project; the build
  preset (or `cmake --build --config <config>`) chooses one.
- Single-config generators (Ninja, Makefiles): the configure preset sets `CMAKE_BUILD_TYPE`; a configuration the project
  does not list fails the configure (`request to build with config ... which is not supported by this project`).

The csCMake presets have a build, install, test and workflow preset for Debug, Release, RelWithDebInfo and Paranoid:
use the ones of the configurations of the project.

## MSVC runtime library

The MSVC runtime of each configuration is the cache variable
`CSCMAKE_MSVC_RUNTIME_LIBRARY_<CONFIG>` (a value of CMake's `MSVC_RUNTIME_LIBRARY`):
`MultiThreadedDebugDLL` for Debug, `MultiThreadedDLL` for Release and RelWithDebInfo; a custom configuration copies the
one of the configuration it is based on. For the static runtime, for example:

```bash
cmake --preset <preset> -DCSCMAKE_MSVC_RUNTIME_LIBRARY_DEBUG=MultiThreadedDebug \
      -DCSCMAKE_MSVC_RUNTIME_LIBRARY_RELEASE=MultiThreaded -DCSCMAKE_MSVC_RUNTIME_LIBRARY_RELWITHDEBINFO=MultiThreaded
```

or the same values in the `cacheVariables` of a preset of the project. Every library linked into one executable (the
packages of the workspace and the third-party ones) must use the same runtime: build them all with the same values.

## Several projects in one build

When csCMake projects are nested (`add_subdirectory`, see [Dependencies](dependencies.md)), the configurations belong to
the build: the first project defines them. A nested project lists some of them, each defined the same way (same
mapping, same base and postfix); a configuration the build does not have, or defines differently, fails the configure.
