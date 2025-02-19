include_guard(GLOBAL)
include(utils/csPathUtils)

function(_cs_set_vs_debugger_env_variable TARGETS_LIST)
  cs_debug_message("[_cs_set_vs_debugger_env_variable] targets: ${TARGETS_LIST}")

	# for each target, get the path with unique folders
  foreach (TARGET_NAME IN ITEMS ${TARGETS_LIST})
		cs_get_target_dependencies_debug_libraries_finalized(${TARGET_NAME} TARGET_DEBUG_DLLS)
		cs_extract_unique_folders_list_from_file_list(TARGET_DEBUG_FOLDERS ${TARGET_DEBUG_DLLS})

		cs_get_target_dependencies_release_libraries_finalized(${TARGET_NAME} TARGET_RELEASE_DLLS)
		cs_extract_unique_folders_list_from_file_list(TARGET_RELEASE_FOLDERS ${TARGET_RELEASE_DLLS})

		cs_debug_message("[_cs_set_vs_debugger_env_variable] target: ${TARGET_NAME} PATH DEBUG ${TARGET_DEBUG_FOLDERS}")
		cs_debug_message("[_cs_set_vs_debugger_env_variable] target: ${TARGET_NAME} PATH RELEASE ${TARGET_RELEASE_FOLDERS}")

    set(TARGET_DEBUG_FOLDERS_PATH "PATH=${TARGET_DEBUG_FOLDERS}\n")
    set(TARGET_RELEASE_FOLDERS_PATH "PATH=${TARGET_RELEASE_FOLDERS}\n")

    # TODO(sc) add extra env variable here, e.g. qt plugins etc can be managed in a second line with "QT_PLUGIN_PATH=..."
    set(EXTRA_ENV_VARIABLES_DEBUG "")
    set(EXTRA_ENV_VARIABLES_RELEASE "")

    # set the full ENV 
    set(VS_DEBUGGER_ENVIRONMENT_DEBUG "${TARGET_DEBUG_FOLDERS_PATH}${EXTRA_ENV_VARIABLES_DEBUG}")
    set(VS_DEBUGGER_ENVIRONMENT_RELEASE "${TARGET_RELEASE_FOLDERS_PATH}${EXTRA_ENV_VARIABLES_RELEASE}")

    # set the full ENV to a target property
    set_property(TARGET ${TARGET_NAME} PROPERTY VS_DEBUGGER_ENVIRONMENT_DEBUG "${VS_DEBUGGER_ENVIRONMENT_DEBUG}")
    set_property(TARGET ${TARGET_NAME} PROPERTY VS_DEBUGGER_ENVIRONMENT_RELEASE "${VS_DEBUGGER_ENVIRONMENT_RELEASE}")


    # set a generator expression that retrieve the target properties
    set(P_RELEASE "$<TARGET_PROPERTY:${TARGET_NAME},VS_DEBUGGER_ENVIRONMENT_RELEASE>") # helper variable
    set(P_DEBUG "$<TARGET_PROPERTY:${TARGET_NAME},VS_DEBUGGER_ENVIRONMENT_DEBUG>") # helper variable

    # set special VS variable, need to use generator expressions
    set_target_properties(${TARGET_NAME}
        PROPERTIES VS_DEBUGGER_ENVIRONMENT "$<$<CONFIG:Debug>:${P_DEBUG}>$<$<CONFIG:Release>:${P_RELEASE}>"
    )

    # TODO(sc) if needed, add $<$<CONFIG:RelWithDebInfo>:${P_RELEASE}> or manage properly relWithDebInfo

	endforeach()

endfunction()
