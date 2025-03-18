include_guard(GLOBAL)

function(_cs_path_list_normalize INPUT_LIST_NAME)
  set(OUTPUT_LIST "")
  foreach (PATH_ITEM IN ITEMS ${${INPUT_LIST_NAME}})
    cmake_path(SET NORMALIZED_PATH NORMALIZE "${PATH_ITEM}")
    list(APPEND OUTPUT_LIST ${NORMALIZED_PATH})
  endforeach()
  set(${INPUT_LIST_NAME} ${OUTPUT_LIST} PARENT_SCOPE)
endfunction()

function(cs_extract_unique_folders_list_from_file_list OUT_LIST)
	set(OUT_TMP "")
	foreach(FILE_PATH ${ARGN})
		get_filename_component(DIR_PATH "${FILE_PATH}" DIRECTORY)
		_cs_list_add_unique_value(OUT_TMP ${DIR_PATH})
	endforeach()
	SET(${OUT_LIST} ${OUT_TMP} PARENT_SCOPE)
endfunction()

function(cs_get_generate_folder_common OUTPUT_FOLDER)
  set(FOLDER "${CMAKE_BINARY_DIR}/csCMakeGenerated/")
  set(${OUTPUT_FOLDER} "${FOLDER}" PARENT_SCOPE)
endfunction()

function(cs_get_generate_folder_config OUTPUT_FOLDER)

  get_property(GENERATOR_IS_MULTI_CONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)

  if(GENERATOR_IS_MULTI_CONFIG)
    # if multi-generator, use a -CONFIG folder
    set(FOLDER "${CMAKE_BINARY_DIR}/csCMakeGenerated-$<CONFIG>/")
    set(${OUTPUT_FOLDER} "${FOLDER}" PARENT_SCOPE)
  else()
    # if not multigenerator, just get the common folder
    cs_get_generate_folder_common(FOLDER)
    set(${OUTPUT_FOLDER} "${FOLDER}" PARENT_SCOPE)
  endif()
endfunction()