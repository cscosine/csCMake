include_guard(GLOBAL)
include(utils/csFindPackage)

function(csUseOpenMPOnTarget TARGET VISIBILITY)
    if(NOT TARGET ${TARGET})
        message(FATAL_ERROR "Target '${TARGET}' does not exist")
    endif()

    if(MSVC AND CMAKE_CXX_COMPILER_ID MATCHES "Clang")
        # Windows + ClangCL
        message(STATUS "Enabling OpenMP for ${TARGET} (ClangCL on Windows)")
        target_compile_options(${TARGET} ${VISIBILITY} /openmp)
        target_link_libraries(${TARGET} ${VISIBILITY} vcomp)
    else()
        # Clang or GCC on Linux/other
        message(STATUS "Enabling OpenMP for ${TARGET} (non Clang on windows)")
        message(STATUS "Looking for OpenMP. If this fail, for clang on linux try `sudo apt install libomp-dev`")
        cs_find_package(${TARGET} PUBLIC OpenMP REQUIRED)
        target_link_libraries(${TARGET} ${VISIBILITY} OpenMP::OpenMP_CXX)
    endif()
endfunction()
