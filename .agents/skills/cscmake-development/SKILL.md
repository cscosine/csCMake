# csCMake development skill

Agent-facing guide for working in the csCMake repository. This file lives at
`.agents/skills/cscmake-development/SKILL.md`.

## Repository purpose

csCMake wraps CMake for common C++ project setup: targets, dependencies, install/export,
compile-option defaults, and CMake presets. It has two parts:

1. **CMake utility library** (`csCMake.cmake` + `utils/`) — turns a plain `CMakeLists.txt`
   into a well-structured project (custom build configurations, consistent output layout,
   MSVC handling, recursive dependency analysis, namespace-based install/export).
2. **Python preset generator** (`src/cscmake/`) — renders a full matrix of CMake Presets
   (OS × architecture × compiler × generator × build type) from small templates.

## Key files and their responsibilities

| Path | Role |
|------|------|
| `csCMake.cmake` | Main entry point. `include(csCMake)` from a consumer `CMakeLists.txt`. Defines `cs_initialize_project` / `cs_finalize_project`. |
| `utils/csAddLibraryExecutable.cmake` | `cs_add_library`, `cs_add_executable`, `cs_finalize_target`, `cs_get_project_targets`. |
| `utils/csTargetSources.cmake` | `cs_target_sources` — sources + install-aware variants. |
| `utils/csTargetLinkLibraries.cmake` | `cs_target_link_libraries` — scoped linking with dependency analysis. |
| `utils/csFindPackage.cmake` | `cs_find_package` — PUBLIC/PRIVATE propagation for install. |
| `utils/csTargetDependencies.cmake` | Recursive DLL/runtime dependency analysis per configuration. |
| `utils/csInstall.cmake` | `cs_install_target`, install layout, `<Ns>Config.cmake` generation from template. |
| `utils/csBuildConfigurations.cmake` | Build-configuration registration, postfixes, MSVC runtime per config. |
| `utils/csCompileEachInstalledInclude.cmake` | Compile every installed header standalone. |
| `utils/csClangTidy.cmake` / `utils/csOpenMP.cmake` | Optional per-target helpers. |
| `templates/csTemplateConfig.cmake.in` | Template for the installed `<Ns>Config.cmake` (component-based). Format/lint with `cscmake-cmake-template`. |
| `.cmake-format.json` | cmake-format / cmake-lint configuration (width, naming patterns, disabled codes). |
| `src/cscmake/devtools/cmake_template.py` | `cscmake-cmake-template format\|lint`: cmakelang on `@VAR@` templates via parseable stand-ins. |
| `presets/common/` | Reusable preset building blocks (hosts, compilers, generators, build types, tests). |
| `presets/csv1/` | **Generated** preset matrix — do not edit by hand. |
| `presets/template/` | `@VAR@` templates used to generate `presets/csv1/`. |
| `src/cscmake/utils/generate_cs_preset_variants.py` | Template renderer (`@VAR@` delimiter) with JSON validation. |
| `src/cscmake/presets/registry.py` | Built-in variant matrix (OS/arch/compiler/generator) and short forms. |
| `src/cscmake/presets/generate.py` | Preset generator; console script `cscmake-generate-presets` (`--check` to verify). |
| `pyproject.toml` | Project metadata, ruff/mypy/pytest/coverage/import-linter config. |
| `tests/` | pytest suite (mirrors `src/` layout). |

## Conventions

- **CMake:** public functions `cs_*`, private helpers `_cs_`. File names `cs<Name>.cmake`.
  Formatted and linted by cmake-format / cmake-lint (`.cmake-format.json`, line width 120); every
  `function`/`macro` has a docstring comment block right above it. Long string literals are allowed
  (C0301 off: cmake-format cannot wrap strings).
- **Python:** strict mypy, ruff line-length 120, double quotes, docstrings on public functions.
- **Commit style:** short imperative summary, e.g. `add presets for arm64`.
- **Presets:** checked-in `presets/csv1/*.json` and `presets/csCMakeProjectSetup-{default,default-standalone,shortBuildPath}.json`
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
- CMake smoke projects live in `tests/smoke/` (described in `tests/smoke/README.md`: a chain of packages
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
