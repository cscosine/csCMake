# Visual Studio debugger environment of the targets.
include_guard(GLOBAL)
include(utils/csPathUtils)

# Set the Visual Studio debugger environment of each target of targets_list, per configuration: PATH starts with the
# folders of its runtime libraries, then the PATH of the environment (%PATH%, expanded by Visual Studio). A
# configuration without runtime libraries keeps the default debugger_environment; a target without any keeps
# VS_DEBUGGER_ENVIRONMENT unset.
#
# Reads:
#
# * target property CSCMAKE_RUNTIME_LIBRARIES_<CONFIG>
#
# Writes:
#
# * target property VS_DEBUGGER_ENVIRONMENT, VS_DEBUGGER_ENVIRONMENT_<CONFIG>
function(_cs_set_vs_debugger_env_variable targets_list)
  cs_debug_message("[_cs_set_vs_debugger_env_variable] targets: ${targets_list}")
  cs_get_build_configurations(configs_list)

  foreach(target_name IN ITEMS ${targets_list})
    set(debugger_environment "")
    foreach(config ${configs_list})
      string(TOUPPER "${config}" config_ucase)
      cs_get_target_runtime_libraries(${target_name} ${config} libraries)
      _cs_unique_parent_dirs(folders ${libraries})
      cs_debug_message("[_cs_set_vs_debugger_env_variable] target: ${target_name} PATH ${config_ucase} ${folders}")
      if(NOT folders)
        continue()
      endif()

      # the value of each configuration in its own property, selected by configuration in VS_DEBUGGER_ENVIRONMENT
      set_property(TARGET ${target_name} PROPERTY VS_DEBUGGER_ENVIRONMENT_${config_ucase} "PATH=${folders};%PATH%")
      string(APPEND debugger_environment
             "$<$<CONFIG:${config}>:$<TARGET_PROPERTY:${target_name},VS_DEBUGGER_ENVIRONMENT_${config_ucase}>>")
    endforeach()

    if(debugger_environment)
      set_property(TARGET ${target_name} PROPERTY VS_DEBUGGER_ENVIRONMENT "${debugger_environment}")
    endif()
  endforeach()
endfunction()
