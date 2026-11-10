#.rst:
# csPathUtils
# -----------
#
# Paths: the folders of the generated files.
#
# Commands
# ^^^^^^^^
include_guard(GLOBAL)

# Normalize (cmake_path NORMALIZE) every path of the list variable input_list_name of the caller.
function(_cs_path_list_normalize input_list_name)
  set(output_list "")
  foreach(path_item IN ITEMS ${${input_list_name}})
    cmake_path(SET normalized_path NORMALIZE "${path_item}")
    list(APPEND output_list ${normalized_path})
  endforeach()
  set(${input_list_name}
      ${output_list}
      PARENT_SCOPE)
endfunction()

# Return in out_list the unique parent folders of the files given after it.
function(_cs_unique_parent_dirs out_list)
  set(out_tmp "")
  foreach(file_path ${ARGN})
    get_filename_component(dir_path "${file_path}" DIRECTORY)
    _cs_list_add_unique_value(out_tmp ${dir_path})
  endforeach()
  set(${out_list}
      ${out_tmp}
      PARENT_SCOPE)
endfunction()

#.rst:
# .. command:: cs_get_generated_dir
#
#   Return the folder of the generated files shared by all the configurations: <build>/gen/ (an include folder of
#   <namespace>::cscmake_base_include).
#
#   .. code-block:: cmake
#
#     cs_get_generated_dir(<out-var>)
function(cs_get_generated_dir output_folder)
  set(folder "${CMAKE_BINARY_DIR}/gen/")
  set(${output_folder}
      "${folder}"
      PARENT_SCOPE)
endfunction()

#.rst:
# .. command:: cs_get_generated_config_dir
#
#   Return the folder of the configuration-specific generated files: <build>/gen-$<CONFIG>/ with multi-config
#   generators, <build>/gen/ otherwise (an include folder of <namespace>::cscmake_base_include).
#
#   .. code-block:: cmake
#
#     cs_get_generated_config_dir(<out-var>)
function(cs_get_generated_config_dir output_folder)

  get_property(generator_is_multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)

  if(generator_is_multi_config)
    # if multi-generator, use a -CONFIG folder
    set(folder "${CMAKE_BINARY_DIR}/gen-$<CONFIG>/")
    set(${output_folder}
        "${folder}"
        PARENT_SCOPE)
  else()
    # if not multigenerator, just get the common folder
    cs_get_generated_dir(folder)
    set(${output_folder}
        "${folder}"
        PARENT_SCOPE)
  endif()
endfunction()
