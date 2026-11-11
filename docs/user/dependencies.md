# Dependencies

A target depends on other packages (found with `find_package`) or on targets of other csCMake projects of the same
build. csCMake records both, so that the installed package finds them again for its consumers.

## Packages: `cs_find_package`

```cmake
cs_add_library(core STATIC)
cs_add_executable(myTool main.cpp)
cs_find_package(core PUBLIC fmt REQUIRED CONFIG)
cs_find_package(myTool PRIVATE GTest REQUIRED)
cs_target_link_libraries(core PUBLIC fmt::fmt)
```

`cs_find_package` calls `find_package` with the arguments after `PUBLIC` / `PRIVATE`, for a target:

- `PUBLIC`: the dependency is part of the interface of the target. The installed `<namespace>Config.cmake` calls
  `find_dependency` with the same arguments when the component of the target is loaded, so a consumer of the target
  finds the dependency without knowing about it.
- `PRIVATE`: needed to build the target only (a test framework, a library linked privately into an executable).
  Nothing is propagated.

The target must exist already (`cs_add_library` / `cs_add_executable` first): the dependency is recorded on it. It is
a macro: the variables set by `find_package` (`fmt_FOUND`, `fmt_VERSION`, ...) are visible after the call.

Packages are searched in `CMAKE_PREFIX_PATH`. With the csCMake presets it contains the install folder of the workspace,
`install/<variant>/`, and each project installs in `install/<variant>/<project folder>/`: `find_package(<name>)` looks
in the folders starting with `<name>`, so **the folder of a project must be named like its package** (its namespace).
See [Presets](presets.md#folders).

## Other csCMake projects, installed

A csCMake project installed in the workspace is a package like any other:

```cmake
cs_find_package(app PUBLIC myLib COMPONENTS core REQUIRED CONFIG)
cs_target_link_libraries(app PRIVATE myLib::core)
```

`COMPONENTS` loads the given components of the package and the components they depend on; without `COMPONENTS`, the
default ones (see [Installed packages](install.md)).

## Other csCMake projects, in the same build

A csCMake project can also be added with `add_subdirectory` to another one, e.g. a library developed together with the
application that uses it:

```cmake
# myApp/CMakeLists.txt
cs_initialize_project(NAMESPACE myApp CXX_STANDARD 20 DEFAULT_CONFIG Debug Release)
add_subdirectory(../myLib myLib)      # a csCMake project too, finalized at the end of its CMakeLists.txt
add_subdirectory(app)                 # links myLib::core
```

- Each project keeps its own namespace, targets, components and installed package.
- The build configurations belong to the build: the first csCMake project defines them; a nested project lists some
  of them, defined the same way, or the configure fails (see [Build configurations](build-configurations.md#several-projects-in-one-build)).
- A target linking a target of the other project makes its component `find_dependency` that package in the installed
  `<namespace>Config.cmake`, as if it had been found with `cs_find_package(... PUBLIC ...)`.

## Runtime dependencies

When the project is finalized, each executable and shared library gets a Visual Studio debugger environment whose
`PATH` contains the folders of the DLLs it needs, per configuration (CMake's `$<TARGET_RUNTIME_DLL_DIRS>`), so running
or debugging it from Visual Studio finds them. Nothing to write for that.

What CMake cannot know, a project adds with `cs_target_runtime_environment`: folders of plugins or of libraries loaded
at run time, and variables the program reads (e.g. Qt's plugin folder):

```cmake
cs_target_runtime_environment(app PATH "${MYSDK_ROOT}/bin" SET "QT_PLUGIN_PATH=${QT_ROOT}/plugins")
```

### Running from a terminal on Windows: `cs-env.bat`, `cs-env.ps1`

Outside Visual Studio, the same environment comes from two scripts csCMake writes in the top build folder (next to the
`.sln`), one pair for the whole build: `PATH` with the folders of every executable and shared library of the csCMake
projects of the build, and their variables.

| | |
|---|---|
| double-click `cs-env.bat` | a command prompt with the environment |
| `call cs-env.bat [<config>]` | from a command prompt: the environment in that command prompt |
| `cs-env.bat [<config>] -ps` | a PowerShell with the environment |
| `.\cs-env.ps1 [<config>]` | from PowerShell: the environment in that PowerShell |

```bat
C:\ws\build\myApp> call cs-env.bat Debug
csCMake run-time environment: Debug
C:\ws\build\myApp> bin\Debug\app.exe
```

- `<config>`: not needed when the build has one configuration, or when every configuration gives the same environment;
  otherwise the scripts list the configurations and ask for one (a double-click asks in the window). With
  Visual Studio, a project with DLLs of its own needs it: they are in `bin/<config>`.
- Your own additions: `cs-env.local.bat` / `cs-env.local.ps1` next to them, run last with the configuration as argument;
  csCMake never writes them.
- One value per variable for the whole build: two targets setting the same variable to different values fail the
  configure.
- PowerShell runs a local script with the execution policy `RemoteSigned` (or `Unrestricted`, `Bypass`): e.g.
  `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.
- Written on Windows only (Linux and macOS run the build folder through the RPATH); `-DCSCMAKE_RUNTIME_SCRIPTS=OFF`
  turns them off, `ON` writes them on any platform.

See [Runtime dependencies](../advanced/runtime-dependencies.md).
