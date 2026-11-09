include_guard(GLOBAL)
include(utils/csPathUtils)

# For each target of targets_list set VS_DEBUGGER_ENVIRONMENT, per configuration, so that the Visual Studio debugger
# finds the runtime dependencies (PATH with the folders of the dependency DLLs).
function(_cs_set_vs_debugger_env_variable targets_list)
  cs_debug_message("[_cs_set_vs_debugger_env_variable] targets: ${targets_list}")

  # for each target, get the path with unique folders
  foreach(target_name IN ITEMS ${targets_list})

    set(p_cumulated "")
    cs_get_build_configurations(configs_list)
    foreach(config ${configs_list})
      string(TOUPPER "${config}" config_ucase)
      cs_get_target_runtime_libraries(${target_name} ${config} target_${config_ucase}_dlls)
      _cs_unique_parent_dirs(target_${config_ucase}_folders ${target_${config_ucase}_dlls})

      cs_debug_message(
        "[_cs_set_vs_debugger_env_variable] target: ${target_name} PATH ${config_ucase} ${target_${config_ucase}_folders}"
      )

      set(target_${config_ucase}_folders_path "PATH=${target_${config_ucase}_folders}\n")

      # TODO(sc) add extra env variable here, e.g. qt plugins etc can be managed in a second line with
      # "QT_PLUGIN_PATH=..."
      set(extra_env_variables_${config_ucase} "")

      # set the full ENV
      set(vs_debugger_environment_${config_ucase}
          "${target_${config_ucase}_folders_path}${extra_env_variables_${config_ucase}}")

      # set the full ENV to a target property
      set_property(TARGET ${target_name} PROPERTY VS_DEBUGGER_ENVIRONMENT_${config_ucase}
                                                  "${vs_debugger_environment_${config_ucase}}")

      # set a generator expression that retrieve the target properties
      set(p_${config_ucase} "$<TARGET_PROPERTY:${target_name},VS_DEBUGGER_ENVIRONMENT_${config_ucase}>") # helper
                                                                                                         # variable

      # set a string with generator expression that retrieve the target properties
      set(p_${config_ucase}_full "$<$<CONFIG:${config}>:${p_${config_ucase}}>")

      # cumulate on loop
      set(p_cumulated "${p_cumulated}${p_${config_ucase}_full}")
    endforeach()

    # set special VS variable, need to use generator expressions
    set_target_properties(${target_name} PROPERTIES VS_DEBUGGER_ENVIRONMENT "${p_cumulated}")

  endforeach()

endfunction()
