# Targets and sources

The targets of a csCMake project are created, given sources and linked with `cs_*` commands that work like the CMake
ones, plus one rule: every target is finalized after its links.

## Libraries and executables

```cmake
cs_add_library(core STATIC)                  # any add_library form: STATIC, SHARED, INTERFACE, OBJECT, ...
cs_add_library(myApp::core ALIAS core)       # aliases work as with add_library
cs_add_executable(myTool main.cpp)
```

`cs_add_library` and `cs_add_executable` take the arguments of `add_library` /
`add_executable`, and register the target in the project:

- its output name gets the postfix of each build configuration (`libcored.a` in Debug, `libcore.a` in Release, ...: see
  [Build configurations](build-configurations.md));
- with MSVC it uses the runtime library of the project;
- `cs_finalize_target` becomes mandatory for it.

An `ALIAS` is not registered: it is only another name.

## Sources and installed headers

```cmake
cs_target_sources(
  core
  PRIVATE core/Greeting.cpp
  PRIVATE_INSTALL core/Greeting.hpp)
```

`cs_target_sources` works like `target_sources` (`PRIVATE`, `PUBLIC`, `INTERFACE`), and adds keywords
for the files installed with the target, usually the public headers:

| Keyword | The file is |
|---|---|
| `PRIVATE`, `PUBLIC`, `INTERFACE` | a source of the target, as with `target_sources` |
| `PRIVATE_INSTALL`, `PUBLIC_INSTALL`, `INTERFACE_INSTALL` | also installed by `cs_install_target`, at its path relative to the project folder |
| `PRIVATE_INSTALL_ABSOLUTE_PATH`, `PUBLIC_INSTALL_ABSOLUTE_PATH`, `INTERFACE_INSTALL_ABSOLUTE_PATH` | given by absolute path (e.g. a generated header), installed in the include folder of the current folder |

Headers do not need to be `PUBLIC`: the include folders come from the default target (below), so `PRIVATE` and
`PRIVATE_INSTALL` are the usual choice.

### Include paths

Headers are included relative to the *project folder*, the folder of `cs_initialize_project`, in the build tree and
once installed:

```text
myApp/                          project folder (cs_initialize_project)
  myApp/core/Greeting.hpp       #include <myApp/core/Greeting.hpp>
```

The default target `<namespace>::cscmake_base_include`, created by `cs_initialize_project`, carries this include folder
(and the folders of the generated files). Link it from the targets of the project:

```cmake
cs_target_link_libraries(core PUBLIC myApp::cscmake_base_include)
```

It is installed with the package (component `cscmake_common`), so the consumers of `myApp::core` include
`<myApp/core/Greeting.hpp>` the same way.

### Generated files

`cs_get_generated_dir` returns the folder for generated files shared by every configuration,
`cs_get_generated_config_dir` the one for configuration-specific files (with multi-config generators it
contains `$<CONFIG>`). Both are include folders of `<namespace>::cscmake_base_include`.

## Links

```cmake
cs_target_link_libraries(myTool PRIVATE core)
```

`cs_target_link_libraries` works like `target_link_libraries`; an alias of a project target is replaced
by the target itself. `target_link_libraries` works too: csCMake reads the links of the targets when they are
finalized.

## Finalizing: mandatory, after the links

```cmake
cs_target_link_libraries(core PUBLIC myApp::cscmake_base_include)
cs_install_target(core core DEFAULT)
cs_finalize_target(core)
```

`cs_finalize_target` is required for every target of `cs_add_library` / `cs_add_executable`, after its
links. It applies the [compile profiles](compile-profiles.md) of the target and records the libraries it links, from
which `cs_finalize_project` computes its runtime dependencies. `cs_finalize_project` fails when:

- a target was not finalized: `cs_finalize_target(<target>) is required for every target, after its links: missing
  for ...`;
- a link was added after `cs_finalize_target`: `links added after cs_finalize_target: ...`.

Test executables, tools and examples are targets too: finalize them as well.

## Checking the installed headers

```cmake
cs_target_check_installed_headers(core COMPILE_PROFILES cscmake_strict_warnings)
```

`cs_target_check_installed_headers` compiles each header queued for installation (`*_INSTALL`) on its
own: for each header it generates a `.cpp` file that only includes it (named after the path of the header, so
`a/util.h` and `b/util.h` are both checked), and builds them in one static library `<target>_installed_headers` (e.g.
`core_installed_headers`) linking the target. A header that does not include what it uses fails the build. The
library uses the default compile profiles of the project plus the `COMPILE_PROFILES` given (e.g. strict warnings only
for this check).

## OpenMP

```cmake
cs_target_use_openmp(core PUBLIC)
```

`cs_target_use_openmp` enables OpenMP: `find_package(OpenMP REQUIRED)` and `OpenMP::OpenMP_CXX`; with clang-cl on
Windows, `/openmp` and the `vcomp` library. The installed package finds OpenMP for its consumers when they link it
too: `PUBLIC` and `INTERFACE`, and `PRIVATE` on a static library. Clang on Linux needs the OpenMP runtime of LLVM
(`libomp-dev` on Ubuntu).

## Debug messages

Every csCMake project has the cache option `<project>_CSCMAKE_DEBUG` (`<project>` is the `project()` name of
`cs_initialize_project`): `-DmyApp_CSCMAKE_DEBUG=ON` prints what csCMake does for it (its targets, components and
configurations among them). `cs_print_target_properties(<target>)` prints every property set on a target, and
`cs_print_state(<header>)` the search paths and configurations, as debug messages.
