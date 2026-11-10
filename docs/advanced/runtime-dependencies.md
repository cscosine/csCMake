# Runtime dependencies

csCMake works out, for every target of a project and every configuration, the shared libraries it needs at run time:
the libraries of the imported targets it links, directly or through other targets. They give the Visual Studio
debugger environment of the targets, and the dependencies between the components of the installed package.

It runs in two phases: each target is walked when it is finalized, and the results are combined when the project is
finalized, once every target exists.

## Walking a target: `cs_finalize_target`

Starting from the target, csCMake visits every library it links, breadth first, through all the link properties:
`LINK_LIBRARIES`, `INTERFACE_LINK_LIBRARIES`, `LINK_INTERFACE_LIBRARIES`, `IMPORTED_LINK_INTERFACE_LIBRARIES`, and
their per-configuration forms, `INTERFACE_LINK_DEPENDS`. Aliases are resolved. Each name visited is recorded on the
target:

| The name is | Recorded in | Then |
|---|---|---|
| a target of the build, not imported | `CSCMAKE_LINKED_PROJECT_TARGETS` | its links are visited too |
| an imported shared, module or interface library | `CSCMAKE_DIRECT_RUNTIME_LIBRARIES_<CONFIG>`: its file for each configuration (`IMPORTED_LOCATION_<CONFIG>`, else `IMPORTED_LOCATION`), when it exists | its links are visited too |
| another imported target (static) | — | its links are visited too |
| not a target (yet) | `CSCMAKE_LINKED_NON_TARGETS` | resolved at the project level |

A file that does not exist is not recorded, with a warning: the package is usually installed without that
configuration.

A target linked before it is defined (a link by name to a target of a later folder) is not a target yet when the
linking target is finalized: it is kept as a name and resolved at the end.

## Combining: `cs_finalize_project`

For every target of the project:

1. its runtime libraries (`CSCMAKE_RUNTIME_LIBRARIES_<CONFIG>`) start as its direct ones;
2. its *project dependencies* (`CSCMAKE_PROJECT_DEPENDENCIES`) are the recorded project targets plus the
   recorded names that are targets now (aliases resolved); they are also its pending dependencies
   (`_CSCMAKE_PENDING_DEPENDENCIES`).

Then, until no target has pending dependencies, each target takes the runtime libraries of its pending dependencies that
have none left, and keeps the others pending. The result: every target lists the shared libraries of its whole
dependency tree, per configuration (`cs_get_target_runtime_libraries`).

The libraries built by the project itself are not listed: they are written to the output folders of the build
(`<build>/bin`), next to the executables.

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

- **Visual Studio debugger environment**: for each target and configuration with runtime libraries,
  `VS_DEBUGGER_ENVIRONMENT` is `PATH=<the folders of its runtime libraries>;%PATH%` (Visual Studio expands `%PATH%`: the
  rest of the environment is kept), so running or debugging the target from Visual Studio finds the DLLs
  of its dependencies.
- **Component dependencies**: the project dependencies of the targets of a component give the components it depends
  on, and the other csCMake packages of the build it needs (see [Installed packages internals](packages.md)).
