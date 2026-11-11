#.rst:
# csOpenMP
# --------
#
# OpenMP.
#
# Commands
# ^^^^^^^^
include_guard(GLOBAL)
include(modules/csDebug)
include(modules/csFindPackage)

#.rst:
# .. command:: cs_target_use_openmp
#
#   Enable OpenMP on a target.
#
#   .. code-block:: cmake
#
#     cs_target_use_openmp(<target> PUBLIC|PRIVATE|INTERFACE)
#
#   ClangCL on Windows: /openmp and vcomp; otherwise ``find_package(OpenMP REQUIRED)`` and OpenMP::OpenMP_CXX.
#   ``find_package(OpenMP)`` goes to the installed package (:command:`cs_find_package` ``PUBLIC``) when its consumers
#   need it: ``PUBLIC`` and ``INTERFACE``, and ``PRIVATE`` on a static or object library (its consumers link OpenMP).
#
#   ``<target>``
#     A target of the project.
#
#   ``PUBLIC``, ``PRIVATE``, ``INTERFACE``
#     The scope of the OpenMP options and library, as in :command:`target_link_libraries`.
function(cs_target_use_openmp target_name visibility)
  _cs_message_context(cs_target_use_openmp)
  if(NOT TARGET ${target_name})
    message(FATAL_ERROR "[cs_target_use_openmp] ${target_name} is not a target")
  endif()
  if(NOT visibility MATCHES "^(PUBLIC|PRIVATE|INTERFACE)$")
    message(FATAL_ERROR "[cs_target_use_openmp] the scope is PUBLIC, PRIVATE or INTERFACE, got ${visibility}")
  endif()

  if(MSVC AND CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    # ClangCL: the OpenMP runtime of MSVC
    message(VERBOSE "${CSCMAKE_NAMESPACE}: ${target_name} uses OpenMP: /openmp and vcomp (ClangCL)")
    target_compile_options(${target_name} ${visibility} /openmp)
    target_link_libraries(${target_name} ${visibility} vcomp)
    return()
  endif()

  # the consumers of the installed package need find_package(OpenMP) when they link OpenMP::OpenMP_CXX too
  get_target_property(target_type ${target_name} TYPE)
  set(propagate PRIVATE)
  if(NOT visibility STREQUAL "PRIVATE" OR target_type MATCHES "^(STATIC|OBJECT)_LIBRARY$")
    set(propagate PUBLIC)
  endif()
  message(VERBOSE "${CSCMAKE_NAMESPACE}: ${target_name} uses OpenMP: OpenMP::OpenMP_CXX ${visibility}")
  cs_find_package(${target_name} ${propagate} OpenMP REQUIRED)
  target_link_libraries(${target_name} ${visibility} OpenMP::OpenMP_CXX)
endfunction()
