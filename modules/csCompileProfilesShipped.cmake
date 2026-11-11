#.rst:
# csCompileProfilesShipped
# ------------------------
#
# The compile profiles shipped with csCMake, defined with :command:`cs_add_compile_profile_rule` when csCMake is
# included (:doc:`csCompileProfiles`). Their options apply to C++ sources, and to C sources where they are valid in C
# (warnings, warnings as errors, sanitizers, ``/MP``); the C++-only ones (``-Wold-style-cast``, ``/permissive-``,
# the standard library hardening, ...) not.
#
# ``cscmake_default``
#   MSVC: ``/MP`` (parallel compilation), ``/Zc:__cplusplus``. The default of :command:`cs_initialize_project`.
#
# ``cscmake_warnings``
#   High warning level, the same essential checks on every compiler.
#   Clang, AppleClang (also clang-cl): the C++98 compatibility warnings off; clang-cl: the C++20 extensions
#   warnings off.
#
# ``cscmake_warnings_as_errors``
#   ``-Werror`` / ``/WX``.
#
# ``cscmake_strict_warnings``
#   ``cscmake_warnings`` and ``cscmake_warnings_as_errors``.
#
# ``cscmake_sanitize_undefined``, ``cscmake_sanitize_address``
#   UndefinedBehaviorSanitizer, AddressSanitizer (GCC, Clang, AppleClang on Linux and macOS; AddressSanitizer also
#   MSVC).
#
# ``cscmake_hardening_fast``
#   The cheap standard library checks, usable in release builds: ``_GLIBCXX_ASSERTIONS`` (libstdc++),
#   ``_LIBCPP_HARDENING_MODE_FAST`` (libc++).
#
# ``cscmake_hardening_debug``
#   Every standard library check, expensive, for test configurations: ``_GLIBCXX_ASSERTIONS``,
#   ``_LIBCPP_HARDENING_MODE_DEBUG``.
#
# ``cscmake_clang_tidy``
#   clang-tidy, with the checks of the ``.clang-tidy`` of the project.

include_guard(GLOBAL)
include(modules/csCompileProfiles)

# The compile profiles shipped with csCMake (README: "Compile profiles").
function(_cs_add_cscmake_compile_profiles)
  # every target of a project, unless DEFAULT_COMPILE_PROFILES says otherwise
  cs_add_compile_profile_rule(PROFILE cscmake_default COMPILERS MSVC LANGUAGES C CXX COMPILE_OPTIONS /MP)
  cs_add_compile_profile_rule(PROFILE cscmake_default COMPILERS MSVC COMPILE_OPTIONS /Zc:__cplusplus)

  # high warning level, the same essential checks on every compiler
  cs_add_compile_profile_rule(
    PROFILE cscmake_warnings
    FRONTENDS GNU LANGUAGES C CXX
    COMPILE_OPTIONS
      -Wall
      -Wextra
      -Wpedantic
      -Wconversion
      -Wsign-conversion
      -Wshadow
      -Wfloat-equal
      -Winit-self
      -Wuninitialized
      -Wunused
      -Wimplicit-fallthrough
      -Wcast-align
      -Wformat=2
      -Wnull-dereference
      -Wdouble-promotion
  )
  cs_add_compile_profile_rule(
    PROFILE cscmake_warnings
    FRONTENDS GNU
    COMPILE_OPTIONS -Wnon-virtual-dtor -Woverloaded-virtual -Wold-style-cast -Wreorder -Wzero-as-null-pointer-constant
  )
  cs_add_compile_profile_rule(
    PROFILE cscmake_warnings
    COMPILERS GNU LANGUAGES C CXX
    COMPILE_OPTIONS -Wlogical-op -Wduplicated-cond -Wduplicated-branches -Wmisleading-indentation
  )
  cs_add_compile_profile_rule(PROFILE cscmake_warnings COMPILERS GNU COMPILE_OPTIONS -Wstrict-null-sentinel)
  # Clang: C++98 compatibility warnings, noise in a project at C++11 or later (on with -Weverything, and with -Wall on
  # clang-cl, where it means -Weverything)
  cs_add_compile_profile_rule(
    PROFILE cscmake_warnings
    COMPILERS Clang AppleClang
    COMPILE_OPTIONS -Wno-c++98-compat -Wno-c++98-compat-pedantic
  )
  # clang-cl: C++20 extensions used by headers written for MSVC (e.g. an empty variadic macro argument), not reported by
  # MSVC itself
  cs_add_compile_profile_rule(
    PROFILE cscmake_warnings
    COMPILERS Clang
    FRONTENDS MSVC
    COMPILE_OPTIONS -Wno-c++20-extensions
  )
  # MSVC and clang-cl (MSVC command line)
  cs_add_compile_profile_rule(PROFILE cscmake_warnings FRONTENDS MSVC LANGUAGES C CXX COMPILE_OPTIONS /W4)
  cs_add_compile_profile_rule(PROFILE cscmake_warnings FRONTENDS MSVC COMPILE_OPTIONS /permissive-)
  # MSVC: warnings off by default even at /W4, the counterparts of the GCC/Clang ones above
  cs_add_compile_profile_rule(
    PROFILE cscmake_warnings
    COMPILERS MSVC
    COMPILE_OPTIONS
      # data member initialization order (-Wreorder)
      /w15038
      # virtual functions and a non-virtual destructor (-Wnon-virtual-dtor)
      /w14265
      # member function hiding a virtual one (-Woverloaded-virtual)
      /w14263
      /w14264
      # narrowing and sign-extending conversions (-Wconversion, -Wsign-conversion)
      /w14242
      /w14254
      /w14826
      # enumerator not handled in a switch (-Wswitch)
      /w14062
      # expression always false
      /w14296
      # string literal casts
      /w14905
      /w14906
      # illegal copy-initialization
      /w14928
      # thread-unsafe construction of a static local
      /w14640
  )

  cs_add_compile_profile_rule(PROFILE cscmake_warnings_as_errors FRONTENDS GNU LANGUAGES C CXX COMPILE_OPTIONS -Werror)
  cs_add_compile_profile_rule(PROFILE cscmake_warnings_as_errors FRONTENDS MSVC LANGUAGES C CXX COMPILE_OPTIONS /WX)

  cs_add_compile_profile_rule(PROFILE cscmake_strict_warnings PROFILES cscmake_warnings cscmake_warnings_as_errors)

  # sanitizers (compile and link)
  cs_add_compile_profile_rule(
    PROFILE cscmake_sanitize_undefined
    FRONTENDS GNU
    PLATFORMS Linux Darwin LANGUAGES C CXX
    COMPILE_OPTIONS -fsanitize=undefined
    LINK_OPTIONS -fsanitize=undefined
  )
  cs_add_compile_profile_rule(
    PROFILE cscmake_sanitize_address
    FRONTENDS GNU
    PLATFORMS Linux Darwin LANGUAGES C CXX
    COMPILE_OPTIONS -fsanitize=address -fno-omit-frame-pointer
    LINK_OPTIONS -fsanitize=address
  )
  cs_add_compile_profile_rule(
    PROFILE cscmake_sanitize_address
    COMPILERS MSVC LANGUAGES C CXX
    COMPILE_OPTIONS /fsanitize=address
  )

  # checks of the standard library, libstdc++ and libc++ (each one ignores the other definition): the cheap ones (usable
  # in release builds) and all of them (libc++ debug mode, expensive: for test configurations); MSVC STL: the Debug
  # runtime has them. Xcode defines _LIBCPP_HARDENING_MODE too (its setting CLANG_CXX_STANDARD_LIBRARY_HARDENING),
  # before the definitions of the target: the one of the profile wins, without the macro-redefined warning
  set(hardening_options "")
  if(CMAKE_GENERATOR STREQUAL "Xcode")
    set(hardening_options -Wno-macro-redefined)
  endif()
  cs_add_compile_profile_rule(
    PROFILE cscmake_hardening_fast
    FRONTENDS GNU
    COMPILE_OPTIONS ${hardening_options}
    COMPILE_DEFINITIONS _GLIBCXX_ASSERTIONS _LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_FAST
  )
  cs_add_compile_profile_rule(
    PROFILE cscmake_hardening_debug
    FRONTENDS GNU
    COMPILE_OPTIONS ${hardening_options}
    COMPILE_DEFINITIONS _GLIBCXX_ASSERTIONS _LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_DEBUG
  )

  cs_add_compile_profile_rule(PROFILE cscmake_clang_tidy CLANG_TIDY)
endfunction()

_cs_add_cscmake_compile_profiles()
