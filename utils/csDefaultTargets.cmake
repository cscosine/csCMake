include_guard(GLOBAL)
include(utils/csDebugMessage)

# creates two targets that the user can use in target_link_libraries
# ${PROJECT_NAME}_csCMakeBaseInclude - contains include directory of the main
# folder ${PROJECT_NAME}_csCMakeCompileOptionsDefault - contain common
# compilation flags, e.g. multithread compilation in windows - in particular, it
# contains the following specific targets: -- {PROJECT_NAME}MSVCParallelCompile
# with parallel compilation options for MSCV
# ${PROJECT_NAME}_csCMakeCompileOptionsStrict - contain common compilation
# flags, e.g. multithread compilation in windows - in particular, it contains
# the following specific targets: -- {PROJECT_NAME}MSVCParallelCompile with
# parallel compilation options for MSCV -- {PROJECT_NAME}StrictCompilation with
# all the warning to errors etc... all targets are installed too
function(_cs_add_default_targets)

  # create the base include, to be used in all project
  _cs_target_base_project_include_dir() # _csCMakeBaseInclude

  # ---------------------------------------------------
  # create MSVC parallel compilation flags
  _cs_target_msvc_parallel_compilation() # MSVCParallelCompile
  # TODO(sc) add a target that manages the version file etc

  # create a final target with name ${PROJECT_NAME}_csCMakeCompileOptionsDefault
  # that includes the default ones. TARGET_NAME will contains the name
  _cs_target_create_default(_csCMakeCompileOptionsDefault INTERFACE TARGET_NAME)
  # add the selected targets
  cs_target_link_libraries(${TARGET_NAME} INTERFACE
                           ${PROJECT_NAME}::${PROJECT_NAME}MSVCParallelCompile)

  _cs_target_create_default_finalize(_csCMakeCompileOptionsDefault)

  # ---------------------------------------------------
  # create the strict compiler options
  _cs_target_strict_compilation() # StrictCompilation

  # create a final target with name ${PROJECT_NAME}_csCMakeCompileOptionsStrict
  # that includes the strict ones. TARGET_NAME will contains the name
  _cs_target_create_default(_csCMakeCompileOptionsStrict INTERFACE TARGET_NAME)
  # add the selected targets
  cs_target_link_libraries(
    ${TARGET_NAME} INTERFACE ${PROJECT_NAME}::${PROJECT_NAME}StrictCompilation
    ${PROJECT_NAME}::${PROJECT_NAME}MSVCParallelCompile)
  _cs_target_create_default_finalize(_csCMakeCompileOptionsStrict)

endfunction()

# add a target named <ProjectName>_csCMakeBaseInclude, alias
# <ProjectName>::<ProjectName>_csCMakeBaseInclude that allow to propagate
# include directories to the root of the project
function(_cs_target_base_project_include_dir)
  _cs_target_create_default(_csCMakeBaseInclude INTERFACE TARGET_NAME)
  cs_get_install_folder_suffix(INSTALL_FOLDER_EXPRESSION)

  # add include to root dir, with subdir $<CONFIG> in installation if multiple
  # config, with single folder if individual
  target_include_directories(
    ${TARGET_NAME} INTERFACE $<INSTALL_INTERFACE:${INSTALL_FOLDER_EXPRESSION}>
                             $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>)

  # get the folder where files are generated
  cs_get_generate_folder_common(COMMON_FOLDER)
  cs_get_generate_folder_config(CONFIG_FOLDER)

  target_include_directories(
    ${TARGET_NAME} INTERFACE $<BUILD_INTERFACE:${COMMON_FOLDER}>
                             $<BUILD_INTERFACE:${CONFIG_FOLDER}>)

  _cs_target_create_default_finalize(_csCMakeBaseInclude)

endfunction()

function(_cs_target_msvc_parallel_compilation)
  _cs_target_create_default(MSVCParallelCompile INTERFACE TARGET_NAME)

  # add /MP and /Zc:__cplusplus
  target_compile_options(${TARGET_NAME} INTERFACE $<$<CXX_COMPILER_ID:MSVC>:
                                                  /MP /Zc:__cplusplus >)

  _cs_target_create_default_finalize(MSVCParallelCompile)

endfunction()

function(_cs_target_strict_compilation)

  _cs_target_create_default(StrictCompilation INTERFACE TARGET_NAME)

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

  csgetconfigurationwithstrictflags(CONFIGNAME)
  if(CONFIGNAME)
    # add sanitize options only for the specified configuration
    target_compile_options(
      ${TARGET_NAME}
      INTERFACE
        # both GNU and Clang but not on windows
        $<$<AND:$<CONFIG:${CONFIGNAME}>,$<CXX_COMPILER_ID:GNU,Clang>,$<NOT:$<PLATFORM_ID:Windows>>>:
        # -fsanitize=address # might cause false positives if 3rd parts are not
        # compiled with the very same flags
        -fsanitize=undefined
        # -fsanitize=leak # mutually exclusive with thread -fsanitize=thread #
        # mutually exclusive with address -fsanitize=pointer-compare  # might
        # cause false positives if 3rd parts are not compiled with the very same
        # flags -fsanitize=pointer-subtract # might cause false positives if 3rd
        # parts are not compiled with the very same flags
        >
        # Clang additions
        $<$<AND:$<CONFIG:${CONFIGNAME}>,$<CXX_COMPILER_ID:Clang>,$<NOT:$<PLATFORM_ID:Windows>>>:
        # -fsanitize=integer # might cause false positives if 3rd parts are not
        # compiled with the very same flags -fsanitize=nullability # might cause
        # false positives if 3rd parts are not compiled with the very same flags
        # -fsanitize=bounds  # might cause false positives if 3rd parts are not
        # compiled with the very same flags
        >)
    target_link_options(
      ${TARGET_NAME}
      INTERFACE
      $<$<AND:$<CONFIG:${CONFIGNAME}>,$<CXX_COMPILER_ID:GNU,Clang>,$<NOT:$<PLATFORM_ID:Windows>>>:
      # -fsanitize=address # might cause false positives if 3rd parts are not
      # compiled with the very same flags
      -fsanitize=undefined
      # -fsanitize=leak # mutually exclusive with thread -fsanitize=thread #
      # mutually exclusive with address -fsanitize=pointer-compare  # might
      # cause false positives if 3rd parts are not compiled with the very same
      # flags -fsanitize=pointer-subtract # might cause false positives if 3rd
      # parts are not compiled with the very same flags
      >
      # Clang additions
      $<$<AND:$<CONFIG:${CONFIGNAME}>,$<CXX_COMPILER_ID:Clang>,$<NOT:$<PLATFORM_ID:Windows>>>:
      # -fsanitize=integer # might cause false positives if 3rd parts are not
      # compiled with the very same flags -fsanitize=nullability # might cause
      # false positives if 3rd parts are not compiled with the very same flags
      # -fsanitize=bounds # might cause false positives if 3rd parts are not
      # compiled with the very same flags
      >)
  endif()

  _cs_target_create_default_finalize(StrictCompilation)

endfunction()

# create a empty target with coherent name, alias, export, etc...
function(_cs_target_create_default TARGET_SUB_NAME TARGET_TYPE TARGET_NAME_OUT)
  set(TARGET_NAME ${PROJECT_NAME}${TARGET_SUB_NAME})
  cs_add_library(${TARGET_NAME} ${TARGET_TYPE})
  cs_add_library(${PROJECT_NAME}::${TARGET_NAME} ALIAS ${TARGET_NAME})

  # return the target name
  set(${TARGET_NAME_OUT}
      ${TARGET_NAME}
      PARENT_SCOPE)
endfunction()

function(_cs_target_create_default_finalize TARGET_SUB_NAME)
  set(TARGET_NAME ${PROJECT_NAME}${TARGET_SUB_NAME})

  # add to its own export
  cs_install_target(${TARGET_NAME} ${PROJECT_NAME}_csCMakeCommon DEFAULT)

  cs_finalize_target(${TARGET_NAME})

endfunction()
