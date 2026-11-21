# Changelog

The changes of each csCMake release that matter to the projects using it. Releases and their assets (the csCMake
package, the documentation): GitHub Releases of this repository. How a release is made:
[Releasing](docs/contributing/releasing.md). What a project can rely on between releases:
[Compatibility](docs/user/compatibility.md).

## v1.0.0 (release candidates)

The first release. A release candidate (`v1.0.0-rc<n>`) is the API proposed for 1.0.0: it may still change from one
candidate to the next, listed here with what to change in a project.

Release candidate 9 (since `v1.0.0-rc8`):

- **The gersemi extension is a package**: `gersemi/` is the Python package `gersemi-cscmake` (module
  `gersemi_cscmake`, the file renamed from `gersemi/cscmake.py`), installed from a csCMake tag
  (`gersemi-cscmake @ git+https://github.com/cscosine/csCMake@<tag>#subdirectory=gersemi`, e.g. as an
  `additional_dependencies` of the gersemi pre-commit hook) and loaded with `extensions: [cscmake]`: no path to a
  csCMake checkout. A project that referenced `<csCMake>/gersemi/cscmake.py` uses `[cscmake]` instead
  ([Formatting](docs/user/formatting.md)).

Release candidate 8 (since `v1.0.0-rc7`):

- **clang-cl with Ninja on Windows**: the `msvcclang-msvc_2022_17` and `msvcclang-msvc_2026_18` presets use the clang-cl
  of their Visual Studio (`$env{VCINSTALLDIR}Tools/Llvm/x64/bin/clang-cl.exe`), no longer the first `clang-cl` on
  `PATH`: a standalone LLVM older than the standard library of the toolset failed every compile (MSVC 14.52 of
  Visual Studio 2026 needs Clang 22: `error STL1000`). Nothing to change in a project; configure from the developer
  environment of that Visual Studio, as before.
- **The error of a package built for a newer macOS** names both ways to raise the deployment target:
  `cs_macos_deployment_target(<version>)` (a csCMake project) or the `cscmake-project-setup-macos` preset (a project
  without csCMake).

Release candidate 7 (since `v1.0.0-rc6`):

- **The recorded macOS deployment target of a csCMake project** is named as its package:
  `share/cscmake/<namespace>.macos-deployment-target` (rc6: the project name, e.g. `csCoreSol` for the package
  `csCore`, which its consumers did not find, so they did not check it); a project added with `add_subdirectory`
  records its own too. Nothing to change in a project.

Release candidate 6 (since `v1.0.0-rc5`):

- **macOS deployment target: declared by each project, checked by csCMake** (breaking for macOS builds): the macOS
  presets set no `CMAKE_OSX_DEPLOYMENT_TARGET` (rc5: `13.3`). To change in a project built on macOS:
  - a csCMake project: `include(csCMakeSetup)` and `cs_macos_deployment_target(<version>)` (new) before `project()` in
    its top-level `CMakeLists.txt`; at least the value of the packages it uses (`14.4` with Qt 6.12; `13.3` with a
    compiled library that needs the floating-point `std::to_chars`, e.g. cpptrace). The build may raise it
    (`-DCMAKE_OSX_DEPLOYMENT_TARGET`, a preset), never lower it;
  - a project without csCMake built with the presets (a fork): `CMAKE_OSX_DEPLOYMENT_TARGET` and
    `CMAKE_PROJECT_INCLUDE=modules/scripts/csRecordMacosDeploymentTarget` in the `cscmake-project-setup-macos` preset
    of its `csCMakeProjectSetup.json`.

  Without a value, the binaries are built for the macOS of the build machine (a warning). The value is recorded in the
  installed package (`share/cscmake/<project>.macos-deployment-target`); a package found built for a newer macOS than
  the project fails the configure, with the value to raise to. `cs_require_macos_deployment_target(<version>
  [REASON <text>])` (new): the same check for a need of the project.
- **Checks on the packages found, hooks** (new): `cs_find_package` and the installed `<namespace>Config.cmake` (after
  each `find_dependency`) run `cs_after_find_dependency(<package>)`: the deployment target check, then the hooks
  registered for that package with `cs_add_after_find_hook(<package> <function>)`, the place for the checks of one
  library (guide: [Dependencies](docs/user/dependencies.md#hooks-checks-for-one-library)).
- **Qt** (`csQt`): the hook for `Qt6` checks that the project builds for `QT_SUPPORTED_MIN_MACOS_VERSION` of Qt or
  newer. Qt loaded without it (a plain `find_package(Qt6)`) fails at the end of the project: find it with
  `cs_find_package(<target> PUBLIC|PRIVATE Qt6 ...)`, or `-DCSCMAKE_QT_ALLOW_FIND_PACKAGE=ON` (a warning, the check
  done anyway).

Release candidate 5 (since `v1.0.0-rc4`):

- **macOS deployment target**: the macOS presets set `CMAKE_OSX_DEPLOYMENT_TARGET` to `13.3` (the floating-point
  `std::to_chars` of `std::format` in the libc++ of Apple; Qt 6.11 needs 13.0); before, the binaries ran only from
  the macOS of the build machine (macOS 15 or 26 on the CI runners). A project with its own value: in
  `cscmake-project-setup-macos`, which wins.
- **`cs_target_use_openmp` with Apple Clang**: nothing (a message), the target is built without OpenMP (Apple Clang has
  no OpenMP runtime); before: `find_package(OpenMP)` failed.
- **`cs_deployment_qt_gui(<name> [OFFSCREEN] [NO_WAYLAND])`** (new, `modules/integrations/csQt.cmake`): the Qt
  plugins of a GUI application in a deployment, per system (Linux: xcb with its OpenGL integrations, Wayland, in
  `plugins/<type>/`; Windows: `windows`, the native style, `opengl32sw.dll`, in `bin/`; macOS: `cocoa`, the native
  style, in `bin/<type>/`), instead of the list of plugins in every project.

Release candidate 4 (since `v1.0.0-rc3`):

- **Deployments on Windows and macOS**: the shared libraries of other packages are shipped there too (native builds;
  a warning in cross builds). Windows: the DLLs, found in the folders of the DLLs of the targets
  (`TARGET_RUNTIME_DLL_DIRS`) and `cs_deployment(... DIRECTORIES <folder>...)`, next to the executables, with the C++
  runtime of MSVC (`MSVC_RUNTIME ON`, default; `OFF`: the machine needs the Visual C++ Redistributable); a deployment
  using the debug C runtime of MSVC (e.g. Debug) fails, it is not redistributable. macOS: the dylibs and frameworks
  (without their headers) in `lib/`. `system-requirements.txt`: Linux only.

Release candidate 3:

- **Deployments** (new, `csDeployment`): `cs_deployment(<name> TARGETS ... [FILES|DIRECTORY ... DESTINATION ...]
  [CONFIGS ...])` declares a folder that runs without the build: the targets with the shared libraries of the project
  they need, and files (data, configuration, licences), run time only, independent of the installed package (e.g.
  samples). The normal install makes it too, in its own folder `<CSCMAKE_DEPLOY_DIR>/<name>-<config>` (default
  `<build>/deploy`, not in the install prefix), in its configurations only (default `Release`; skipped in the others);
  a failing deployment fails the install; `-DCSCMAKE_DEPLOY_ON_INSTALL=OFF` turns it off. The build target
  `cs_deploy_<name>` makes it alone (fails in a configuration it does not list). `cs-deployments.json` in the top build
  folder lists the deployments of the build. Nothing changes for a project without `cs_deployment`.
- **Deployments, the shared libraries of other packages** (Linux, native builds): a deployment also ships the shared
  libraries of other packages its binaries need (e.g. OpenCV, Qt), found from the build tree, copied unchanged to
  `lib/` with their symlinks; the libraries of the system (`/lib`, `/usr/lib`, ...) are not shipped, nor what they
  need. Then the deployment is checked: every library its binaries need resolves in it or in the system, and every
  library it ships resolves to its own copy, never to a library of the system of the same name. A library not found
  or found twice fails. `system-requirements.txt` in the deployment lists the libraries of the system it needs, with
  their Debian packages and the `apt install` line. `cs_deployment(... EXCLUDE_REGEXES <regex>...)` never ships (nor
  checks) the matching libraries. On Windows, macOS and in cross builds: a warning, the deployment has the binaries of
  the project only.
- **Deployments in the workspace**: the project setup presets set `CSCMAKE_DEPLOY_DIR` to
  `<workspace>/deploy/<variant>/<project folder>`, next to `install/<variant>/<project folder>`: the deployments go
  there, the same folder for every generator, instead of the build folder.
- **Deployments, plugins**: `cs_deployment(... PLUGINS <plugin target>... DESTINATION <folder>)` ships plugins
  (imported module libraries, loaded at run time) in a folder of the deployment, as they are, with the shared libraries
  they need (Linux); e.g. the Qt platform plugins: `PLUGINS Qt6::QXcbIntegrationPlugin DESTINATION plugins/platforms`.
  `DESTINATION` now goes with `PLUGINS`, `FILES` or `DIRECTORY`.

Release candidate 2:

- **Presets**: the configure preset of a variant inherits `cscmake-project-setup-<os>` (`linux`, `windows`,
  `macos`) before `cscmake-project-setup`. `presets/csCMakeProjectSetup.json` defines them empty and includes the
  new `presets/csCMakeProjectSetup-common.json` (`cscmake-common-project-setup` and the presets of the variants). A
  project with a layout, or with its own setup on `csCMakeProjectSetup.json`: nothing to change. A project that sets
  values per operating system includes `csCMakeProjectSetup-common.json` instead and defines the three OS presets
  ([Presets](docs/user/presets.md#choosing-the-project-setup)).
- **Presets**: the generated `cscmake-project-setup-<os>` and `cscmake-project-setup-<variant>` presets are hidden: the
  list of the presets of a project (`cmake --list-presets`, IDEs) shows only the `csv1-*` presets of the host.

Release candidate 1:

- **Projects**: `cs_initialize_project` after `project(<name> VERSION ...)`: namespace, C++ standard, build
  configurations (Debug, Release, RelWithDebInfo, mapped and custom ones with their postfixes); the project is
  finalized at the end of the same `CMakeLists.txt`.
- **Targets**: `cs_add_library`, `cs_add_executable`, `cs_target_sources` (sources installed with the target),
  `cs_target_link_libraries`, `cs_find_package` (`PUBLIC`: found again by the consumers of the package).
- **Installed packages with components**: `cs_install_target(<target> COMPONENT <component> [DEFAULT])`; the generated
  `<namespace>Config.cmake` loads the requested components, the ones they depend on and their packages;
  `VERSION_COMPATIBILITY`; relocatable (relative paths, relative install RPATH).
- **Compile profiles**: warnings, sanitizers, standard library hardening, clang-tidy, by configuration, compiler,
  platform and language, per project or per target (`cs_add_compile_profile_rule`, `cs_target_use_compile_profiles`).
- **Run-time environment**: the DLLs of each target per configuration, in the Visual Studio debugger and, on Windows,
  in `cs-env.bat` / `cs-env.ps1` for the whole build; `cs_target_runtime_environment` for what CMake cannot know.
- **Checks and troubleshooting**: `cs_target_check_installed_headers`; `cs_print_target`, `cs_print_project`; the
  messages of CMake's log levels (`--log-level=VERBOSE|DEBUG`, `--log-context`).
- **Presets** (`csv1`): Linux (Ubuntu 22.04 to 26.04, x64 and arm64, GCC and Clang), Windows (MSVC and clang-cl, Visual
  Studio and Ninja), macOS (Apple Clang, Ninja and Xcode); configure, build, test and workflow presets; workspace
  layouts `sibling`, `standalone`, `env`.
- **Formatting**: the gersemi configuration and the signatures of the `cs_*` commands for the projects.
