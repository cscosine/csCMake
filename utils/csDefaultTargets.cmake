include_guard(GLOBAL)
include(utils/csDebugMessage)

# Create the default targets of the project, to be linked by the project targets. Same name in the build tree and once
# installed, in the namespace given to cs_initialize_project:
#
# * <namespace>::cscmake_base_include: include folders (project source folder, generated files)
# * <namespace>::cscmake_compile_options: default compile options (cscmake_msvc_parallel_compile)
# * <namespace>::cscmake_compile_options_strict: the default ones plus cscmake_strict_warnings
#
# All of them are installed in the cscmake_common component (a default component).
function(_cs_add_default_targets)

  # create the base include, to be used in all project
  _cs_target_base_project_include_dir() # cscmake_base_include

  # ---------------------------------------------------
  # create MSVC parallel compilation flags
  _cs_target_msvc_parallel_compilation() # cscmake_msvc_parallel_compile
  # TODO(sc) add a target that manages the version file etc

  # <namespace>::cscmake_compile_options: the default compile options
  _cs_target_create_default(cscmake_compile_options INTERFACE target_name)
  cs_get_namespace(namespace)
  cs_target_link_libraries(${target_name} INTERFACE ${namespace}::cscmake_msvc_parallel_compile)

  _cs_target_create_default_finalize(cscmake_compile_options)

  # ---------------------------------------------------
  # create the strict compiler options
  _cs_target_strict_compilation() # cscmake_strict_warnings

  # <namespace>::cscmake_compile_options_strict: the default compile options plus the strict warnings
  _cs_target_create_default(cscmake_compile_options_strict INTERFACE target_name)
  cs_target_link_libraries(${target_name} INTERFACE ${namespace}::cscmake_strict_warnings
                                                    ${namespace}::cscmake_msvc_parallel_compile)
  _cs_target_create_default_finalize(cscmake_compile_options_strict)

endfunction()

# Create <namespace>::cscmake_base_include: include folders of the project (the folder of cs_initialize_project and the
# folders of the generated files).
function(_cs_target_base_project_include_dir)
  _cs_target_create_default(cscmake_base_include INTERFACE target_name)
  cs_get_install_include_dir(install_folder_expression)

  # add include to root dir, with subdir $<CONFIG> in installation if multiple config, with single folder if individual
  target_include_directories(${target_name} INTERFACE $<INSTALL_INTERFACE:${install_folder_expression}>
                                                      $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>)

  # get the folder where files are generated
  cs_get_generated_dir(common_folder)
  cs_get_generated_config_dir(config_folder)

  target_include_directories(${target_name} INTERFACE $<BUILD_INTERFACE:${common_folder}>
                                                      $<BUILD_INTERFACE:${config_folder}>)

  # create the folders now: an include folder must exist even when nothing is generated there (clang-cl reports a
  # missing include folder, -Wmissing-include-dirs, an error with the strict options)
  file(MAKE_DIRECTORY "${common_folder}")
  get_property(generator_is_multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
  if(generator_is_multi_config)
    cs_get_build_configurations(configs_list)
    foreach(config ${configs_list})
      string(REPLACE "$<CONFIG>" "${config}" config_folder_of_config "${config_folder}")
      file(MAKE_DIRECTORY "${config_folder_of_config}")
    endforeach()
  endif()

  _cs_target_create_default_finalize(cscmake_base_include)

endfunction()

# Create the <namespace>::cscmake_msvc_parallel_compile interface target, adding /MP and /Zc:__cplusplus on MSVC.
function(_cs_target_msvc_parallel_compilation)
  _cs_target_create_default(cscmake_msvc_parallel_compile INTERFACE target_name)

  # add /MP and /Zc:__cplusplus
  target_compile_options(${target_name} INTERFACE $<$<CXX_COMPILER_ID:MSVC>: /MP /Zc:__cplusplus >)

  _cs_target_create_default_finalize(cscmake_msvc_parallel_compile)

endfunction()

# Create the <namespace>::cscmake_strict_warnings interface target with the strict warning flags of each compiler (GCC,
# Clang, ClangCL, MSVC), warnings treated as errors.
function(_cs_target_strict_compilation)

  _cs_target_create_default(cscmake_strict_warnings INTERFACE target_name)

  # add compile options
  target_compile_options(
    ${target_name}
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

  cs_get_strict_build_configuration(configname)
  if(configname)
    # add sanitize options only for the specified configuration
    target_compile_options(
      ${target_name}
      INTERFACE # both GNU and Clang but not on windows
                $<$<AND:$<CONFIG:${configname}>,$<CXX_COMPILER_ID:GNU,Clang>,$<NOT:$<PLATFORM_ID:Windows>>>:
                # -fsanitize=address # might cause false positives if 3rd parts are not compiled with the very same
                # flags
                -fsanitize=undefined
                # -fsanitize=leak # mutually exclusive with thread -fsanitize=thread # mutually exclusive with address
                # -fsanitize=pointer-compare  # might cause false positives if 3rd parts are not compiled with the very
                # same flags -fsanitize=pointer-subtract # might cause false positives if 3rd parts are not compiled
                # with the very same flags
                >
                # Clang additions
                $<$<AND:$<CONFIG:${configname}>,$<CXX_COMPILER_ID:Clang>,$<NOT:$<PLATFORM_ID:Windows>>>:
                # -fsanitize=integer # might cause false positives if 3rd parts are not compiled with the very same
                # flags -fsanitize=nullability # might cause false positives if 3rd parts are not compiled with the very
                # same flags -fsanitize=bounds  # might cause false positives if 3rd parts are not compiled with the
                # very same flags
                >)
    target_link_options(
      ${target_name}
      INTERFACE
      $<$<AND:$<CONFIG:${configname}>,$<CXX_COMPILER_ID:GNU,Clang>,$<NOT:$<PLATFORM_ID:Windows>>>:
      # -fsanitize=address # might cause false positives if 3rd parts are not compiled with the very same flags
      -fsanitize=undefined
      # -fsanitize=leak # mutually exclusive with thread -fsanitize=thread # mutually exclusive with address
      # -fsanitize=pointer-compare  # might cause false positives if 3rd parts are not compiled with the very same flags
      # -fsanitize=pointer-subtract # might cause false positives if 3rd parts are not compiled with the very same flags
      >
      # Clang additions
      $<$<AND:$<CONFIG:${configname}>,$<CXX_COMPILER_ID:Clang>,$<NOT:$<PLATFORM_ID:Windows>>>:
      # -fsanitize=integer # might cause false positives if 3rd parts are not compiled with the very same flags
      # -fsanitize=nullability # might cause false positives if 3rd parts are not compiled with the very same flags
      # -fsanitize=bounds # might cause false positives if 3rd parts are not compiled with the very same flags
      >)
  endif()

  _cs_target_create_default_finalize(cscmake_strict_warnings)

endfunction()

# Create the empty default target <project>_<target_sub_name> (unique in the build tree, also with several csCMake
# projects) of type target_type, return its name in target_name_out. It is exported as <target_sub_name> (EXPORT_NAME)
# and aliased as <namespace>::<target_sub_name>: the same name in the build tree and once installed.
function(_cs_target_create_default target_sub_name target_type target_name_out)
  set(target_name ${PROJECT_NAME}_${target_sub_name})
  cs_get_namespace(namespace)
  cs_add_library(${target_name} ${target_type})
  set_target_properties(${target_name} PROPERTIES EXPORT_NAME ${target_sub_name})
  cs_add_library(${namespace}::${target_sub_name} ALIAS ${target_name})

  # return the target name
  set(${target_name_out}
      ${target_name}
      PARENT_SCOPE)
endfunction()

# Finalize a default target created with _cs_target_create_default: install it in the cscmake_common component (a
# default component) and run cs_finalize_target on it.
function(_cs_target_create_default_finalize target_sub_name)
  set(target_name ${PROJECT_NAME}_${target_sub_name})
  cs_install_target(${target_name} cscmake_common DEFAULT)

  cs_finalize_target(${target_name})

endfunction()
