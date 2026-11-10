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
add_subdirectory(../myLib myLib)      # a csCMake project too: cs_initialize_project ... cs_finalize_project
add_subdirectory(app)                 # links myLib::core
cs_finalize_project()
```

- Each project keeps its own namespace, targets, components, debug option and installed package.
- The build configurations belong to the build: the first csCMake project defines them; a nested project lists some
  of them, defined the same way, or the configure fails (see [Build configurations](build-configurations.md#several-projects-in-one-build)).
- A target linking a target of the other project makes its component `find_dependency` that package in the installed
  `<namespace>Config.cmake`, as if it had been found with `cs_find_package(... PUBLIC ...)`.

## Runtime dependencies

When the project is finalized, csCMake walks the links of every target and collects the shared libraries it needs at
run time, per configuration, also through other targets
(`cs_get_target_runtime_libraries`). With the Visual Studio generators, each target gets a debugger
environment whose `PATH` contains the folders of those libraries, so running or debugging it from Visual Studio finds
its DLLs.
