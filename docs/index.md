# csCMake

**CMake for teams with many C++ projects.** csCMake gives every project the same way to define its targets, find its
dependencies, install itself as a package with components, choose its compile options per configuration, and build on
every platform with ready-made presets: less CMake to write, and the same CMake everywhere.

````{grid} 1 2 2 2
:gutter: 3

```{grid-item-card} Get started
:link: user/getting-started
:link-type: doc

A first project: the three files it needs, then configure, build, test and install with one command.
```

```{grid-item-card} The smoke projects, step by step
:link: tutorials/index
:link-type: doc

Real projects that use csCMake: a package with components, a package using it, an application.
```

```{grid-item-card} Reference
:link: reference/csCMake
:link-type: doc

Every command, variable and property, from the CMake modules.
```

```{grid-item-card} Why it is built this way
:link: advanced/design-decisions
:link-type: doc

The decisions behind csCMake, and what they mean for a project.
```
````

## What it solves

Plain CMake can do all of it: the cost is the boilerplate, written again in every project, and every project doing it
a little differently. Three examples.

### A library installed as a package with components

````{tab-set}

```{tab-item} With csCMake
~~~cmake
cs_add_library(core STATIC)
cs_target_sources(core PRIVATE core/Greeting.cpp PRIVATE_INSTALL core/Greeting.hpp)
cs_target_link_libraries(core PUBLIC myApp::cscmake_base_include)
cs_install_target(core core DEFAULT)
cs_finalize_target(core)

# at the end of the top CMakeLists.txt: generates myAppConfig.cmake
cs_finalize_project()
~~~

A consumer writes `find_package(myApp COMPONENTS core)` and links `myApp::core`. The generated
`myAppConfig.cmake` loads the requested components, the components they depend on and the packages they need; the
headers keep their path from the project folder, in the build tree and once installed.
```

```{tab-item} Plain CMake
~~~cmake
add_library(core STATIC core/Greeting.cpp)
add_library(myApp::core ALIAS core)
target_include_directories(core PUBLIC $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}> $<INSTALL_INTERFACE:include>)
set_target_properties(core PROPERTIES DEBUG_POSTFIX d)
install(TARGETS core EXPORT myApp_core-targets ARCHIVE DESTINATION lib LIBRARY DESTINATION lib RUNTIME DESTINATION bin)
install(FILES myApp/core/Greeting.hpp DESTINATION include/myApp/core)
install(EXPORT myApp_core-targets NAMESPACE myApp:: DESTINATION lib/cmake/myApp/targets)

include(CMakePackageConfigHelpers)
configure_package_config_file(myAppConfig.cmake.in myAppConfig.cmake INSTALL_DESTINATION lib/cmake/myApp)
write_basic_package_version_file(myAppConfigVersion.cmake COMPATIBILITY AnyNewerVersion)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/myAppConfig.cmake ${CMAKE_CURRENT_BINARY_DIR}/myAppConfigVersion.cmake
        DESTINATION lib/cmake/myApp)
~~~

…plus `myAppConfig.cmake.in`, written and kept up to date by hand: which components exist, which ones each depends
on, their `find_dependency` calls, `myApp_<component>_FOUND`. For every library of every project.
```
````

### Debug, Release and a custom configuration, installed side by side

````{tab-set}

```{tab-item} With csCMake
~~~cmake
cs_initialize_project(
  NAMESPACE myApp
  CXX_STANDARD 20
  DEFAULT_CONFIG Debug Release
  CUSTOM_CONFIG Paranoid BASED_ON "Debug,Release," POSTFIX "dp"
  DEFAULT_COMPILE_PROFILES cscmake_default myApp_checks)

# every standard library check and UndefinedBehaviorSanitizer in Paranoid
cs_add_compile_profile_rule(PROFILE myApp_checks CONFIGS Paranoid
                            PROFILES cscmake_hardening_debug cscmake_sanitize_undefined)
~~~

`libcored.a`, `libcore.a` and `libcoredp.a` install in the same prefix, each with its headers; Paranoid copies the
flags of Debug, links the Debug build of the dependencies (else their Release build), and gets its checks on every
compiler that supports them.
```

```{tab-item} Plain CMake
~~~cmake
set(CMAKE_CONFIGURATION_TYPES Debug Release Paranoid)
foreach(var CMAKE_CXX_FLAGS CMAKE_EXE_LINKER_FLAGS CMAKE_SHARED_LINKER_FLAGS CMAKE_STATIC_LINKER_FLAGS ...)
  set(${var}_PARANOID "${${var}_DEBUG}" CACHE STRING "")
endforeach()
set(CMAKE_MAP_IMPORTED_CONFIG_PARANOID Debug Release)
set(CMAKE_PARANOID_POSTFIX dp)
add_compile_options("$<$<AND:$<CONFIG:Paranoid>,$<CXX_COMPILER_ID:GNU,Clang,AppleClang>>:-fsanitize=undefined>"
                    "$<$<AND:$<CONFIG:Paranoid>,$<CXX_COMPILER_ID:GNU>>:-D_GLIBCXX_DEBUG>" ...)
add_link_options(...)
~~~

…and the per-configuration header folders, the single-config generators (`CMAKE_BUILD_TYPE`), the MSVC flags and
runtime library: by hand, in every project.
```
````

### One preset per platform, compiler and generator

````{tab-set}

```{tab-item} With csCMake
`CMakePresets.json` includes the presets of csCMake, `csCMakeProjectSetup.json` says where the workspace is:

~~~json
{ "version": 10, "include": ["${sourceParentDir}/csCMake/presets/csv1/cs-presets-all.json"] }
~~~

~~~json
{ "version": 10, "include": ["${sourceParentDir}/csCMake/presets/layout/sibling.json"] }
~~~

Then configure, build, test and install every configuration in one command:

~~~bash
cmake --workflow --preset workflow-csv1-linux-ubuntu24.04-x64-generic-gcc-default-ninjamulticonfig-debug-release
~~~

Linux (GCC, Clang; x64, arm64), Windows (MSVC, clang-cl; Visual Studio, Ninja), macOS (Apple Clang; Ninja, Xcode):
the same names in every project and in CI.
```

```{tab-item} Plain CMake
A `CMakePresets.json` per project with configure, build, test and workflow presets for every compiler, generator and
platform, their build and install folders, and the search paths to find the other projects: copied from project to
project, and kept in sync by hand.
```
````

## Also in the box

- **Compile profiles**: warnings, warnings as errors, sanitizers, standard library hardening and clang-tidy, the same
  checks on every compiler, by configuration, per project or per target.
- **Runtime dependencies**: the shared libraries each target needs, per configuration; found by the Visual Studio
  debugger, and by the installed executables of a package (relative install RPATH).
- **Checks at configure time**: every target and the project finalized, the links of a target complete, installed
  headers that compile on their own.
- **Workspaces**: projects side by side, a self-contained application with its own workspace, or the workspace given
  by the environment (CI).

## Who it is for

csCMake fits a set of C++ projects that depend on each other (libraries, then applications), are built for several
platforms, compilers and configurations, and are installed and found with `find_package`, locally and in CI.

It is not a package manager: it consumes what `find_package` finds (your packages, or the ones of vcpkg, Conan, a
system install). A single executable that is never installed or consumed is fine with plain CMake. csCMake needs
CMake 3.31 or newer.

```{toctree}
:hidden:
:caption: User guide
:maxdepth: 2

user/getting-started
user/targets
user/dependencies
user/install
user/build-configurations
user/compile-profiles
user/presets
user/formatting
user/troubleshooting
```

```{toctree}
:hidden:
:caption: Tutorials
:maxdepth: 1

tutorials/index
```

```{toctree}
:hidden:
:caption: Advanced
:maxdepth: 1

advanced/design-decisions
advanced/lifecycle
advanced/runtime-dependencies
advanced/packages
advanced/presets-internals
advanced/smoke-tests
```

```{toctree}
:hidden:
:caption: Reference
:maxdepth: 1

reference/csCMake
reference/csProject
reference/csBuildConfigurations
reference/csTargets
reference/csTargetSources
reference/csTargetLinkLibraries
reference/csFindPackage
reference/csBaseInclude
reference/csTargetDependencies
reference/csInstall
reference/csPackageConfig
reference/csCheckInstalledHeaders
reference/csCompileProfiles
reference/csCompileProfilesShipped
reference/csDebug
reference/csOpenMP
```

```{toctree}
:hidden:
:caption: Contributing
:maxdepth: 1

contributing/code
contributing/documentation
contributing/releasing
```
