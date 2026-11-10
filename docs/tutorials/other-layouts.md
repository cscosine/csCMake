# Other layouts

The previous tutorials use the `sibling` layout: the projects and csCMake side by side in a workspace folder. Two more
projects show the other layouts (see [Presets](../user/presets.md#layouts)).

## Workspace from the environment: `csSmokeEnv`

The workspace and csCMake can be anywhere: the environment variables `CSCMAKE_WORKSPACE_ROOT` and `CSCMAKE_ROOT` say
where. The presets use `$penv{CSCMAKE_ROOT}` to find csCMake.

[`tests/smoke/csSmokeEnv/CMakePresets.json`](../../tests/smoke/csSmokeEnv/CMakePresets.json):

```{literalinclude} ../../tests/smoke/csSmokeEnv/CMakePresets.json
:language: json
```

[`tests/smoke/csSmokeEnv/csCMakeProjectSetup.json`](../../tests/smoke/csSmokeEnv/csCMakeProjectSetup.json):

```{literalinclude} ../../tests/smoke/csSmokeEnv/csCMakeProjectSetup.json
:language: json
```

[`tests/smoke/csSmokeEnv/csSmokeEnv/CMakeLists.txt`](../../tests/smoke/csSmokeEnv/csSmokeEnv/CMakeLists.txt):

```{literalinclude} ../../tests/smoke/csSmokeEnv/csSmokeEnv/CMakeLists.txt
:language: cmake
```

`csSmokeBase` is found in `$CSCMAKE_WORKSPACE_ROOT/install/<variant>/`, as with the other layouts. This layout suits CI
jobs and shells that set the variables once for every project.

## Its own workspace: `csSmokeStandalone`

A self-contained project keeps its workspace inside: `<project>/workspace/` holds csCMake and the build and install
folders.

```text
csSmokeStandalone/
  CMakeLists.txt
  CMakePresets.json
  csCMakeProjectSetup.json
  csSmokeStandalone/
  workspace/
    csCMake/                  a copy (or a git submodule) of csCMake
    build/  install/          created by the presets
```

[`tests/smoke/csSmokeStandalone/CMakePresets.json`](../../tests/smoke/csSmokeStandalone/CMakePresets.json):

```{literalinclude} ../../tests/smoke/csSmokeStandalone/CMakePresets.json
:language: json
```

[`tests/smoke/csSmokeStandalone/csCMakeProjectSetup.json`](../../tests/smoke/csSmokeStandalone/csCMakeProjectSetup.json):

```{literalinclude} ../../tests/smoke/csSmokeStandalone/csCMakeProjectSetup.json
:language: json
```

`standalone-short` uses short build folder names (for the Windows path length limit). The project itself is plain:

[`tests/smoke/csSmokeStandalone/csSmokeStandalone/CMakeLists.txt`](../../tests/smoke/csSmokeStandalone/csSmokeStandalone/CMakeLists.txt):

```{literalinclude} ../../tests/smoke/csSmokeStandalone/csSmokeStandalone/CMakeLists.txt
:language: cmake
```
