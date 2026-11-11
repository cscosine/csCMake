# Troubleshooting

The errors csCMake reports, what they mean and what to do. Every csCMake message starts with the command that
reports it, e.g. `[cs_finalize_project]`.

To see what csCMake does for a project, configure it with `-D<project>_CSCMAKE_DEBUG=ON` (`<project>` is the
`project()` name of `cs_initialize_project`); for an installed package being loaded, `-D<namespace>_DEBUG=ON`.

## Inspecting a target or the project

Two commands print what csCMake knows, whatever the debug switch; call them at the end of the `CMakeLists.txt` of the
project, after `cs_finalize_project` (some values are resolved there), and remove them afterwards:

- `cs_print_target(<target>)`: a target does not build, link, install or run as expected. It prints its type, its
  component, the headers it installs, the packages it finds for its consumers, its compile profiles, its run-time
  environment (`cs_target_runtime_environment`), the targets of the project it depends on, then every CMake property
  set on it (`INTERFACE_INCLUDE_DIRECTORIES`, `INSTALL_RPATH`, `VS_DEBUGGER_ENVIRONMENT`, ...).
- `cs_print_project()`: the configurations, the search paths or the components are not the expected ones. It prints the
  configurations (postfix, C++ flags, MSVC runtime of each), the search paths, the install prefix, the targets, and
  each component with its targets, the packages it finds and the components it depends on.

```cmake
cs_finalize_project()
cs_print_target(myLib)
cs_print_project()
```

## Setting up

`include could not find requested file: csCMake`
: csCMake is not in `CMAKE_MODULE_PATH`. With the presets, check the layout of `csCMakeProjectSetup.json` and where
  csCMake is (see [Presets](presets.md#layouts)); without them, add `-DCMAKE_MODULE_PATH=<csCMake folder>`.

`csCMake requires CMake 3.31 or newer`
: Update CMake.

`[_cs_set_root_dir] csCMake has been included multiple times with different base paths`
: Two copies of csCMake are used in one build, e.g. a nested project finding another clone. Use one csCMake for the
  whole build.

`[cs_initialize_project] project(<name> VERSION <x.y.z> ...) is required`
: `project()` has no `VERSION`: it is the version of the installed package (`<namespace>ConfigVersion.cmake`).

`[cs_initialize_project] NAMESPACE <namespace> is required`, `CXX_STANDARD <standard> is required`, `unparsed arguments`
: See the arguments of `cs_initialize_project`; `MIGRATION.md` maps the arguments of older versions.

`[cs_add_library / cs_add_executable] <target>: call cs_initialize_project(NAMESPACE ...) before adding targets`
: A target is created before `cs_initialize_project`, or in a folder outside the project.

## Build configurations

`[cs_initialize_project] CMAKE_BUILD_TYPE <config> is not a configuration of the project (<configs>)`
: A single-config preset (or `CMAKE_BUILD_TYPE`) asks for a configuration the project does not list. Use the presets of
  the configurations of the project, or add the configuration to `cs_initialize_project`.

`[cs_initialize_project] CMAKE_BUILD_TYPE is empty: a single-config generator builds one configuration of the project`
: The project is configured without a preset and without `-DCMAKE_BUILD_TYPE=<config>` (Ninja, Makefiles). Use a
  preset, or give one of the configurations listed in the message.

`[cs_initialize_project] configuration <config> of <namespace> is not a configuration of the build`, `... is '<definition>', in the build it is '<definition>'`
: A nested csCMake project lists a configuration the first project of the build does not have, or defines it
  differently. See [Build configurations](build-configurations.md#several-projects-in-one-build).

`DEFAULT_CONFIG_MAPPED need to specify values as ...`, `CUSTOM_CONFIG need to specify values as ...`
: The form is `DEFAULT_CONFIG_MAPPED <config> MAPPED_TO "<config>,<fallback>,"` and
  `CUSTOM_CONFIG <name> BASED_ON "<config>,<fallback>," POSTFIX "<postfix>"`.

## Finalizing

`[cs_initialize_project] cs_finalize_project() is required at the end of <folder>/CMakeLists.txt`
: Add `cs_finalize_project()` at the end of the `CMakeLists.txt` that calls `cs_initialize_project`.

`[cs_finalize_project] cs_finalize_target(<target>) is required for every target, after its links: missing for <targets>`
: Every target of `cs_add_library` / `cs_add_executable` needs `cs_finalize_target`, tests and tools included.

`[cs_target_link_libraries] <target>: links after cs_finalize_target(<target>)`,
`[cs_finalize_project] links added after cs_finalize_target: <targets>`
: Move `cs_finalize_target` after the last `cs_target_link_libraries` (or `target_link_libraries`) of these targets.

`[cs_finalize_project] takes no arguments`
: The namespace is given to `cs_initialize_project(NAMESPACE ...)` only.

`[_cs_check_component_cycles_recursive] detected cyclic dependency: <components>`
: The targets of these components link each other in a cycle: move the targets so that the components depend on each
  other in one direction.

## Compile profiles

`[cs_finalize_target] compile profile <profile> of <target> is not defined`
: The profile has no rule: check its name, and that its `cs_add_compile_profile_rule` calls run before the target is
  finalized.

`[cs_finalize_target] clang-tidy is required: the compile profiles of <target> run it in this build`
: Install clang-tidy, or give its path with `-DCSCMAKE_CLANG_TIDY_EXE=<path>`; or restrict the `CLANG_TIDY` rule to the
  compilers and platforms where it is available.

`[csCMake] clang-tidy (compile profiles) is not run with the <generator> generator`
: A warning: Visual Studio and Xcode do not run clang-tidy. Use a Ninja preset to run it.

## Installed packages

`find_package(<name>)` does not find a package of the workspace
: Check that it is installed for the same variant (`install/<variant>/`), and that its project folder is named like the
  package (see [Presets](presets.md#folders)).

`Visual Studio: path too long`, files not found in deep build folders
: Use a `*-short` layout: short build folder names (see [Presets](presets.md#layouts)).
