# csCMake development skill

Agent-facing guide for working in the csCMake repository. This file lives at
`.agents/skills/cscmake-development/SKILL.md`.

## Repository purpose

csCMake wraps CMake for common C++ project setup: targets, dependencies, install/export,
compile-option defaults, and CMake presets. It has two parts:

1. **CMake utility library** (`csCMake.cmake` + `modules/`) — turns a plain `CMakeLists.txt`
   into a well-structured project (custom build configurations, consistent output layout,
   MSVC handling, recursive dependency analysis, namespace-based install/export).
2. **Python preset generator** (`src/cscmake/`) — renders a full matrix of CMake Presets
   (OS × architecture × compiler × generator × build type) from small templates.

## Key files and their responsibilities

| Path | Role |
|------|------|
| `csCMake.cmake` | Entry point: `include(csCMake)` from a consumer `CMakeLists.txt`; CMake version and policies, includes the modules. |
| `modules/csProject.cmake` | `cs_initialize_project`, `cs_finalize_project`, `cs_get_namespace`; the variables set in the project scope. |
| `modules/csBuildConfigurations.cmake` | Build configurations: default, mapped, custom; postfixes, MSVC runtime per configuration. |
| `modules/csTargets.cmake` | `cs_add_library`, `cs_add_executable`, `cs_finalize_target`, `cs_get_project_targets`. |
| `modules/csTargetSources.cmake` | `cs_target_sources`: sources and the headers to install. |
| `modules/csTargetLinkLibraries.cmake` | `cs_target_link_libraries`. |
| `modules/csFindPackage.cmake` | `cs_find_package`: PUBLIC/PRIVATE propagation to the installed package. |
| `modules/csBaseInclude.cmake` | `<ns>::cscmake_base_include`, the generated files folders, the installed include folders. |
| `modules/csTargetDependencies.cmake` | Project and runtime dependencies of the targets, per configuration; Visual Studio debugger `PATH`. |
| `modules/csInstall.cmake` | `cs_install_target`, the components, the install RPATH. |
| `modules/csPackageConfig.cmake` | Component dependencies (cycles, sorting), `<Ns>Config.cmake` generation from the template. |
| `modules/csCheckInstalledHeaders.cmake` | `cs_target_check_installed_headers`: every installed header compiled on its own. |
| `modules/csCompileProfiles.cmake` / `csCompileProfilesShipped.cmake` | Compile profiles: the mechanism / the `cscmake_*` profiles. |
| `modules/csDebug.cmake` | `cs_debug_message`, `cs_print_state`, `cs_print_target_properties`. |
| `modules/csInternal.cmake` | Private helpers (lists, properties, paths); no reference page. |
| `modules/integrations/csOpenMP.cmake` | `cs_target_use_openmp` (integrations with third-party tools and libraries). |
| `templates/csTemplateConfig.cmake.in` | Template for the installed `<Ns>Config.cmake` (component-based). Format/lint with `cscmake-cmake-template`. |
| `.cmake-format.json` | cmake-format / cmake-lint configuration (width, naming patterns, disabled codes). |
| `src/cscmake/devtools/cmake_template.py` | `cscmake-cmake-template format\|lint`: cmakelang on `@VAR@` templates via parseable stand-ins. |
| `presets/common/` | Reusable preset building blocks (hosts, compilers, generators, build types, tests). |
| `presets/csv1/` | **Generated** preset matrix — do not edit by hand. |
| `presets/template/` | `@VAR@` templates used to generate `presets/csv1/`. |
| `src/cscmake/presets/render.py` | Template renderer (`@VAR@` delimiter) with JSON validation. |
| `src/cscmake/presets/registry.py` | Built-in variant matrix (OS/arch/compiler/generator) and short forms. |
| `src/cscmake/presets/generate.py` | Preset generator; console script `cscmake-generate-presets` (`--check` to verify). |
| `pyproject.toml` | Project metadata, ruff/mypy/pytest/coverage/import-linter config. |
| `tests/` | pytest suite (mirrors `src/` layout). |

## Conventions

- **CMake:** public functions `cs_*`, private helpers `_cs_`. File names `cs<Name>.cmake`.
  Formatted and linted by cmake-format / cmake-lint (`.cmake-format.json`, line width 120); every
  `function`/`macro` has a docstring comment block right above it: a `#.rst:` reStructuredText block for the public
  ones (the reference documentation, built by Sphinx from `docs/`), a plain `#` comment for the private ones. See the
  docs rule in `CLAUDE.md`.
- **Python:** strict mypy, ruff line-length 120, double quotes, docstrings on public functions.
- **Commit style:** short imperative summary, e.g. `add presets for arm64`.
- **Presets:** checked-in `presets/csv1/*.json` and `presets/csCMakeProjectSetup.json` and `presets/layout/*.json`
  are generated (templates in `presets/template/`). Never edit by hand.
  Regenerate with `cscmake-generate-presets`.

## Common tasks

### Set up the environment
```bash
./setup.sh          # Linux/macOS
./setup.ps1         # Windows
source .venv/bin/activate
```

### Run quality gates
```bash
pre-commit run --all-files   # hygiene, ruff, ruff-format, actionlint, mypy, cmake-format, cmake-lint,
                             # cmake-format/-lint (templates), generate-csv1-presets, import-linter
```

### Run tests
```bash
pytest                     # all tests
pytest --cov=cscmake       # with coverage
```

### Add a new build configuration
Edit `utils/csBuildConfigurations.cmake` (`_cs_add_default_build_configuration` /
`_cs_add_default_build_configuration_mapped`) and add the corresponding preset
entries in `presets/common/build-configurations.json`.

### Add a new preset variant
1. Update the variant registry in `src/cscmake/presets/registry.py` (built-in matrix).
2. Run `cscmake-generate-presets` to regenerate `presets/csv1/`.
3. Commit the regenerated presets (pre-commit `generate-csv1-presets` hook verifies sync).

### Runtime dependencies
- The package and the preset generator use the Python standard library only.
- Do not add runtime dependencies to `pyproject.toml` or extra installs to `setup.sh` / `setup.ps1`.

### Adding tests
- Python tests go in `tests/cscmake/<module>/test_*.py`.
- CMake behaviour that can be checked at configure time (properties, generated values, error messages) goes in
  `tests/cmake/test_*.py`: `tests.cmake.cmake_project.configure()` writes a `LANGUAGES NONE` project including csCMake,
  configures it and returns what it reported with `cstest_report(<key> <value>)`. Fast, no compiler needed.
- CMake smoke projects live in `tests/smoke/` (described in `docs/advanced/smoke-tests.md`, walked through in
  `docs/tutorials/`: a chain of packages
  `csSmokeBase` → `csSmokeMidA`/`csSmokeMidB` → `csSmokeTop`), driven by
  `tests/smoke/run_smoke.py --variant <id>`; CI runs it for every registry variant (`smoke.yml`,
  matrix from `tests/smoke/ci_matrix.py`). New csCMake features should get coverage there.
- Markers (root `conftest.py`): `@pytest.mark.slow` (skipped unless `--run-all`) and
  `@pytest.mark.requires("cmake")` (skipped when the tool is not on PATH).

### Dependency hygiene
- When adding a new dev dependency to `[project.optional-dependencies] dev` in
  `pyproject.toml`, also pin it in `constraints-minimum.txt` in the **same commit**.
  The CI minimum-deps job installs `pip install -e .[dev] -c constraints-minimum.txt`;
  anything missing from constraints will silently install the latest version from PyPI,
  defeating the purpose of the minimum-deps test.
