# Lifecycle of a project

What csCMake does, and when, from `include(csCMake)` to the end of the configure. The user guide says what to call;
this page says what happens.

```mermaid
flowchart TD
    inc["include(csCMake)<br/>modules, cache defaults, shipped compile profiles"] --> init
    init["cs_initialize_project<br/>namespace, configurations, folders, standard,<br/>default target, deferred finalization"] --> targets
    targets["cs_add_library / cs_add_executable<br/>register the target: postfixes, runtime,<br/>default compile profiles, install RPATH"] --> targets
    targets --> fin
    fin["end of the CMakeLists.txt (deferred)<br/>compile profiles, dependencies,<br/>components, Config"]
```

## `include(csCMake)`

- Fails on a CMake older than 3.31.
- Runs between `cmake_policy(PUSH)` / `cmake_policy(VERSION 3.31)` / `cmake_policy(POP)`: every csCMake function and
  macro records the 3.31 policies where it is defined, whatever the including project declares.
- Includes the modules of `modules/` (each once: `include_guard(GLOBAL)`), which define the cache defaults (postfixes and
  MSVC runtime of the CMake configurations, [build configurations](../user/build-configurations.md)) and register
  the compile profiles shipped with csCMake.
- Records the csCMake folder (`CSCMAKE_ROOT_DIR`): a second csCMake folder in the same build fails.

Nothing is project-specific yet: a build tree can include csCMake once and hold several csCMake projects.

## `cs_initialize_project`

A macro, so that what it sets belongs to the scope of the project folder (and is inherited by its sub-folders). In
order:

1. checks that `project()` has a `VERSION`;
2. `CSCMAKE_SOURCE_DIR`: the project folder, base of the include paths and of the installed headers;
3. normalizes the search paths and the install prefix;
4. the output folders `<build>/bin` and `<build>/lib` (`/<CONFIG>` with multi-config generators), unless set;
5. collects the CMake variables with a `<CONFIG>` part, once per build tree (`cmake --help-variable-list`): a custom
   configuration copies the ones defined for its base (the flags of the languages enabled so far);
6. parses the arguments: namespace (`CSCMAKE_NAMESPACE`), C++ standard, default compile profiles, and
   the configurations, added to the build, or, in a nested project, checked against the build;
7. sets in the project scope the variables computed by the functions called so far (see
   [project scope](#project-scope)): imported configuration mapping, postfixes, MSVC runtime, output folders of the
   custom configurations;
8. `CMAKE_CXX_STANDARD`; `CMAKE_CXX_STANDARD_REQUIRED` `ON` and `CMAKE_CXX_EXTENSIONS` `OFF` unless the project set them;
9. the configurations of the build: `CMAKE_CONFIGURATION_TYPES` with a multi-config generator; with a single-config
   one, fails if `CMAKE_BUILD_TYPE` is not one of them;
10. adds `CSCMAKE_PREFIX_PATH_HEAD` / `_TAIL` and the module path ones around `CMAKE_PREFIX_PATH` /
    `CMAKE_MODULE_PATH`;
11. `enable_testing()`; with Ninja, `CMAKE_EXPORT_COMPILE_COMMANDS` `ON` unless set (`-D...=OFF`, or the environment
    variable of the same name);
12. reports the project (`VERBOSE`: one line; `DEBUG`: its configurations);
13. creates the default target `<namespace>::cscmake_base_include` (and its include folders, created on disk);
14. defers the [finalization](#finalization) of the project to the end of the current `CMakeLists.txt`
    (`cmake_language(DEFER)`).

### What reaches beyond the csCMake targets

csCMake changes only what its own targets need, or what the project asks for (see
[Contributing to csCMake](../contributing/code.md#cmake-conventions)). The settings that reach further, and why:

| Setting | Reaches | Why |
|---|---|---|
| output folders `<build>/bin`, `<build>/lib` | every target of the project folder, third-party projects added with `add_subdirectory` included | on Windows, the DLLs are found next to the executables; kept when the project set them |
| `CMAKE_CXX_STANDARD`, `_REQUIRED`, `CMAKE_CXX_EXTENSIONS` | every target of the project folder | `CXX_STANDARD` of the project; `_REQUIRED` and `_EXTENSIONS` kept when the project set them |
| `CMAKE_MSVC_RUNTIME_LIBRARY` | the targets of the folder not created by `cs_add_*` | every target of a build must use the same MSVC runtime to link; set with `CSCMAKE_MSVC_RUNTIME_LIBRARY_<CONFIG>` |
| `CMAKE_MAP_IMPORTED_CONFIG_<CONFIG>` | every imported target of the folder | the configurations of imported targets to use (`MAPPED_TO`, `BASED_ON`): needed for the custom configurations |
| `CMAKE_CONFIGURATION_TYPES` | the build | the configurations of the first csCMake project (multi-config generators) |
| `CMAKE_EXPORT_COMPILE_COMMANDS` | the build folder | `compile_commands.json` for the editors (Ninja); kept when set |
| `enable_testing()` | the project folder | the tests of the project run with ctest |

The installed `<namespace>Config.cmake` defines, in the consumer, only names prefixed by the namespace, and unsets its
temporaries; its messages use the consumer's log level (`VERBOSE`, `DEBUG`).

### Project scope

Functions have their own scope: a variable they set is lost when they return. The functions called by
`cs_initialize_project` record the variables meant for the project with `_cs_set_in_project_scope(<name> <value>)`
(global properties); `cs_initialize_project`, a macro running in the project scope, sets them all with
`_cs_apply_project_scope_variables()`. This keeps the logic in functions (local variables, early `return()`) while
the results land where `project()` variables do.

## Targets

`cs_add_library` / `cs_add_executable` call `add_library` / `add_executable`, then register the target (aliases
excepted): `CSCMAKE_<namespace>_PROJECT_TARGETS`, the namespace on the target
(`CSCMAKE_NAMESPACE`), `<CONFIG>_POSTFIX` for each configuration and `MSVC_RUNTIME_LIBRARY`. They also take the values
of the folder variables the finalization needs, as CMake does with its own `CMAKE_<X>` variables:
`CSCMAKE_COMPILE_PROFILES` starts with `CSCMAKE_DEFAULT_COMPILE_PROFILES`, and the install RPATH is set from
`CSCMAKE_INSTALL_RPATH` and the install folders (a value the project sets on the target afterwards replaces it). The
finalization runs in the project folder and reads target properties only, so what a sub-folder sets still counts.
Creating a target before `cs_initialize_project` fails (the postfixes do not exist yet).

## Finalization

At the end of the `CMakeLists.txt` of `cs_initialize_project`, the call deferred at step 14 runs, in the scope of the
project folder (nested projects: each at the end of its own `CMakeLists.txt`, before the outer project goes on):

1. Marks the namespace finalized (`_CSCMAKE_PROJECT_FINALIZED_<namespace>`): `cs_target_link_libraries` and
   `cs_target_runtime_environment` fail afterwards.
2. Applies the compile profiles of every target of the project, and marks it finalized (`_CSCMAKE_FINALIZED`).
3. Resolves the targets of the build each target depends on, and the Visual Studio debugger environment (see
   [Runtime dependencies](runtime-dependencies.md)).
4. Installs the components: the export of each one, the dependencies between them (cycles fail, then sorted), the
   generated `<namespace>Config.cmake` and `<namespace>ConfigVersion.cmake` (see
   [Installed packages internals](packages.md)).
5. Prints the project (`DEBUG` log level).

Deferred calls run in the order they were deferred: `cs_print_target` / `cs_print_project` called in the project defer
themselves after the finalization, so they print the targets as built.
