---
name: cscmake-usage
description: Using csCMake in a C++ project (a CMakeLists.txt with include(csCMake), cs_initialize_project, cs_add_library, cs_target_sources, cs_find_package, cs_install_target, cs_deployment, CMakePresets.json including csCMake/presets/csv1, csCMakeProjectSetup.json). Use when writing or changing such CMake files, adding a target, a dependency, a component, a build configuration, a compile profile (warnings, sanitizers, hardening, clang-tidy) or a deployment, choosing a preset or layout, or when a configure, find_package, install or deployment fails with a [cs_*] / [csCMake] message. Not for developing csCMake itself.
---

# Using csCMake

csCMake is a CMake library (`cs_*` commands) plus generated CMake presets for every platform. A project registers its
targets with the `cs_*` commands; at the end of the `CMakeLists.txt` of `cs_initialize_project` csCMake finalizes the
project: compile profiles, dependencies between components, install rules, the generated `<namespace>Config.cmake`.

Documentation (latest release): <https://cscosine.github.io/csCMake/>; the same pages as Markdown:
<https://github.com/cscosine/csCMake/tree/main/docs>. The command reference is in the `#.rst:` block above each
command in `modules/*.cmake`. When a detail is not below, read the page instead of guessing.

## The files of a project

```cmake
# CMakeLists.txt (top level)
cmake_minimum_required(VERSION 3.31)
include(csCMakeSetup)                 # before project(): only for cs_macos_deployment_target
cs_macos_deployment_target(14.4)      # oldest macOS the binaries run on; raise it to the max of the packages used
project(myApp VERSION 1.0.0 LANGUAGES CXX)   # VERSION is required (it is the package version)
include(csCMake)
cs_initialize_project(NAMESPACE myApp CXX_STANDARD 20 DEFAULT_CONFIG Debug Release)
add_subdirectory(myApp)

# myApp/CMakeLists.txt
cs_add_library(core STATIC)
cs_target_sources(core PRIVATE core/Greeting.cpp PRIVATE_INSTALL core/Greeting.hpp)
cs_target_link_libraries(core PUBLIC myApp::cscmake_base_include)   # the include folder of the project
cs_install_target(core COMPONENT core DEFAULT)
cs_add_executable(app main.cpp)
cs_target_link_libraries(app PRIVATE core)
cs_install_target(app COMPONENT app)
cs_deployment(app TARGETS app)        # optional: a folder that runs on another machine
```

`CMakePresets.json` includes `<csCMake>/presets/csv1/cs-presets-all.json`; `csCMakeProjectSetup.json` (same folder)
includes one layout, `<csCMake>/presets/layout/<layout>.json`. The `<csCMake>` path depends on the layout:

| Layout | Workspace / csCMake | Path in both files |
|---|---|---|
| `sibling` | parent folder of the project / `<workspace>/csCMake` | `${sourceParentDir}/csCMake/...` |
| `standalone` (what csorchestrator projects use) | `<project>/workspace` / `<workspace>/csCMake` | `${sourceDir}/workspace/csCMake/...` |
| `env` | env `CSCMAKE_WORKSPACE_ROOT` / env `CSCMAKE_ROOT` | `$penv{CSCMAKE_ROOT}/...` |

`*-short` variants of each: short build folder names (Visual Studio, 260-character paths). Project values in the
presets (cache variables, per OS values, own folders): the levels of
[Presets: choosing the project setup](https://cscosine.github.io/csCMake/user/presets.html), lowest level that fits.

## Which command for what

| Need | Use | Not |
|---|---|---|
| a library / executable | `cs_add_library`, `cs_add_executable` (same arguments as CMake) | `add_library`: not registered, not finalized |
| sources; headers to install | `cs_target_sources(t PRIVATE a.cpp PRIVATE_INSTALL a.hpp)` | `install(FILES ...)` |
| include `<myApp/core/x.hpp>` | link `<namespace>::cscmake_base_include` (headers are included by their path from the project folder) | `target_include_directories` |
| a package dependency | `cs_find_package(<target> PUBLIC\|PRIVATE <find_package args>)` after the target exists | plain `find_package`: not propagated, no checks (macOS target, Qt) |
| install into a component | `cs_install_target(t COMPONENT c [DEFAULT])` | |
| use another csCMake package | `cs_find_package(t PUBLIC myLib COMPONENTS core REQUIRED CONFIG)`, link `myLib::core` | |
| a library developed together | `add_subdirectory(../myLib myLib)` (nested csCMake project, own namespace) | |
| warnings, sanitizers, hardening, clang-tidy | `DEFAULT_COMPILE_PROFILES` of `cs_initialize_project`, `cs_target_use_compile_profiles`, own profiles with `cs_add_compile_profile_rule` | `target_compile_options` for those |
| looser tests / samples | `set(CSCMAKE_DEFAULT_COMPILE_PROFILES ...)` in their folder before their targets | |
| every installed header compiles alone | `cs_target_check_installed_headers(t)` | |
| OpenMP | `cs_target_use_openmp(t PUBLIC)` | |
| ship an app folder | `cs_deployment(name TARGETS ... [FILES ... DESTINATION ...] [PLUGINS ... DESTINATION ...] [CONFIGS ...])`; Qt GUI: `cs_deployment_qt_gui` | copying DLLs by hand |
| run-time paths / env CMake cannot know | `cs_target_runtime_environment(t PATH ... SET VAR=value)` | |
| generated headers | `cs_get_generated_dir`, `cs_get_generated_config_dir` (already include folders) | |

PUBLIC vs PRIVATE in `cs_find_package`: `PUBLIC` = part of the interface, the installed `<namespace>Config.cmake`
calls `find_dependency` for it; `PRIVATE` = build only (test framework, private link into an executable).

## Build configurations

```cmake
cs_initialize_project(
  NAMESPACE myApp CXX_STANDARD 20
  DEFAULT_CONFIG Debug Release
  DEFAULT_CONFIG_MAPPED RelWithDebInfo MAPPED_TO "RelWithDebInfo,Release,"   # links a dependency's RelWithDebInfo, else Release
  CUSTOM_CONFIG Paranoid BASED_ON "Debug,Release," POSTFIX "dp")             # a copy of Debug, own postfix
```

- Postfixes: Debug `d`, Release none, RelWithDebInfo `rd`, custom: its `POSTFIX`. All configurations install side by
  side in one prefix (headers in `include/<CONFIG>/` when there are several).
- `BASED_ON` must name a `DEFAULT_CONFIG` of the project. Use only presets of configurations the project lists.
- Nested projects: the first project of the build defines the configurations; a nested one may list a subset, defined
  identically.
- A consumer configuration the package lacks (e.g. `MinSizeRel` in Visual Studio / Xcode):
  `-DCMAKE_MAP_IMPORTED_CONFIG_MINSIZEREL=Release`.

## Compile profiles

Shipped: `cscmake_default` (the default), `cscmake_warnings`, `cscmake_warnings_as_errors`,
`cscmake_strict_warnings` (= both), `cscmake_sanitize_undefined`, `cscmake_sanitize_address`,
`cscmake_hardening_fast`, `cscmake_hardening_debug`, `cscmake_clang_tidy`. A project defines its own policy profile
from them, by configuration / compiler / platform:

```cmake
cs_add_compile_profile_rule(PROFILE myApp_policy PROFILES cscmake_default cscmake_strict_warnings)
cs_add_compile_profile_rule(PROFILE myApp_policy CONFIGS Debug Paranoid PROFILES cscmake_hardening_debug)
cs_add_compile_profile_rule(PROFILE myApp_policy CONFIGS Paranoid PROFILES cscmake_sanitize_undefined cscmake_sanitize_address)
cs_initialize_project(... DEFAULT_COMPILE_PROFILES myApp_policy)
```

Options and definitions stay private to the target; link options of static / object libraries propagate (sanitizer
runtimes). Conditions: `CONFIGS`, `COMPILERS` (`CMAKE_CXX_COMPILER_ID`), `FRONTENDS` (`GNU` / `MSVC`), `PLATFORMS`,
`LANGUAGES` (default `CXX`). clang-tidy does not run with Visual Studio or Xcode generators.

## Presets and building

Name: `csv1-<os>-<os version>-<arch>-generic-<compiler>-<compiler version>-<generator>`, e.g.
`csv1-linux-ubuntu24.04-x64-generic-gcc-default-ninjamulticonfig`. `cmake --list-presets` shows the ones of the
machine.

| Generator | Configure | Build / install / test | Workflow |
|---|---|---|---|
| multi-config (`ninjamulticonfig`, `msvc2022`, `msvc2026`, `xcode`) | `<variant>` | `build-<variant>-<config>`, `install-...`, `test-...` | `workflow-<variant>-<config>`, `-debug-release`, `-debug-release-relWithDebInfo-paranoid` |
| single-config (`ninja`) | `<variant>-<config>` | same | `workflow-<variant>-<config>` |

`<config>`: `debug`, `release`, `relWithDebInfo`, `paranoid`. A workflow preset configures, builds, installs, tests:

```bash
cmake --workflow --preset workflow-csv1-linux-ubuntu24.04-x64-generic-gcc-default-ninjamulticonfig-debug-release
```

Folders, under the workspace: `build/<variant>/<project>/`, `install/<variant>/<project>/`,
`deploy/<variant>/<project>/<deployment>-<config>/`. `CMAKE_PREFIX_PATH` has `install/<variant>` and
`libs/<variant>`, so **a project folder must be named like its package (namespace)** or `find_package` misses it.
Deployments are made by the install (Release by default), checked to run on their own; alone:
`cmake --build --preset <build preset> --target cs_deploy_<name>`. Windows terminal environment: `call cs-env.bat
[<config>]` in the build folder.

## Pitfalls

- `cs_find_package` and `cs_target_*` need the target to exist: create it first.
- Every link must be made inside the target's own project: a link from a parent project after it is finalized fails.
- `cs_macos_deployment_target` goes before `project()`; it can only be raised by the build, never lowered. A package
  built for a newer macOS than the project fails the configure: raise the project's value.
- Qt must be found with `cs_find_package` (its macOS check); a plain `find_package(Qt6)` fails at the end of the
  project unless `-DCSCMAKE_QT_ALLOW_FIND_PACKAGE=ON`.
- Component dependencies come from the links; a cycle between components fails the finalize: move targets.
- MSVC runtime is per configuration (`CSCMAKE_MSVC_RUNTIME_LIBRARY_<CONFIG>`); everything linked into one executable
  must use the same one.
- Formatting: gersemi with the csCMake signatures and `cscmake-lint` (rules `CS101`–`CS108`: lowercase names,
  a comment above each function, ≤ 120 columns, ...) come from the `cs-pre-commit-hooks` hooks; run
  `pre-commit run --all-files`.

## When something is wrong

- `cmake --preset <preset> --log-level=VERBOSE` (or `DEBUG`) shows what csCMake does: targets, components, packages
  found, profiles, dependencies. `--log-context` prefixes each line with the command.
- `cs_print_target(<target>)` / `cs_print_project()` anywhere in the project print everything csCMake knows after
  the finalize; remove them afterwards.
- Every csCMake error starts with the reporting command (`[cs_initialize_project] ...`, `[csCMake] ...` at the
  finalize): look it up in [Troubleshooting](https://cscosine.github.io/csCMake/user/troubleshooting.html), which
  lists each message with its fix.
