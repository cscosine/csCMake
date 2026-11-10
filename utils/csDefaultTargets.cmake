# The default target of a project: <namespace>::cscmake_base_include.
include_guard(GLOBAL)
include(utils/csDebugMessage)

# Create the default target of the project, <namespace>::cscmake_base_include (compile options come from the compile
# profiles).
function(_cs_add_default_targets)
  _cs_target_base_project_include_dir()
endfunction()

# Create <namespace>::cscmake_base_include: include folders of the project (the folder of cs_initialize_project, the
# generated files folders, created at configure time).
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
  # missing include folder, -Wmissing-include-dirs, an error with -Werror)
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

# Create the empty default target <project>_<target_sub_name> of type target_type (unique in the build tree), exported
# as <target_sub_name> and aliased as <namespace>::<target_sub_name>; return its name in target_name_out.
#
# Writes:
#
# * target property EXPORT_NAME
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

# Install the default target in the cscmake_common component (a default component) and finalize it.
function(_cs_target_create_default_finalize target_sub_name)
  set(target_name ${PROJECT_NAME}_${target_sub_name})
  cs_install_target(${target_name} cscmake_common DEFAULT)

  cs_finalize_target(${target_name})

endfunction()
