# TODO

The open work of csCMake: one line per item, by area. Done items are removed (the commit says what changed,
`CHANGELOG.md` what changed for the projects). The reasons behind the design: the documentation, "Design decisions".

## 1.0

- [ ] Validate the API on real projects: they use the rc1 release package (unpacked in the workspace, the sibling
  layout); a change of the API they need is a new release candidate.
- [ ] Delete the tags `v0.1.0` to `v0.4.0` (local and GitHub) and their GitHub Releases, once nothing uses them.
- [ ] Release `v1.0.0` when the release candidates need no change of the API.

## API

- [ ] Version header: a generated `<namespace>/version.h` from `project(VERSION)` (and the git hash), installed.
- [ ] Export header and symbol visibility: `generate_export_header`, hidden visibility by default for shared
  libraries, instead of `WINDOWS_EXPORT_ALL_SYMBOLS`.
- [ ] Test executables: GoogleTest / Catch2 with `gtest_discover_tests` / `catch_discover_tests` (IDEs list each test
  case); a helper (e.g. `cs_add_test_executable`) with labels, timeouts and, on Windows, the DLL `PATH` of the tests
  (`ENVIRONMENT_MODIFICATION` from `$<TARGET_RUNTIME_DLL_DIRS>`), so `ctest` and the test explorers run them outside
  Visual Studio.
- [ ] Documentation of the C++ projects: Doxygen (or Sphinx + Breathe) with a `cs_add_documentation` helper / `docs`
  target, a docs preset, published per release by CI.

## Runtime

- [ ] Deployments, plugins: `PLUGINS <imported module target>...` to `plugins/<QT_PLUGIN_TYPE>/` (Qt), as shipped.
- [ ] Deployments on Windows and macOS: the shared libraries of other packages (today a warning, the binaries of the
  project only): DLL folders (`$<TARGET_RUNTIME_DLL_DIRS>`, plus a `DIRECTORIES` option for the others), system
  exclusions (`System32`, `api-ms-*`, `/System`), `MSVC_RUNTIME ON|OFF` (app-local MSVC runtime, default `ON`; debug CRT configurations fail), `@loader_path`, the
  `csSmokeDeploy` applications run in the smoke. OpenCV loads `opencv_videoio_ffmpeg*.dll` at run time: shipped as a
  plugin (like the Qt ones). Cross builds: the libraries of the sysroot are the system ones.
- [ ] Deployments in the presets: `CSCMAKE_DEPLOY_DIR` in the project setup layouts (`deploy/` of the workspace).
- [ ] Deployments, a user-guide page (and `docs/advanced/runtime-dependencies.md`).
- [ ] Windows build folder in ctest and VS Code: the tests and `launch.json` need the `PATH` of `cs-env.bat` (e.g.
  `ENVIRONMENT_MODIFICATION` on the tests, an `envFile` generated next to the scripts).
- [ ] MSVC ASan: the ASan runtime DLLs on the debugger `PATH` and in `cs-env.bat`.

## Compile profiles

Guiding constraint: a core library is stricter than an application, a sample or a tool; the tests and samples of a
project may be looser than its library.

- [ ] Tiers composed from the shipped profiles, chosen with `DEFAULT_COMPILE_PROFILES` (core: strict warnings,
  hardening in the debug configurations, sanitizers and clang-tidy in a paranoid one; app: warnings as errors; sample:
  warnings). The configurations are the project's: a helper taking them (e.g.
  `cs_add_compile_profile_tier(<name> CORE PARANOID_CONFIGS Paranoid)`) or documented recipes.
- [ ] Per-target exceptions: `cs_target_exclude_compile_profiles(<target> <profile>...)` (vendored or generated code);
  generated sources (Qt `moc` / `uic`) marked `SKIP_LINTING`.
- [ ] More profiles: `cscmake_conformance` (MSVC `/Zc:preprocessor /utf-8 /permissive-`), `cscmake_hardening_release`
  (`-D_FORTIFY_SOURCE=3 -fstack-protector-strong -fcf-protection`, MSVC `/sdl /guard:cf`), `cscmake_sanitize_thread`,
  `cscmake_sanitize_undefined_fatal` (`-fno-sanitize-recover=all`), `cscmake_coverage` (GCC `--coverage`, Clang
  source-based) with a report target (gcovr / llvm-cov, HTML + Cobertura) for CI.
- [ ] More warnings, opt-in: `-Wcast-qual -Wextra-semi -Wundef -Wredundant-decls -Wsuggest-override`, GCC
  `-Wuseless-cast`; MSVC `/w14287 /we4289 /w14545 /w14546 /w14547 /w14549 /w14555 /w14619`.
- [ ] Other analyzers as rule fields like `CLANG_TIDY`: `CPPCHECK`, `IWYU`; clang-tidy fixes export
  (`<LANG>_CLANG_TIDY_EXPORT_FIXES_DIR`); MSVC `/analyze`.
- [ ] clang-tidy matured on a real library first (a profile in a Paranoid or Lint configuration, its `.clang-tidy`),
  then `.clang-tidy` tiers (core, app, sample; `InheritParentConfig: true` for tests and samples) in the template.
- [ ] Warnings from a nested csCMake project: its targets are not `SYSTEM` for the outer project, its headers trigger
  the outer project's warnings: mark them `SYSTEM` for the consumers.

## IDE

- [ ] IntelliSense: clangd on `compile_commands.json` (Ninja presets) or Microsoft C/C++ with CMake Tools as
  configuration provider (every generator): choose a default, document both; check Ninja Multi-Config.
- [ ] Compile a single file (CMake Tools "Compile Active File": Ninja and Makefiles only): document.
- [ ] Visual Studio "Open Folder" with `CMakePresets.json`: check the debugger environment (`launch.vs.json`), document.
- [ ] Build speed: a compiler cache (ccache / sccache as `CMAKE_CXX_COMPILER_LAUNCHER`, opt-in from a user preset or
  the environment), precompiled headers and unity builds documented.

## Presets and CI

- [ ] A CI generator following the registry (`presets/csv1/variants.json`): a selection of variants per project.
- [ ] Packaging of applications: CPack (archives, installers), with the deployment above. DEB: the `Depends` from
  `CPACK_DEBIAN_PACKAGE_SHLIBDEPS` (`dpkg-shlibdeps`), the shipped libraries private
  (`CPACK_DEBIAN_PACKAGE_SHLIBDEPS_PRIVATE_DIRS`).

## Smoke

- [ ] `cs_target_use_openmp` is not covered (it needs OpenMP on every runner).

## Documentation

- [ ] The docs zip opened offline shows the Mermaid diagrams as text (Mermaid is loaded from a CDN): ship Mermaid in
  the docs (and its licence on the Licences page) if offline diagrams are wanted.

## Project template

- [ ] A project template (copier): `CMakePresets.json`, `csCMakeProjectSetup.json`, the top `CMakeLists.txt`,
  pre-commit, `.clang-format`, `.clang-tidy` tiers, gersemi configuration (the `cs_*` signatures stay in csCMake,
  referenced from the checkout), `.vscode` (extensions, settings, `launch.json` per platform), licence and its check, a
  CI stub; it pins a compatible csCMake version.
