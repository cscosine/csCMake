include_guard(GLOBAL)
include(utils/csFindPackage)

# Enable OpenMP on TARGET with the given VISIBILITY (PUBLIC, PRIVATE or INTERFACE): /openmp and vcomp for ClangCL on
# Windows, find_package(OpenMP) otherwise (recorded as PUBLIC dependency for the installed config).
function(cs_target_use_openmp TARGET VISIBILITY)
  if(NOT TARGET ${TARGET})
    message(FATAL_ERROR "Target '${TARGET}' does not exist")
  endif()

  if(MSVC AND CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    # Windows + ClangCL
    message(NOTICE "Enabling OpenMP for ${TARGET} (ClangCL on Windows)")
    target_compile_options(${TARGET} ${VISIBILITY} /openmp)
    target_link_libraries(${TARGET} ${VISIBILITY} vcomp)
  else()
    # Clang or GCC on Linux/other
    message(
      NOTICE
      "Enabling OpenMP for ${TARGET} (non Clang on windows), If this fail, for clang on linux try `sudo apt install libomp-dev`"
    )
    cs_find_package(${TARGET} PUBLIC OpenMP REQUIRED)
    target_link_libraries(${TARGET} ${VISIBILITY} OpenMP::OpenMP_CXX)
  endif()
endfunction()
