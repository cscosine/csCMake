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
| `utils/csAddLibraryExecutable.cmake` | `cs_add_library`, `cs_add_executable`, `cs_finalize_target`, `cs_get_all_targets`. |
| `utils/csTargetSources.cmake` | `cs_target_sources` — sources + install-aware variants. |
| `utils/csTargetLinkLibraries.cmake` | `cs_target_link_libraries` — scoped linking with dependency analysis. |
| `utils/csFindPackage.cmake` | `cs_find_package` — PUBLIC/PRIVATE propagation for install. |
| `utils/csTargetDependencies.cmake` | Recursive DLL/runtime dependency analysis per configuration. |
| `utils/csInstall.cmake` | `cs_install_target`, install layout, `<Ns>Config.cmake` generation from template. |
| `utils/csBuildConfigurations.cmake` | Build-configuration registration, postfixes, MSVC runtime per config. |
| `utils/csCompileEachInstalledInclude.cmake` | Compile every installed header standalone. |
| `utils/csClangTidy.cmake` / `utils/csOpenMP.cmake` | Optional per-target helpers. |
| `templates/csTemplateConfig.cmake.in` | Template for the installed `<Ns>Config.cmake` (component-based). |
| `presets/common/` | Reusable preset building blocks (hosts, compilers, generators, build types, tests). |
| `presets/csv1/` | **Generated** preset matrix — do not edit by hand. |
| `presets/template/` | `@VAR@` templates used to generate `presets/csv1/`. |
| `src/cscmake/utils/generate_cs_preset_variants.py` | Template renderer (`@VAR@` delimiter) with JSON validation. |
| `tools/generate_all_csv1_presets.py` | Entry point to regenerate the preset matrix. |
| `pyproject.toml` | Project metadata, ruff/mypy/pytest/coverage/import-linter config. |
| `tests/` | pytest suite (mirrors `src/` layout). |

## Conventions

- **CMake:** public functions `cs_*`, private helpers `_cs_`. File names `cs<Name>.cmake`.
- **Python:** strict mypy, ruff line-length 120, double quotes, docstrings on public functions.
- **Commit style:** short imperative summary, e.g. `add presets for arm64`.
- **Presets:** checked-in `presets/csv1/*.json` are generated. Never edit by hand.
  Regenerate with `python tools/generate_all_csv1_presets.py`.

## Common tasks

### Set up the environment
```bash
./setup.sh          # Linux/macOS
./setup.ps1         # Windows
source .venv/bin/activate
```

### Run quality gates
```bash
pre-commit run --all-files   # ruff, ruff-format, mypy, cmake-format, import-linter, presets sync
```

### Run tests
```bash
pytest                     # fast tests (skips slow/git by default)
pytest --run-all           # all tests
pytest --cov=cscmake       # with coverage
```

### Add a new build configuration
Edit `utils/csBuildConfigurations.cmake` (`_cs_add_default_build_configuration` /
`_cs_add_default_build_configuration_mapped`) and add the corresponding preset
entries in `presets/common/build-configurations.json`.

### Add a new preset variant
1. Update the variant registry in `src/cscmake/presets/registry.py` (built-in matrix).
2. Run `python tools/generate_all_csv1_presets.py` to regenerate `presets/csv1/`.
3. Commit the regenerated presets (pre-commit `generate-csv1-presets` hook verifies sync).

### csOrchestrator coupling
- The preset generator previously imported `csorchestrator` (not on PyPI). It now uses a
  built-in, zero-dependency variant registry in `cscmake.presets`.
- An optional `--variants-source csorchestrator` flag exists for when csOrchestrator is
  pip-installable; it is **not** the default.
- Do not re-add a hard dependency on `csorchestrator` in `pyproject.toml` or `setup.sh`.

### Adding tests
- Python tests go in `tests/cscmake/<module>/test_*.py`.
- CMake fixture project goes in `tests/fixture/` and is exercised by
  `tests/cmake/test_fixture_project.py` via subprocess (configure/build/install).
- Mark slow or git-dependent tests with `@pytest.mark.slow` / `@pytest.mark.git`; they
  are skipped unless `--run-all` is passed.

### Dependency hygiene
- When adding a new dev dependency to `[project.optional-dependencies] dev` in
  `pyproject.toml`, also pin it in `constraints-minimum.txt` in the **same commit**.
  The CI minimum-deps job installs `pip install -e .[dev] -c constraints-minimum.txt`;
  anything missing from constraints will silently install the latest version from PyPI,
  defeating the purpose of the minimum-deps test.
