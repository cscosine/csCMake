# Compatibility

What a project can rely on from one csCMake release to the next, and what may change in any release.

## Versions

csCMake follows semantic versioning. A breaking change of the public API (below) raises the major version (1.x →
2.0). The changes of each release are in `CHANGELOG.md`, a breaking change with what to change in a project.

The release candidates of a version (`1.0.0-rc1`, `1.0.0-rc2`, ...) propose its API: it may still change from one
candidate to the next, until the version itself is released.

A project chooses its version by the copy of csCMake in its workspace: a release package, or a git clone on a release
tag (see [Getting started](getting-started.md#where-cscmake-lives)).

## The public API

| What | Where it is listed |
|---|---|
| the `cs_*` commands, their arguments and behaviour | {doc}`Commands by tier <../reference/commands>` and the reference of each module |
| the variables and the target and global properties a project sets or reads | the `Variables`, `Target properties` and `Global properties` sections of the reference, except the ones marked *Internal* |
| the default targets of a project | `<namespace>::cscmake_base_include` ([Targets and sources](targets.md)) |
| the installed package | `find_package(<namespace> [COMPONENTS ...])`, the components, the public variables of `<namespace>Config.cmake` ([Installed packages](install.md)) |
| the presets | the names of the `csv1` presets (configure, build, test, workflow), the layouts (`presets/layout/*.json`), `csCMakeProjectSetup.json` and the environment variables they read ([Presets](presets.md)) |
| the formatter configuration | `.gersemirc` and the `cs_*` signatures in `gersemi/` ([Formatting](formatting.md)) |

A new command, argument, variable, preset or component is not a breaking change. Neither is a new message at the
`VERBOSE` or `DEBUG` log level, or a change of one: the messages are not part of the API.

## Not part of the API

May change in any release:

- the internal commands, `_cs_*`, and the internal variables and properties, `_CSCMAKE_*` and the ones marked
  *Internal* in the reference;
- the files csCMake generates other than the installed package: what is in the build folder, the hidden presets the
  `csv1` presets inherit from;
- the text of the messages, errors included;
- the Python tools of the repository (`src/cscmake/`): they develop csCMake, projects do not use them.

## CMake and the platforms

- **CMake 3.31** or newer: the `csv1` presets use preset schema 10. A new minimum CMake version is a breaking change.
- The platforms, compilers and generators of the presets: [Presets](presets.md). A preset removed (e.g. an operating
  system version at its end of life) is a breaking change.
