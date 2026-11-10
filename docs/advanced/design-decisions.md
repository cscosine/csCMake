# Design decisions

Why csCMake works the way it does: each decision, the reason, and what it means for a project.

## The project is the package

`cs_initialize_project(NAMESPACE <namespace> ...)` makes the project one installed package: `find_package(<namespace>)`
finds it, its targets are `<namespace>::<target>`, in the build tree and once installed. Inside, `cs_install_target`
puts each target in a *component*, and the generated `<namespace>Config.cmake` loads the requested components, the
ones they depend on (from the links of their targets) and the packages they need. A consumer asks for what it uses,
`find_package(myApp COMPONENTS core)`, and gets nothing else.

**For a project:** no `Config.cmake.in` to write; the dependencies between components follow the code, and a cycle
between them fails at configure time.

## Every configuration installed side by side

Each configuration has an output name postfix (`d` for Debug, none for Release, `rd` for RelWithDebInfo, chosen for a
custom one), and the headers of a project with several configurations go to `include/<CONFIG>/`: Debug, Release and
Paranoid builds install in the same prefix, generated per-configuration headers included. A consumer gets the
libraries **and** the headers of the configuration CMake selects for it (`CMAKE_MAP_IMPORTED_CONFIG_<CONFIG>`): the
include folders are exported per configuration, `$<$<CONFIG:Debug>:.../include/Debug>`, not `include/$<CONFIG>`, which
would name the consumer's configuration even when the package does not have it.

**For a project:** one install folder per platform and compiler, every configuration in it; a configuration of the
consumer that the package does not have is mapped like for any imported target.

## An explicit lifecycle

`cs_initialize_project` at the start, `cs_finalize_target` after the links of each target, `cs_finalize_project` at
the end: mandatory, and checked at configure time (a missing call, links added after `cs_finalize_target`). They are
where csCMake applies the compile profiles, analyses the runtime dependencies and generates the package, at a moment
where everything the target or the project needs is known.

**For a project:** a forgotten step fails early with a message naming it, instead of an incomplete package.

## No hidden side effects

csCMake changes only what its own targets need, or what the project asks for. A setting goes, by preference, on the
targets of `cs_add_library` / `cs_add_executable` (a target property set by `cs_finalize_target`), then in the project
folder, and only when unavoidable in the whole build; a wider setting is applied only if the project has not set it,
is documented, and can be turned off. The settings that reach beyond the csCMake targets, and why, are listed in
[the lifecycle](lifecycle.md#what-reaches-beyond-the-cscmake-targets).

**For a project:** its own `CMAKE_CXX_EXTENSIONS`, `CMAKE_INSTALL_RPATH`, `CMAKE_EXPORT_COMPILE_COMMANDS`, ... win;
a third-party project added with `add_subdirectory` keeps its own behaviour.

## Presets: toolchains and folders, never build behaviour

The presets are generated from one registry of supported platforms, compilers and generators, and committed: projects
use them without Python. They set the compiler, the generator, the build and install folders and the search paths,
and nothing that changes how a target is built: projects that use them without csCMake (a third-party library built
with the same toolchains) must keep their upstream behaviour. Build behaviour lives in the CMake code of csCMake,
where a project sees it and can turn it off.

**For a project:** the same preset names on every machine and in CI; `cmake --workflow --preset <name>` configures,
builds, tests and installs.

## Compile profiles instead of option targets

Warnings, sanitizers, standard library hardening and clang-tidy are named *profiles*: rules with conditions on the
configuration, the compiler, its command-line style and the platform, applied per target by `cs_finalize_target`.
Their compile options are `PRIVATE`: a library's warnings never reach its consumers.

**For a project:** one line for strict warnings on every compiler; a core library stricter than a sample, a test
folder looser than the library.

## Relative install RPATH, per target

On Linux and macOS, `cs_finalize_target` gives the executables and shared libraries of the project an install RPATH
relative to the binary (`$ORIGIN/../lib`, `@loader_path`), so an installed package runs wherever it is moved: built on
a CI machine, unpacked on another. Absolute paths to other packages (`CMAKE_INSTALL_RPATH_USE_LINK_PATH`) are not
used: they would point to the machine that built them.

**For a project:** installed applications find the shared libraries of their own package; the ones of other packages
are deployed with the application or found through the environment.

## The reference lives in the code

Every command, variable and property is documented in a `#.rst:` block of its module, right above the code, in the
format of CMake's own modules; Sphinx builds the reference from it, and `cscmake-check-docs` fails when something
public has no entry.

**For a project:** the reference matches the code of the version it uses (each release ships its documentation).

## Formatting and linting

gersemi formats the CMake code; the signatures of the `cs_*` commands ship as a gersemi extension, so a project
formats its calls the same way. csCMake checks its own conventions with a small linter of its own, `cscmake-lint`: no
maintained CMake linter checks them, and the previous one (cmakelang) is no longer maintained.

**For a project:** `gersemi` with the csCMake extension; see [Formatting your CMake files](../user/formatting.md).
