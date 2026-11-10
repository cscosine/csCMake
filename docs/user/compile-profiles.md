# Compile profiles

A compile profile is a named set of compile options, definitions, link options and checks (clang-tidy), each under
conditions on the build. A project chooses which profiles every target gets, and adds more for some targets.

## Rules

A profile is made of rules, added with `cs_add_compile_profile_rule`; the first rule creates it:

```cmake
cs_add_compile_profile_rule(
  PROFILE myApp_paranoid
  CONFIGS Paranoid                  # build configurations
  COMPILERS GNU Clang               # CMAKE_CXX_COMPILER_ID
  FRONTENDS GNU                     # command-line style: GNU, or MSVC (cl, clang-cl)
  PLATFORMS Linux                   # CMAKE_SYSTEM_NAME
  COMPILE_OPTIONS -fno-inline
  COMPILE_DEFINITIONS MY_CHECKS=1
  LINK_OPTIONS ...
  PROFILES cscmake_sanitize_undefined cscmake_clang_tidy)   # other profiles, under the same conditions
```

Every condition is optional: a rule without conditions always applies. The conditions of a rule also apply to the
profiles it includes with `PROFILES`. A profile can have any number of rules, e.g. one per compiler.

## Which targets get which profiles

`cs_finalize_target` applies to each target:

1. the default profiles of the project: `DEFAULT_COMPILE_PROFILES` of `cs_initialize_project` (`cscmake_default` when
   not given, `NONE` for none);
2. the profiles given to `cs_target_use_compile_profiles`:

```cmake
cs_initialize_project(... DEFAULT_COMPILE_PROFILES cscmake_default cscmake_strict_warnings)
cs_target_use_compile_profiles(core myApp_paranoid)
```

The default profiles are the directory variable `CSCMAKE_DEFAULT_COMPILE_PROFILES`: a sub-folder (tests,
samples) can set its own before creating its targets.

- Compile options and definitions are private to the target: the consumers of the target never get them.
- The link options of static and object libraries are also part of their interface (e.g. the sanitizer runtime: the
  executable linking the library must link it too).
- INTERFACE libraries get nothing: they compile nothing.

## clang-tidy

A rule with `CLANG_TIDY` (or the profile `cscmake_clang_tidy`) runs clang-tidy on the sources of the target while
compiling them, with the checks of the `.clang-tidy` file of the project. Where such a rule matches the build, the
configure fails without clang-tidy (install it, or set `CLANG_TIDY_EXE`). The Visual Studio and Xcode generators do
not run it: csCMake prints a warning.

## Profiles shipped with csCMake

| Profile | Contents |
|---|---|
| `cscmake_default` | MSVC: `/MP` (parallel compilation), `/Zc:__cplusplus` |
| `cscmake_warnings` | high warning level, the same checks on every compiler (table below) |
| `cscmake_warnings_as_errors` | `-Werror` / `/WX` |
| `cscmake_strict_warnings` | `cscmake_warnings` + `cscmake_warnings_as_errors` |
| `cscmake_sanitize_undefined` | UndefinedBehaviorSanitizer (GCC, Clang, AppleClang on Linux and macOS) |
| `cscmake_sanitize_address` | AddressSanitizer (GCC, Clang, AppleClang on Linux and macOS; MSVC `/fsanitize=address`) |
| `cscmake_hardening_fast` | cheap standard library checks, usable in release builds |
| `cscmake_hardening_debug` | every standard library check, expensive, for test configurations |
| `cscmake_clang_tidy` | clang-tidy |

`cscmake_warnings`:

| Check | GCC / Clang / AppleClang | MSVC (`cl`) |
|---|---|---|
| warning level | `-Wall -Wextra -Wpedantic` | `/W4 /permissive-` (also clang-cl) |
| data member initialization order | `-Wreorder` | `/w15038` |
| non-virtual destructor with virtual functions | `-Wnon-virtual-dtor` | `/w14265` |
| function hiding a virtual one | `-Woverloaded-virtual` | `/w14263 /w14264` |
| narrowing and sign conversions | `-Wconversion -Wsign-conversion -Wdouble-promotion` | `/w14242 /w14254 /w14826` |
| enumerator not handled in a switch | (`-Wall`) | `/w14062` |
| implicit fallthrough in a switch | `-Wimplicit-fallthrough` | |
| shadowed variables | `-Wshadow` | (`/W4`) |
| old-style casts, `0` / `NULL` as pointer | `-Wold-style-cast -Wzero-as-null-pointer-constant` | |
| C++98 compatibility (off) | Clang, AppleClang, clang-cl: `-Wno-c++98-compat -Wno-c++98-compat-pedantic` | |
| uninitialized, unused, format | `-Winit-self -Wuninitialized -Wunused -Wformat=2` | |
| other | `-Wfloat-equal -Wcast-align -Wnull-dereference`; GCC: `-Wlogical-op -Wduplicated-cond -Wduplicated-branches -Wmisleading-indentation -Wstrict-null-sentinel` | `/w14296 /w14905 /w14906 /w14928 /w14640` |

A project adds its own checks with more rules on its own profile, and silences one with a rule adding `-Wno-...` /
`/wd....`.

## Standard library checks (hardening)

The standard library can check many of its preconditions at run time: `v[i]` out of range, `front()` of an empty
container, an empty `optional` dereferenced, ... Without the checks these are undefined behaviour; with them, the
program stops at the faulty call.

| Profile | libstdc++ (GCC; Clang on Linux) | libc++ (Clang on macOS) |
|---|---|---|
| `cscmake_hardening_fast` | `_GLIBCXX_ASSERTIONS` | `_LIBCPP_HARDENING_MODE_FAST`: the cheap checks, usable in production |
| `cscmake_hardening_debug` | `_GLIBCXX_ASSERTIONS` | `_LIBCPP_HARDENING_MODE_DEBUG`: every check, expensive |

The MSVC standard library has them in its Debug runtime. They change the behaviour of a program with such a bug, so no
default profile has them: a project chooses where, e.g. every check while developing and the cheap ones in what it
ships, Release and RelWithDebInfo alike (so that RelWithDebInfo profiles and debugs the code of Release):

```cmake
cs_add_compile_profile_rule(PROFILE myApp_checks CONFIGS Debug Paranoid PROFILES cscmake_hardening_debug)
cs_add_compile_profile_rule(PROFILE myApp_checks CONFIGS Release RelWithDebInfo PROFILES cscmake_hardening_fast)
cs_initialize_project(... DEFAULT_COMPILE_PROFILES cscmake_default myApp_checks)
```

With Xcode, its setting `CLANG_CXX_STANDARD_LIBRARY_HARDENING` defines `_LIBCPP_HARDENING_MODE` too: in the targets
with a hardening profile, the definition of the profile wins; the other targets keep the Xcode setting.

## Recipe: strictness per kind of project

How strict a project is depends on what it is: a core library used by everything is checked hard, an application less,
a sample or a quick tool hardly at all. A project defines its own profile for its kind, and makes it the default:

```cmake
# core library: strict warnings, every check while developing, the cheap ones when shipped,
# sanitizers and clang-tidy in a Paranoid configuration
cs_add_compile_profile_rule(PROFILE myCore_policy PROFILES cscmake_default cscmake_strict_warnings)
cs_add_compile_profile_rule(PROFILE myCore_policy CONFIGS Debug Paranoid PROFILES cscmake_hardening_debug)
cs_add_compile_profile_rule(PROFILE myCore_policy CONFIGS Release RelWithDebInfo PROFILES cscmake_hardening_fast)
cs_add_compile_profile_rule(PROFILE myCore_policy CONFIGS Paranoid
                            PROFILES cscmake_sanitize_undefined cscmake_sanitize_address)
cs_add_compile_profile_rule(PROFILE myCore_policy CONFIGS Paranoid COMPILERS Clang PLATFORMS Linux
                            PROFILES cscmake_clang_tidy)

# application: warnings as errors, checks in Debug
cs_add_compile_profile_rule(PROFILE myApp_policy PROFILES cscmake_default cscmake_strict_warnings)
cs_add_compile_profile_rule(PROFILE myApp_policy CONFIGS Debug PROFILES cscmake_hardening_debug)

# sample: warnings, never errors
cs_add_compile_profile_rule(PROFILE mySample_policy PROFILES cscmake_default cscmake_warnings)

cs_initialize_project(... DEFAULT_COMPILE_PROFILES myCore_policy)
```

Inside one project, tests and samples can be looser than the library: their folder sets
`CSCMAKE_DEFAULT_COMPILE_PROFILES` before creating its targets:

```cmake
# tests/CMakeLists.txt
set(CSCMAKE_DEFAULT_COMPILE_PROFILES cscmake_default cscmake_warnings)
```

Configuration names are chosen by each project (`Paranoid` here), so these are recipes to copy and adapt rather than
profiles shipped with csCMake.
