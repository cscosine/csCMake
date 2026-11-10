# An application

`csSmokeTop` is an application using `csSmokeMidA` and `csSmokeMidB` ([the previous tutorial](using-a-package.md)),
which both use `csSmokeBase`.

[`tests/smoke/csSmokeTop/csSmokeTop/CMakeLists.txt`](../../tests/smoke/csSmokeTop/csSmokeTop/CMakeLists.txt):

```{literalinclude} ../../tests/smoke/csSmokeTop/csSmokeTop/CMakeLists.txt
:language: cmake
```

- **`PUBLIC` and `PRIVATE`**: `csSmokeMidA` is found `PUBLIC`, so the installed `csSmokeTopConfig.cmake` finds it again;
  `csSmokeMidB` is `PRIVATE`: used to build the application, not propagated. Use `PRIVATE` for what the consumers of
  the package never see (an application linked into nothing, a test framework).
- **A diamond**: `csSmokeBase` is reached twice, through the `find_dependency` calls of `csSmokeMidA` (component `text`)
  and of `csSmokeMidB` (component `core`). The generated Configs load each component once.
- **An installed application**: `cs_install_target(csSmokeTop csSmokeTop DEFAULT)` installs the executable in `bin/`,
  with the postfix of the configuration (`csSmokeTopd` in Debug).
- **Its output, tested**: `add_test` runs it and checks what it prints.

[`tests/smoke/csSmokeTop/csSmokeTop/main.cpp`](../../tests/smoke/csSmokeTop/csSmokeTop/main.cpp):

```{literalinclude} ../../tests/smoke/csSmokeTop/csSmokeTop/main.cpp
:language: cpp
```

It prints `mid-a(text(base-core)) mid-b(base-core)`: each package adds its part to the message of the one it uses.

Next: [other layouts](other-layouts.md).
