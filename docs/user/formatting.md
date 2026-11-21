# Formatting your CMake files

[gersemi](https://github.com/BlankSpruce/gersemi) lays out CMake code. To lay out the calls of the `cs_*` commands
well (one keyword with its values per line), it needs the signatures of the commands: they are a gersemi extension
(module `gersemi_cscmake`) in [cs-pre-commit-hooks](https://github.com/cscosine/cs-pre-commit-hooks), the pre-commit
hooks of cscosine, which also check the CMake rules of cscosine (`cscmake-lint`); gersemi loads it as
`extensions: [cscmake]`.

```cmake
# without the signatures                 # with them
cs_initialize_project(                   cs_initialize_project(
  NAMESPACE                                NAMESPACE myApp
  myApp                                    CXX_STANDARD 20
  CXX_STANDARD                             DEFAULT_CONFIG Debug Release
  20                                       CUSTOM_CONFIG Paranoid
  DEFAULT_CONFIG                           BASED_ON "Debug,Release,"
  ...                                      POSTFIX "dp"
)                                        )
```

## The configuration

`.gersemirc` in the project folder (gersemi looks for it in the folder of the file it formats and in the parent
folders):

```yaml
line_length: 120
indent: 2
list_expansion: favour-inlining
extensions: [cscmake]
warn_about_unknown_commands: false
```

The other settings are the project's choice; these are csCMake's own (120 columns, an indentation of 2). The cscosine
projects get both files of this page from the project template.

## With pre-commit

The hooks install gersemi (pinned) with the signatures in their own environment:

```yaml
- repo: https://github.com/cscosine/cs-pre-commit-hooks
  rev: v1.0.0
  hooks:
    - id: gersemi-cscmake
    - id: cscmake-lint      # optional: the CMake rules of cscosine
```

The hook reads the `.gersemirc` of the project. A release of cs-pre-commit-hooks has the signatures of the csCMake
commands of its time (its CHANGELOG says which); a newer csCMake command is laid out on one line until the project
moves to a newer release of the hooks.

## From the command line

```bash
pip install "cs-pre-commit-hooks @ git+https://github.com/cscosine/cs-pre-commit-hooks@v1.0.0"
gersemi -i CMakeLists.txt src/CMakeLists.txt    # format in place
gersemi --check .                               # exit 1 when a file is not formatted
cscmake-lint CMakeLists.txt                     # the CMake rules of cscosine
```

gersemi leaves comments as written: wrap them by hand.
