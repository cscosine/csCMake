include_guard(GLOBAL)

if(UNIX)
  # Find clang-tidy executable
  find_program(CLANG_TIDY_EXE NAMES clang-tidy)
  if(NOT CLANG_TIDY_EXE)
    message(FATAL_ERROR "clang tidy executable not found, install it, e.g. with sudo apt install clang-tidy")
  endif()
endif()

# Run clang-tidy (all checks, warnings as errors) while compiling TARGET_NAME. Only active with Clang on Linux.
function(cs_exec_clang_tidy TARGET_NAME)
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
