# Formatting your CMake files

[gersemi](https://github.com/BlankSpruce/gersemi) lays out CMake code. To lay out the calls of the `cs_*` commands
well (one keyword with its values per line), it needs the signatures of the commands: csCMake ships them as a gersemi
extension, `gersemi/cscmake.py`, the one csCMake itself is formatted with (its `.gersemirc`).

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
extensions: [../csCMake/gersemi/cscmake.py]
```

The path of the extension is the one of the layout of the project (`../csCMake` for the `sibling` layouts,
`workspace/csCMake` for the `standalone` ones), and is relative to the folder gersemi runs from: run it from the project
folder (pre-commit does). The other settings are the project's choice; csCMake uses 120 columns and an indentation of 2.

## From the command line

```bash
pip install gersemi
gersemi -i CMakeLists.txt src/CMakeLists.txt    # format in place
gersemi --check .                               # exit 1 when a file is not formatted
```

## With pre-commit

```yaml
- repo: https://github.com/BlankSpruce/gersemi
  rev: 0.29.2
  hooks:
    - id: gersemi
```

The hook reads the `.gersemirc` of the project.

gersemi leaves comments as written: wrap them by hand.
