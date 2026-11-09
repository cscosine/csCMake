include_guard(GLOBAL)
include(utils/csDebugMessage)

# Create the default targets of the project, to be linked by the project targets. Same name in the build tree and once
# installed, in the namespace given to cs_initialize_project:
#
# * <namespace>::cscmake_base_include: include folders (project source folder, generated files)
# * <namespace>::cscmake_compile_options: default compile options (cscmake_msvc_parallel_compile)
# * <namespace>::cscmake_compile_options_strict: the default ones plus cscmake_strict_warnings
#
# All of them are installed in the <namespace>_cscmake_common component (a default component).
function(_cs_add_default_targets)

  # create the base include, to be used in all project
  _cs_target_base_project_include_dir() # cscmake_base_include

  # ---------------------------------------------------
  # create MSVC parallel compilation flags
  _cs_target_msvc_parallel_compilation() # cscmake_msvc_parallel_compile
  # TODO(sc) add a target that manages the version file etc

  # <namespace>::cscmake_compile_options: the default compile options
  _cs_target_create_default(cscmake_compile_options INTERFACE TARGET_NAME)
  cs_get_namespace(NAMESPACE)
  cs_target_link_libraries(${TARGET_NAME} INTERFACE ${NAMESPACE}::cscmake_msvc_parallel_compile)

  _cs_target_create_default_finalize(cscmake_compile_options)

  # ---------------------------------------------------
  # create the strict compiler options
  _cs_target_strict_compilation() # cscmake_strict_warnings

  # <namespace>::cscmake_compile_options_strict: the default compile options plus the strict warnings
  _cs_target_create_default(cscmake_compile_options_strict INTERFACE TARGET_NAME)
  cs_target_link_libraries(${TARGET_NAME} INTERFACE ${NAMESPACE}::cscmake_strict_warnings
                           ${NAMESPACE}::cscmake_msvc_parallel_compile)
  _cs_target_create_default_finalize(cscmake_compile_options_strict)

endfunction()

# Create <namespace>::cscmake_base_include: include folders of the project (the folder of cs_initialize_project and the
# folders of the generated files).
function(_cs_target_base_project_include_dir)
  _cs_target_create_default(cscmake_base_include INTERFACE TARGET_NAME)
  cs_get_install_include_dir(INSTALL_FOLDER_EXPRESSION)

  # add include to root dir, with subdir $<CONFIG> in installation if multiple config, with single folder if individual
  target_include_directories(${TARGET_NAME} INTERFACE $<INSTALL_INTERFACE:${INSTALL_FOLDER_EXPRESSION}>
                                                      $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>)

  # get the folder where files are generated
  cs_get_generated_dir(COMMON_FOLDER)
  cs_get_generated_config_dir(CONFIG_FOLDER)

  target_include_directories(${TARGET_NAME} INTERFACE $<BUILD_INTERFACE:${COMMON_FOLDER}>
                                                      $<BUILD_INTERFACE:${CONFIG_FOLDER}>)

  # create the folders now: an include folder must exist even when nothing is generated there (clang-cl reports a
  # missing include folder, -Wmissing-include-dirs, an error with the strict options)
  file(MAKE_DIRECTORY "${COMMON_FOLDER}")
  get_property(GENERATOR_IS_MULTI_CONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
  if(GENERATOR_IS_MULTI_CONFIG)
    cs_get_build_configurations(CONFIGS_LIST)
    foreach(CONFIG ${CONFIGS_LIST})
      string(REPLACE "$<CONFIG>" "${CONFIG}" CONFIG_FOLDER_OF_CONFIG "${CONFIG_FOLDER}")
      file(MAKE_DIRECTORY "${CONFIG_FOLDER_OF_CONFIG}")
    endforeach()
  endif()

  _cs_target_create_default_finalize(cscmake_base_include)

endfunction()

# Create the <namespace>::cscmake_msvc_parallel_compile interface target, adding /MP and /Zc:__cplusplus on MSVC.
function(_cs_target_msvc_parallel_compilation)
  _cs_target_create_default(cscmake_msvc_parallel_compile INTERFACE TARGET_NAME)

  # add /MP and /Zc:__cplusplus
  target_compile_options(${TARGET_NAME} INTERFACE $<$<CXX_COMPILER_ID:MSVC>: /MP /Zc:__cplusplus >)

  _cs_target_create_default_finalize(cscmake_msvc_parallel_compile)

endfunction()

# Create the <namespace>::cscmake_strict_warnings interface target with the strict warning flags of each compiler (GCC,
# Clang, ClangCL, MSVC), warnings treated as errors.
function(_cs_target_strict_compilation)

  _cs_target_create_default(cscmake_strict_warnings INTERFACE TARGET_NAME)

  # add compile options
  target_compile_options(
    ${TARGET_NAME}
    INTERFACE # both GNU and Clang
              $<$<CXX_COMPILER_ID:GNU,Clang>:
              -Wall
              -Wextra
              -Wpedantic
              -Wconversion
              -Wsign-conversion
              -Wshadow
              -Wnon-virtual-dtor
              -Wold-style-cast
              -Wfloat-equal
              -Winit-self
              -Wuninitialized
              -Wunused
              -Wreorder
              -Wcast-align
              -Wformat=2
              -Wnull-dereference
              -Wdouble-promotion
              -Wzero-as-null-pointer-constant
              -Werror # Treat all warnings as errors
              >
              # remove some on MSVC CLANG
              $<$<AND:$<PLATFORM_ID:Windows>,$<CXX_COMPILER_ID:Clang>>:
              -Wno-c++98-compat
              -Wno-c++98-compat-pedantic
              -Wno-c++20-extensions # otherwise clang on msvc will not work
              >
              # GNU only
              $<$<CXX_COMPILER_ID:GNU>:
              -Wstrict-null-sentinel
              -Wlogical-op
              -Wduplicated-cond
              -Wduplicated-branches
              >
              # MSVC
              $<$<CXX_COMPILER_ID:MSVC>:
              /W4
              /WX
              /permissive-
              >)

  cs_get_strict_build_configuration(CONFIGNAME)
  if(CONFIGNAME)
    # add sanitize options only for the specified configuration
    target_compile_options(
      ${TARGET_NAME}
      INTERFACE # both GNU and Clang but not on windows
                $<$<AND:$<CONFIG:${CONFIGNAME}>,$<CXX_COMPILER_ID:GNU,Clang>,$<NOT:$<PLATFORM_ID:Windows>>>:
                # -fsanitize=address # might cause false positives if 3rd parts are not compiled with the very same
                # flags
                -fsanitize=undefined
                # -fsanitize=leak # mutually exclusive with thread -fsanitize=thread # mutually exclusive with address
                # -fsanitize=pointer-compare  # might cause false positives if 3rd parts are not compiled with the very
                # same flags -fsanitize=pointer-subtract # might cause false positives if 3rd parts are not compiled
                # with the very same flags
                >
                # Clang additions
                $<$<AND:$<CONFIG:${CONFIGNAME}>,$<CXX_COMPILER_ID:Clang>,$<NOT:$<PLATFORM_ID:Windows>>>:
                # -fsanitize=integer # might cause false positives if 3rd parts are not compiled with the very same
                # flags -fsanitize=nullability # might cause false positives if 3rd parts are not compiled with the very
                # same flags -fsanitize=bounds  # might cause false positives if 3rd parts are not compiled with the
                # very same flags
                >)
    target_link_options(
      ${TARGET_NAME}
      INTERFACE
      $<$<AND:$<CONFIG:${CONFIGNAME}>,$<CXX_COMPILER_ID:GNU,Clang>,$<NOT:$<PLATFORM_ID:Windows>>>:
      # -fsanitize=address # might cause false positives if 3rd parts are not compiled with the very same flags
      -fsanitize=undefined
      # -fsanitize=leak # mutually exclusive with thread -fsanitize=thread # mutually exclusive with address
      # -fsanitize=pointer-compare  # might cause false positives if 3rd parts are not compiled with the very same flags
      # -fsanitize=pointer-subtract # might cause false positives if 3rd parts are not compiled with the very same flags
      >
      # Clang additions
      $<$<AND:$<CONFIG:${CONFIGNAME}>,$<CXX_COMPILER_ID:Clang>,$<NOT:$<PLATFORM_ID:Windows>>>:
      # -fsanitize=integer # might cause false positives if 3rd parts are not compiled with the very same flags
      # -fsanitize=nullability # might cause false positives if 3rd parts are not compiled with the very same flags
      # -fsanitize=bounds # might cause false positives if 3rd parts are not compiled with the very same flags
      >)
  endif()

  _cs_target_create_default_finalize(cscmake_strict_warnings)

endfunction()

# Create the empty default target <project>_<TARGET_SUB_NAME> (unique in the build tree, also with several csCMake
# projects) of type TARGET_TYPE, return its name in TARGET_NAME_OUT. It is exported as <TARGET_SUB_NAME> (EXPORT_NAME)
# and aliased as <namespace>::<TARGET_SUB_NAME>: the same name in the build tree and once installed.
function(_cs_target_create_default TARGET_SUB_NAME TARGET_TYPE TARGET_NAME_OUT)
  set(TARGET_NAME ${PROJECT_NAME}_${TARGET_SUB_NAME})
  cs_get_namespace(NAMESPACE)
  cs_add_library(${TARGET_NAME} ${TARGET_TYPE})
  set_target_properties(${TARGET_NAME} PROPERTIES EXPORT_NAME ${TARGET_SUB_NAME})
  cs_add_library(${NAMESPACE}::${TARGET_SUB_NAME} ALIAS ${TARGET_NAME})

  # return the target name
  set(${TARGET_NAME_OUT}
      ${TARGET_NAME}
      PARENT_SCOPE)
endfunction()

# Finalize a default target created with _cs_target_create_default: install it in the <namespace>_cscmake_common
# component (a default component) and run cs_finalize_target on it.
function(_cs_target_create_default_finalize TARGET_SUB_NAME)
  set(TARGET_NAME ${PROJECT_NAME}_${TARGET_SUB_NAME})
  cs_get_namespace(NAMESPACE)

  # the namespace prefix keeps the component name unique when a consumer loads several csCMake packages (the generated
  # Config sets <component>_DEPENDENT_EXPORTS globally, see PLAN.md 3b)
  cs_install_target(${TARGET_NAME} ${NAMESPACE}_cscmake_common DEFAULT)

  cs_finalize_target(${TARGET_NAME})

endfunction()
