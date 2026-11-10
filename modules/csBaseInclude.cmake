#.rst:
# csBaseInclude
# -------------
#
# The default target of a project, ``<namespace>::cscmake_base_include``, created by
# :command:`cs_initialize_project`: the include folders of the project (the folder of
# :command:`cs_initialize_project`, the folders of the generated files, :command:`cs_get_generated_dir` and
# :command:`cs_get_generated_config_dir`), the same name in the build tree and once installed, installed in
# the ``cscmake_common`` component (a default component). Link it from the targets of the project.
#
# Commands
# ^^^^^^^^

include_guard(GLOBAL)
include(modules/csDebug)
include(modules/csInternal)

#.rst:
# .. command:: cs_get_generated_dir
#
#   Return the folder of the generated files shared by all the configurations: <build>/gen/ (an include folder of
#   <namespace>::cscmake_base_include).
#
#   .. code-block:: cmake
#
#     cs_get_generated_dir(<out-var>)
#
#   ``<out-var>``
#     The variable to set, in the scope of the caller.
function(cs_get_generated_dir output_folder)
  set(folder "${CMAKE_BINARY_DIR}/gen/")
  set(${output_folder} "${folder}" PARENT_SCOPE)
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
#
#   ``<out-var>``
#     The variable to set, in the scope of the caller.
function(cs_get_generated_config_dir output_folder)
  get_property(generator_is_multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)

  if(generator_is_multi_config)
    # if multi-generator, use a -CONFIG folder
    set(folder "${CMAKE_BINARY_DIR}/gen-$<CONFIG>/")
    set(${output_folder} "${folder}" PARENT_SCOPE)
  else()
    # if not multigenerator, just get the common folder
    cs_get_generated_dir(folder)
    set(${output_folder} "${folder}" PARENT_SCOPE)
  endif()
endfunction()

# Create the default target of the project, <namespace>::cscmake_base_include (compile options come from the compile
# profiles).
function(_cs_add_default_targets)
  _cs_target_base_project_include_dir()
endfunction()

# Return in output_variable the include folders of the installed package, for the consumers: a list of
# $<INSTALL_INTERFACE:...> entries. One configuration: CMAKE_INSTALL_INCLUDEDIR. Several: the headers are installed per
# configuration, one entry per configuration, $<$<CONFIG:<config>>:$<INSTALL_PREFIX>/<includedir>/<config>>: in the
# usage requirements of an imported target $<CONFIG:...> also matches the configuration CMake selects for it (the mapped
# ones of MAP_IMPORTED_CONFIG_<CONFIG>), so the headers come from the same configuration as the library; a configuration
# the package does not have, and not mapped, gets no folder (not a missing one). Absolute ($<INSTALL_PREFIX>): CMake
# prefixes a relative entry with the install prefix even when it evaluates to nothing.
function(_cs_installed_include_dirs output_variable)
  _cs_headers_per_configuration(per_configuration)
  if(NOT per_configuration)
    set(${output_variable} "$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>" PARENT_SCOPE)
    return()
  endif()
  cs_get_build_configurations(configs_list)
  set(dirs "")
  foreach(config ${configs_list})
    list(
      APPEND dirs
      "$<INSTALL_INTERFACE:$<$<CONFIG:${config}>:$<INSTALL_PREFIX>/${CMAKE_INSTALL_INCLUDEDIR}/${config}>>"
    )
  endforeach()
  set(${output_variable} "${dirs}" PARENT_SCOPE)
endfunction()

# Create <namespace>::cscmake_base_include: include folders of the project (the folder of cs_initialize_project, the
# generated files folders, created at configure time).
function(_cs_target_base_project_include_dir)
  _cs_target_create_default(cscmake_base_include INTERFACE target_name)
  _cs_installed_include_dirs(installed_include_dirs)

  target_include_directories(
    ${target_name}
    INTERFACE ${installed_include_dirs} $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
  )

  # get the folder where files are generated
  cs_get_generated_dir(common_folder)
  cs_get_generated_config_dir(config_folder)

  target_include_directories(
    ${target_name}
    INTERFACE $<BUILD_INTERFACE:${common_folder}> $<BUILD_INTERFACE:${config_folder}>
  )

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
  set(${target_name_out} ${target_name} PARENT_SCOPE)
endfunction()

# Install the default target in the cscmake_common component (a default component) and finalize it.
function(_cs_target_create_default_finalize target_sub_name)
  set(target_name ${PROJECT_NAME}_${target_sub_name})
  cs_install_target(${target_name} cscmake_common DEFAULT)

  cs_finalize_target(${target_name})
endfunction()
