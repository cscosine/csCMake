# Changelog

The changes of each csCMake release that matter to the projects using it. Releases and their assets (the csCMake
package, the documentation): GitHub Releases of this repository. How a release is made:
[Releasing](docs/contributing/releasing.md). What a project can rely on between releases:
[Compatibility](docs/user/compatibility.md).

## v1.0.0 (release candidates)

The first release. A release candidate (`v1.0.0-rc<n>`) is the API proposed for 1.0.0: it may still change from one
candidate to the next, listed here with what to change in a project.

Since `v1.0.0-rc1`:

- **Presets**: the configure preset of a variant inherits `cscmake-project-setup-<os>` (`linux`, `windows`,
  `macos`) before `cscmake-project-setup`. `presets/csCMakeProjectSetup.json` defines them empty and includes the
  new `presets/csCMakeProjectSetup-common.json` (`cscmake-common-project-setup` and the presets of the variants). A
  project with a layout, or with its own setup on `csCMakeProjectSetup.json`: nothing to change. A project that sets
  values per operating system includes `csCMakeProjectSetup-common.json` instead and defines the three OS presets
  ([Presets](docs/user/presets.md#choosing-the-project-setup)).
- **Presets**: the generated `cscmake-project-setup-<os>` and `cscmake-project-setup-<variant>` presets are hidden: the
  list of the presets of a project (`cmake --list-presets`, IDEs) shows only the `csv1-*` presets of the host.
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
