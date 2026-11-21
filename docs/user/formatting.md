# Formatting your CMake files

[gersemi](https://github.com/BlankSpruce/gersemi) lays out CMake code. To lay out the calls of the `cs_*` commands
well (one keyword with its values per line), it needs the signatures of the commands: csCMake ships them as a gersemi
extension, the package `gersemi-cscmake` in its `gersemi/` folder (module `gersemi_cscmake`), installed from a csCMake
tag; gersemi loads it as `extensions: [cscmake]`.

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

The gersemi hook installs the extension in its environment, from the csCMake tag the project uses:

```yaml
- repo: https://github.com/BlankSpruce/gersemi-pre-commit
  rev: 0.29.2
  hooks:
    - id: gersemi
      additional_dependencies:
        - gersemi-cscmake @ git+https://github.com/cscosine/csCMake@v1.0.0#subdirectory=gersemi
```

The hook reads the `.gersemirc` of the project.

## From the command line

```bash
pip install gersemi "gersemi-cscmake @ git+https://github.com/cscosine/csCMake@v1.0.0#subdirectory=gersemi"
gersemi -i CMakeLists.txt src/CMakeLists.txt    # format in place
gersemi --check .                               # exit 1 when a file is not formatted
```

The released archive contains the same folder: `pip install <csCMake>/gersemi` installs it from a downloaded csCMake.

gersemi leaves comments as written: wrap them by hand.
