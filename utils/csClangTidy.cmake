include_guard(GLOBAL)

# Run clang-tidy (all checks, warnings as errors) while compiling TARGET_NAME. Only active with Clang on Linux, a no-op
# elsewhere. clang-tidy is looked up on the first call (CLANG_TIDY_EXE cache variable), so including csCMake does not
# require it.
#
# Known issue (Phase 3b): the generator expression below is split into several set_target_properties arguments, so
# CXX_CLANG_TIDY ends up empty and clang-tidy does not run.
function(cs_target_enable_clang_tidy TARGET_NAME)
  if(NOT (CMAKE_CXX_COMPILER_ID STREQUAL "Clang" AND CMAKE_SYSTEM_NAME STREQUAL "Linux"))
    return()
  endif()
  find_program(CLANG_TIDY_EXE NAMES clang-tidy)
  if(NOT CLANG_TIDY_EXE)
    message(FATAL_ERROR "clang tidy executable not found, install it, e.g. with sudo apt install clang-tidy")
  endif()

  # Apply to a specific target
  set_target_properties(
    ${TARGET_NAME}
    PROPERTIES
      CXX_CLANG_TIDY ""
      $<$<AND:$<CXX_COMPILER_ID:Clang>,$<PLATFORM_ID:Linux>>:
      "${CLANG_TIDY_EXE};
                        -checks=*,
                        -warnings-as-errors=*,
                        -header-filter=.*"
      # only Clang-compatible extra arguments
      --extra-arg-before=-Wall --extra-arg-before=-Wextra
      --extra-arg-before=-Wpedantic >)
endfunction()
