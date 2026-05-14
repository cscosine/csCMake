include_guard(GLOBAL)
include(utils/csPathUtils)

function(_cs_set_vs_debugger_env_variable TARGETS_LIST)
  cs_debug_message(
    "[_cs_set_vs_debugger_env_variable] targets: ${TARGETS_LIST}")

  # for each target, get the path with unique folders
  foreach(TARGET_NAME IN ITEMS ${TARGETS_LIST})

    set(P_CUMULATED "")
    cs_get_specified_build_configurations(CONFIGS_LIST)
    foreach(CONFIG ${CONFIGS_LIST})
      string(TOUPPER "${CONFIG}" CONFIG_UCASE)
      cs_get_target_dependencies_libraries_finalized(
        ${TARGET_NAME} ${CONFIG} TARGET_${CONFIG_UCASE}_DLLS)
      cs_extract_unique_folders_list_from_file_list(
        TARGET_${CONFIG_UCASE}_FOLDERS ${TARGET_${CONFIG_UCASE}_DLLS})

      cs_debug_message(
        "[_cs_set_vs_debugger_env_variable] target: ${TARGET_NAME} PATH ${CONFIG_UCASE} ${TARGET_${CONFIG_UCASE}_FOLDERS}"
      )

      set(TARGET_${CONFIG_UCASE}_FOLDERS_PATH
          "PATH=${TARGET_${CONFIG_UCASE}_FOLDERS}\n")

      # TODO(sc) add extra env variable here, e.g. qt plugins etc can be managed
      # in a second line with "QT_PLUGIN_PATH=..."
      set(EXTRA_ENV_VARIABLES_${CONFIG_UCASE} "")

      # set the full ENV
      set(VS_DEBUGGER_ENVIRONMENT_${CONFIG_UCASE}
          "${TARGET_${CONFIG_UCASE}_FOLDERS_PATH}${EXTRA_ENV_VARIABLES_${CONFIG_UCASE}}"
      )

      # set the full ENV to a target property
      set_property(
        TARGET ${TARGET_NAME}
        PROPERTY VS_DEBUGGER_ENVIRONMENT_${CONFIG_UCASE}
                 "${VS_DEBUGGER_ENVIRONMENT_${CONFIG_UCASE}}")

      # set a generator expression that retrieve the target properties
      set(P_${CONFIG_UCASE}
          "$<TARGET_PROPERTY:${TARGET_NAME},VS_DEBUGGER_ENVIRONMENT_${CONFIG_UCASE}>"
      ) # helper variable

      # set a string with generator expression that retrieve the target
      # properties
      set(P_${CONFIG_UCASE}_FULL "$<$<CONFIG:${CONFIG}>:${P_${CONFIG_UCASE}}>")

      # cumulate on loop
      set(P_CUMULATED "${P_CUMULATED}${P_${CONFIG_UCASE}_FULL}")
    endforeach()

    # set special VS variable, need to use generator expressions
    set_target_properties(${TARGET_NAME} PROPERTIES VS_DEBUGGER_ENVIRONMENT
                                                    "${P_CUMULATED}")

  endforeach()

endfunction()
