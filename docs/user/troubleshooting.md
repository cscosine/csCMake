# Troubleshooting

The errors csCMake reports, what they mean and what to do. Every csCMake message starts with the command that
reports it, e.g. `[cs_initialize_project]`; `[csCMake]` when the project is finalized, at the end of the
`CMakeLists.txt` of `cs_initialize_project`.

To see what csCMake does, see [Debugging csCMake](#debugging-cscmake).

## Debugging csCMake

csCMake says what it does through CMake's own log levels; by default it prints nothing.

- `VERBOSE`: what it does, one line per thing: the project, each target, each package (found or not, its version and
  folder), the compile profiles a target asks for, what `cs_target_runtime_environment` adds, each component, and at
  the end of the project the dependencies of each target and component; a nested project says where its
  configurations come from;
- `DEBUG`: also the details: arguments, sources, links, the rules of the compile profiles (each rule when defined,
  and the ones applied to each target, marked when not for this compiler or platform), installed files, install
  RPATH, configuration mapping, run-time environment, and the whole project at the end (as `cs_print_project`).

### The whole build

Add `--log-level` to the configure command:

```bash
cmake --preset <preset> --log-level=VERBOSE
```

For a project `myApp` with a library `core` and an executable `app`:

```text
-- myApp: project myApp 1.0.0, C++ 20, configurations Debug, Release
-- myApp: target myApp_cscmake_base_include (INTERFACE_LIBRARY)
-- myApp: myApp_cscmake_base_include installed in the component cscmake_common (default)
-- myApp: target core (STATIC_LIBRARY)
-- myApp: core installed in the component core (default)
-- myApp: target app (EXECUTABLE)
-- myApp: app installed in the component app
-- myApp: finalizing the project (end of <folder>/CMakeLists.txt)
--   core depends on myApp_cscmake_base_include
--   app depends on core, myApp_cscmake_base_include
--   component cscmake_common: targets myApp_cscmake_base_include
--   component core: targets core; depends on cscmake_common
--   component app: targets app; depends on cscmake_common, core
--   myAppConfig.cmake installed in lib/cmake/myApp
```

`--log-level=DEBUG` adds the details. The level applies to everything CMake configures, other projects included.

### Some calls only

To see the details of one target and nothing else, put its calls in a `block()` that sets the level, in the
`CMakeLists.txt` of the project, and configure as usual (without `--log-level`, which would win over it):

```cmake
cs_add_library(core STATIC)
cs_target_link_libraries(core PUBLIC myApp::cscmake_base_include)

block()
  set(CMAKE_MESSAGE_LOG_LEVEL DEBUG)    # only until endblock()
  cs_add_executable(app main.cpp)
  cs_target_link_libraries(app PRIVATE core)
endblock()
```

```text
-- myApp: target app (EXECUTABLE)
--   default compile profiles of the folder: cscmake_default
--   install RPATH $ORIGIN/../lib
-- myApp: app links PRIVATE core
```

`block()` ... `endblock()` (CMake 3.25) is a scope of its own, like the body of a function: a variable set inside it
is restored at `endblock()`, so the level goes back to the default after the calls. The same `set()` at the top of a
sub-folder's `CMakeLists.txt` shows the messages of that folder and the ones below it. Remove it when done.

### Which command wrote a line

`--log-context` starts each line with `[<namespace>.<command>]`:

```text
-- [myApp.cs_add_library] myApp: target core (STATIC_LIBRARY)
-- [myApp.cs_install_target] myApp: core installed in the component core (default)
-- [myApp.finalize]   app depends on core, myApp_cscmake_base_include
```

### An installed package

The `<namespace>Config.cmake` of an installed package follows the level of the consumer: `--log-level=VERBOSE` in
the project that calls `find_package(myApp)` prints `myApp: component <component>` for each component it loads,
`DEBUG` also its `find_dependency(...)` calls.

## Inspecting a target or the project

Two commands print what csCMake knows, whatever the log level. Called anywhere in the project, they print at the
end of the `CMakeLists.txt` of `cs_initialize_project`, after the project is finalized (some values are resolved
there); remove them afterwards:

- `cs_print_target(<target>)`: a target does not build, link, install or run as expected. It prints its type, its
  component, the headers it installs, the packages it finds for its consumers, its compile profiles, its run-time
  environment (`cs_target_runtime_environment`), the targets of the project it depends on, then every CMake property
  set on it (`INTERFACE_INCLUDE_DIRECTORIES`, `INSTALL_RPATH`, `VS_DEBUGGER_ENVIRONMENT`, ...).
- `cs_print_project()`: the configurations, the search paths or the components are not the expected ones. It prints the
  configurations (postfix, C++ flags, MSVC runtime of each), the search paths, the install prefix, the targets, and
  each component with its targets, the packages it finds and the components it depends on.

```cmake
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
: See the arguments of `cs_initialize_project`.

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

`DEFAULT_CONFIG_MAPPED <config> MAPPED_TO ...`, `CUSTOM_CONFIG <config> BASED_ON ...`, `CUSTOM_CONFIG <config>: ... expected`
: The form is `DEFAULT_CONFIG_MAPPED <config> MAPPED_TO "<config>,<fallback>,"` and
  `CUSTOM_CONFIG <name> BASED_ON "<config>,<fallback>," POSTFIX "<postfix>"`.

## Finalizing

`[cs_target_link_libraries] <target>: its project is already finalized`,
`[cs_target_runtime_environment] <target>: its project is already finalized`
: The call comes after the end of the `CMakeLists.txt` of the project of the target, e.g. from a parent project: make
  it in the project of the target.

`[csCMake] cyclic dependency between the components: <components>`
: The targets of these components link each other in a cycle: move the targets so that the components depend on each
  other in one direction.

## Compile profiles

`[csCMake] compile profile <profile> of <target> is not defined`
: The profile has no rule: check its name, and that its `cs_add_compile_profile_rule` calls are in the project (or
  before it).

`[csCMake] clang-tidy is required: the compile profiles of <target> run it in this build`
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
