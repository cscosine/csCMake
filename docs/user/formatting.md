# Formatting your CMake files

[cmake-format](https://cmake-format.readthedocs.io) lays out CMake code and cmake-lint checks it. To lay out the
calls of the `cs_*` commands well (one keyword with its values per line), they need the signatures of the commands:
csCMake keeps them in its `.cmake-format.json` (`parse.additional_commands`), the configuration csCMake itself is
formatted with.

```cmake
# without the signatures                 # with them
cs_initialize_project(                   cs_initialize_project(
  NAMESPACE                                NAMESPACE myApp
  myApp                                    CXX_STANDARD 20
  CXX_STANDARD                             DEFAULT_CONFIG Debug Release
  20                                       CUSTOM_CONFIG Paranoid
  DEFAULT_CONFIG                           BASED_ON "Debug,Release,"
  ...                                      POSTFIX "dp")
```

cmake-format finds a configuration file only in the folder of the file it formats and in the parent folders: a project
next to csCMake does not see the one of csCMake. Give it explicitly.

## From the command line

```bash
pip install cmakelang
cmake-format -i CMakeLists.txt -c ../csCMake/.cmake-format.json
cmake-lint CMakeLists.txt -c ../csCMake/.cmake-format.json
```

`-c` takes several files, the later ones overriding the earlier ones: the project keeps its own settings in its own
`.cmake-format.json` and adds the csCMake one first:

```bash
cmake-format -i -c ../csCMake/.cmake-format.json .cmake-format.json -- CMakeLists.txt src/CMakeLists.txt
```

`--` ends the list of configuration files (without it `-c` takes the files to format as configuration files too). A
project without its own settings leaves out `.cmake-format.json`.

The csCMake configuration also brings its own choices: 120 columns, and the naming rules of cmake-lint (lowercase
functions, arguments and local variables). Override what the project does differently in its own file.

## With pre-commit

```yaml
- repo: https://github.com/cheshirekow/cmake-format-precommit
  rev: v0.6.13
  hooks:
    - id: cmake-format
      args: [-c, ../csCMake/.cmake-format.json, .cmake-format.json, --]
    - id: cmake-lint
      args: [-c, ../csCMake/.cmake-format.json, .cmake-format.json, --]
```

pre-commit appends the files to check after the arguments, hence the final `--`. The path is the one of the layout of
the project (`../csCMake` for the `sibling` layouts, `workspace/csCMake` for the `standalone` ones).
