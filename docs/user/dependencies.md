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

## Checks on the packages found

Each time csCMake finds a package (`cs_find_package`, and the installed `<namespace>Config.cmake` of a csCMake package
for each of its dependencies), it runs `cs_after_find_dependency(<package>)`:

1. the checks of every package: the **macOS deployment target** the package recorded must not be newer than the one
   of the project ([below](#macos-deployment-target));
2. the **hooks** registered for that package name: the checks only that library needs (e.g. Qt, below).

A plain `find_package` runs none of them: find the packages with `cs_find_package`.

### macOS deployment target

`CMAKE_OSX_DEPLOYMENT_TARGET` is the oldest macOS the binaries run on. CMake fixes it when `project()` sets up the
compilers, so it is set **before** `project()`. csCMake sets no value of its own: each project declares its minimum,
at least the value of the packages it uses (e.g. `14.4` with Qt 6.12). Without a value, the binaries are built for the
macOS of the build machine and do not start on an older one (a warning on macOS).

**A csCMake project** declares it in its top-level `CMakeLists.txt`, with `csCMakeSetup` (the part of csCMake used
before `project()`):

```cmake
cmake_minimum_required(VERSION 3.31)
include(csCMakeSetup)
cs_macos_deployment_target(14.4)
project(myApp VERSION 1.0.0 LANGUAGES CXX)
include(csCMake)
cs_initialize_project(NAMESPACE myApp CXX_STANDARD 20 DEFAULT_CONFIG Debug Release)
```

- The build may raise it, never lower it: `-DCMAKE_OSX_DEPLOYMENT_TARGET=15` (or a preset, or the
  `MACOSX_DEPLOYMENT_TARGET` environment variable) builds for macOS 15; `13.3` fails the configure.
- Called after `project()`, it fails; in a project added with `add_subdirectory` to another one, it checks that the
  build (the value of the top-level project) is that version or newer.
- Nothing on Linux and Windows.

**A project without csCMake** built with the csCMake presets (a third-party library, e.g. a fork of cpptrace) cannot
call it: it sets the value in the `cscmake-project-setup-macos` preset of its `csCMakeProjectSetup.json`, with the
script that records it (below), see [Presets](presets.md#values-of-a-project-without-cscmake).

**Recorded and checked:**

- **Recorded**: `cs_initialize_project` installs the value in `<prefix>/share/cscmake/<project>.macos-deployment-target`
  (a project without csCMake: the script of its preset, the same file).
- **Checked**: each package found (`cs_find_package`, and the dependencies of csCMake packages) built for a newer macOS
  than the project fails the configure, with the value to raise to; an older one is fine. A package without the file
  is not checked (`--log-level=VERBOSE` says so).
- **Qt** has its minimum in its package (`QT_SUPPORTED_MIN_MACOS_VERSION`): the hook of csQt for `Qt6` checks it. Qt
  loaded without that check (a plain `find_package(Qt6)`, or a package not made by csCMake that finds it) fails at the
  end of the project; `-DCSCMAKE_QT_ALLOW_FIND_PACKAGE=ON`: a warning instead, and the check is done anyway.
- `cs_require_macos_deployment_target(<version> REASON <text>)`: the same check, for a need of the project itself.

### Hooks: checks for one library

A library with special needs gets a hook: a function called with the package name each time csCMake finds that
package, in the scope of the find (the variables of the package are visible):

```cmake
function(_cs_mylib_after_find package)
  cs_require_macos_deployment_target("${MYLIB_MIN_MACOS}" REASON "MyLib ${MyLib_VERSION}")
endfunction()
cs_add_after_find_hook(MyLib _cs_mylib_after_find)
```

- **Where**: a library used by several projects: an integration module of csCMake,
  `modules/integrations/cs<Lib>.cmake`, included by `csCMake.cmake` (as `csQt.cmake`, `csOpenMP.cmake`); a need of
  one project only: in that project, before its `cs_find_package`.
- **Register before the find**: a hook registered after the package is found does not run for that find.
- **The function**: a function, not a macro; it reads the variables of the package and sets nothing in the caller;
  it fails with `message(FATAL_ERROR ...)` saying what to change in the project. The hooks of a package run in the
  order they are registered, after the checks of every package.
- **Enforcing the hook** (optional): a plain `find_package` runs no hook. An integration that must not be bypassed
  marks the package as checked in its hook (a global property) and fails at the end of the project when the package
  is loaded but not checked, with a way out (a `CSCMAKE_<LIB>_ALLOW_FIND_PACKAGE` cache variable): see
  `_cs_qt_after_find` and `_cs_qt_check_found_with_cscmake` in `csQt.cmake`, called by `_cs_finalize_project`.
- **Test**: a configure test with a stand-in of the package (a `<Package>Config.cmake` setting the variables the hook
  reads), as `tests/cmake/test_macos_deployment_target.py`.

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
