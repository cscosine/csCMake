# Runtime dependencies

When the project is finalized (`cs_finalize_project`), every target exists, and csCMake resolves for each target of
the project:

- its **project dependencies** (`CSCMAKE_PROJECT_DEPENDENCIES`): the targets of the build (not imported) it links,
  directly or through other such targets. They give the dependencies between the components of the installed package;
- its **Visual Studio debugger environment**: the folders of the DLLs it needs, from CMake itself.

## Project dependencies

Starting from the target, csCMake visits the links of each target of the build it reaches: `LINK_LIBRARIES` and
`INTERFACE_LINK_LIBRARIES`. A link item is followed when it names a target of the build that is not imported, after
resolving aliases and unwrapping `$<LINK_ONLY:...>` (what CMake writes for the private links of a static library).
Imported targets, library files and names, and other generator expressions are not followed: they do not belong to
the components of the package. The order of the links does not matter: a target can link a target of a later folder.

## The DLLs of a target

CMake knows the DLLs a target needs: `$<TARGET_RUNTIME_DLLS:tgt>` and the folders `$<TARGET_RUNTIME_DLL_DIRS:tgt>`
(the shared libraries of every target it links, directly or not, imported or not). It evaluates them at generate time,
per configuration, with the configuration it selects for each imported target (`CMAKE_MAP_IMPORTED_CONFIG_<CONFIG>`):
a package installed in Release only gives its DLLs to a Debug build, and a custom configuration mapped to Debug gets
the Debug ones. On platforms without DLLs (Linux, macOS) they are empty: executables find their shared libraries
through the RPATH.

## Running the executables

Where an executable finds its shared libraries:

| | Linux, macOS | Windows |
|---|---|---|
| build folder | the absolute folders of every linked library (build RPATH written by CMake) | its own folder: the DLLs of the project are written to the same `<build>/bin[/<config>]`; the DLLs of other packages through `PATH` (the Visual Studio debugger gets it, see below) |
| install folder | the `lib/` of its package (install RPATH set by `cs_finalize_target`, below) | its own folder: the DLLs of the package are installed in `bin/` |

The install RPATH (`INSTALL_RPATH` target property) is relative to the binary, so the install folder can be moved:
`$ORIGIN/<bin to lib>` (`$ORIGIN/../lib` with the default folders) for an executable, `$ORIGIN` for a shared or module
library (installed next to the others); `@loader_path` instead of `$ORIGIN` on macOS. Only the targets of
`cs_add_library` / `cs_add_executable`: other targets of the build (e.g. a third-party project added with
`add_subdirectory`) and the projects using the presets without csCMake keep their own. Not set when the target has its
own `INSTALL_RPATH` (also from `CMAKE_INSTALL_RPATH`), or with `CSCMAKE_INSTALL_RPATH` `OFF`.

The shared libraries of **other** packages are not found from the install folder (an absolute path to another
package would break when the packages are moved, e.g. built on a CI machine and unpacked elsewhere): an installed
executable using them runs with `LD_LIBRARY_PATH` / `DYLD_LIBRARY_PATH` / `PATH` set to their folders. On Windows,
outside the Visual Studio debugger (ctest, a terminal), the DLLs of other packages also need `PATH` in the build folder.

## Uses

- **Visual Studio debugger environment**: for each executable and shared or module library, `VS_DEBUGGER_ENVIRONMENT`
  gets a line `PATH=<the folders of its DLLs>;%PATH%` (Visual Studio expands `%PATH%`: the rest of the environment is
  kept), none when there are no folders; running or debugging the target from Visual Studio finds the DLLs of its
  dependencies. Nothing to write in the project for that.
- **What CMake cannot know**: `cs_target_runtime_environment` adds to the run-time environment of a target. Needed only
  for libraries loaded at run time (plugins, `dlopen` / `LoadLibrary`), DLLs linked by file name instead of a target,
  tools the program starts, and variables the program reads:

  ```cmake
  cs_target_runtime_environment(app
    PATH "${MYSDK_ROOT}/bin" "$<$<CONFIG:Debug>:${PLUGINS_DIR}/debug>"
    SET "QT_PLUGIN_PATH=${QT_ROOT}/plugins")
  ```

  The `PATH` folders come first, before the DLL folders; each variable is a line of its own. Call it before
  `cs_finalize_project`, as many times as needed.
- **A `VS_DEBUGGER_ENVIRONMENT` written by the project** is kept: its lines come first. When it has a `PATH` line of its
  own, csCMake puts its folders in that line, before the project's (the default) or after them:
  `cs_target_runtime_environment(app DEBUGGER_PATH AFTER)`; `DEBUGGER_PATH OFF` leaves the debugger environment of the
  target as the project wrote it.
- **Component dependencies**: the project dependencies of the targets of a component give the components it depends
  on, and the other csCMake packages of the build it needs (see [Installed packages internals](packages.md)).
- A target linking a target of the other project makes its component `find_dependency` that package in the installed
  `<namespace>Config.cmake`, as if it had been found with `cs_find_package(... PUBLIC ...)`.
