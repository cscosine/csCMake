include_guard(GLOBAL)
include(utils/csFindPackage)

# Enable OpenMP on target_name with the given visibility (PUBLIC, PRIVATE or INTERFACE): /openmp and vcomp for ClangCL
# on Windows, find_package(OpenMP) otherwise (recorded as PUBLIC dependency for the installed config).
function(cs_target_use_openmp target_name visibility)
  if(NOT TARGET ${target_name})
    message(FATAL_ERROR "Target '${target_name}' does not exist")
  endif()

  if(MSVC AND CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    # Windows + ClangCL
    message(NOTICE "Enabling OpenMP for ${target_name} (ClangCL on Windows)")
    target_compile_options(${target_name} ${visibility} /openmp)
    target_link_libraries(${target_name} ${visibility} vcomp)
  else()
    # Clang or GCC on Linux/other
    message(NOTICE
            "Enabling OpenMP for ${target_name} (non Clang on windows), If this fail, for clang on linux try `sudo apt "
            "install libomp-dev`")
    cs_find_package(${target_name} PUBLIC OpenMP REQUIRED)
    target_link_libraries(${target_name} ${visibility} OpenMP::OpenMP_CXX)
  endif()
endfunction()
