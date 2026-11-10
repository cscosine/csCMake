# Presets internals

How the presets of `presets/` are made. They are generated and committed: projects use them without Python. For their
use, see [Presets](../user/presets.md).

## Files

```text
presets/
  common/                     hand-written building blocks: generators, compilers, build types, hosts, test settings
  template/                   templates of the generated files (@{var} placeholders)
  csv1/                       generated: one set of files per variant, and cs-presets-all.json
  csCMakeProjectSetup.json    generated: cscmake-common-project-setup, one cscmake-project-setup-<variant> per variant
  layout/<layout>.json        generated: cscmake-project-setup of each layout
```

Never edit the generated files by hand: change the templates, the registry or the generator, regenerate, and commit
the output with the change (the `generate-csv1-presets` pre-commit hook regenerates and fails when files change).

## The registry: `src/cscmake/presets/registry.py`

The single source of truth of the supported variants: operating systems and versions, architectures, compilers (with
the MSVC toolsets of the Ninja variants), generators and their type (single- or multi-config), and the build
configurations (Debug, Release, RelWithDebInfo, Paranoid). `get_supported_context_os_architecture_list()` returns every
supported combination; each is a *variant*, named

```text
csv1-<os>-<os version>-<arch>-<arch variant>-<compiler>-<compiler version>-<generator>
```

with short forms of each part for the short build folder names. The values and short forms end up in the preset names
and folders used by every project: changing them renames presets.

The smoke workflow reads the registry too (`tests/smoke/ci_matrix.py`): one CI job per variant, on the GitHub runner
that can build it.

## The generator: `cscmake-generate-presets`

`src/cscmake/presets/generate.py` renders, for every variant, the templates of its generator type with the
substitutions of the variant (`@{host}`, `@{osVersion}`, `@{compiler}`, `@{generator}`, `@{buildConfig}`, ...):

| Template | Output, per variant |
|---|---|
| `cs-{single,multi}-config-generator-base.json.template` | `<variant>-base.json`: the configure preset of the variant (multi-config), or the hidden one the configure presets of each configuration inherit (single-config): host, generator, compiler, project setup |
| `cs-{single,multi}-config-generator-config.json.template` | `<variant>-<config>.json`: the build, install, test and workflow presets of a configuration (and, single-config, its configure preset) |
| `cs-{single,multi}-config-generator-ALL.json.template` | `<variant>-ALL.json`: includes the files of the variant (multi-config: also the workflows over several configurations) |
| `cs-presets-all.json.template` | `cs-presets-all.json`: includes every `-ALL` file |
| `csCMakeProjectSetup.json.template` | `csCMakeProjectSetup.json` |
| `layout.json.template` | `layout/<layout>.json`, one per entry of the `LAYOUTS` table of `generate.py` |

```bash
cscmake-generate-presets            # regenerate in place
cscmake-generate-presets --check    # exit 1 if a generated file is out of date (CI, tests)
```

Regeneration is deterministic: the same inputs give byte-identical files, and files of variants that no longer exist
are removed.

## Project setup and layouts

The configure preset of a variant inherits `cscmake-project-setup`, the preset defined by the layout the project
includes in its own `csCMakeProjectSetup.json`, and `cscmake-project-setup-<variant>` (in the generated
`csCMakeProjectSetup.json`: the folder names of the variant), with the host, generator and compiler building blocks of
`presets/common/`. A layout only sets three environment values:

| Value | Meaning |
|---|---|
| `CSCMAKE_WORKSPACE_ROOT` | the workspace: parent of the `build/` and `install/` folders |
| `CSCMAKE_ROOT` | the csCMake folder: `CMAKE_MODULE_PATH`, so that `include(csCMake)` finds it |
| `CSCMAKE_BUILD_SUB_DIR` | the variant folder name in `build/`: long (variant id) or short |

`cscmake-common-project-setup` turns them into the build and install folders, `CMAKE_PREFIX_PATH` (the `install/` and
`libs/` folders of the variant in the workspace) and `CMAKE_MODULE_PATH`, and passes the
`CSCMAKE_{PREFIX,MODULE}_PATH_{HEAD,TAIL}` environment variables on to `cs_initialize_project`. A preset can only
inherit presets of its own file or of the files it includes: the layouts include `csCMakeProjectSetup.json` for this.

## Adding a variant

1. Add the values to the registry (enum, short form, the supported lists) and, if needed, the building blocks in
   `presets/common/`.
2. `cscmake-generate-presets`, and look at the new files.
3. The smoke matrix picks the variant up: give `ci_matrix.py` the runner that builds it.
4. Update the tables of the user guide ([Presets](../user/presets.md#preset-names)).
