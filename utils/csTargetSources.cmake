include_guard(GLOBAL)
include(utils/csDebugMessage)

# support the three types as in target_sources PRIVATE PUBLIC INTERFACE 
# however, supports PRIVATE_INSTALL PUBLIC_INSTALL INTERFACE_INSTALL to add the files to a list of file to be installed when the target is installed
# note: includes does not need to be PUBLIC, therefore, normally only PRIVATE and PRIVATE_INSTALL are used
# it adds all headers to be installed to the target a property csSourcesToInstall so that can be easily retrieved
function(cs_target_sources TARGET_NAME)
	cs_debug_message("[cs_target_sources] target ${TARGET_NAME} find ${ARGN}")
	
	# split arguments in groups according to keywords
	set(KEYWORDS PRIVATE PUBLIC INTERFACE PRIVATE_INSTALL PUBLIC_INSTALL INTERFACE_INSTALL)
	cmake_parse_arguments(ARG "" "" "${KEYWORDS}" ${ARGN})
	
	# retrieve the relative install path
	file(RELATIVE_PATH DESTINATION_FOLDER ${CMAKE_SOURCE_DIR} ${CMAKE_CURRENT_LIST_DIR})
	cs_debug_message("[cs_target_sources] relative install path is ${DESTINATION_FOLDER}")

	set(SOURCES_TO_INSTALL "")

	# get the different groups
	foreach(BASE_TYPE IN ITEMS PRIVATE PUBLIC INTERFACE)

		# add the files not to be installed
		cs_debug_message("[cs_target_sources] ARG_${BASE_TYPE} contains ${ARG_${BASE_TYPE}}")
		foreach(_FILE ${ARG_${BASE_TYPE}})
			target_sources(${TARGET_NAME} ${BASE_TYPE}
				$<BUILD_INTERFACE:${_FILE}>
			)		
		endforeach()

		# add the files to be installed
		cs_debug_message("[cs_target_sources] ARG_${BASE_TYPE}_INSTALL contains ${ARG_${BASE_TYPE}_INSTALL}")
		foreach(_FILE ${ARG_${BASE_TYPE}_INSTALL})
			target_sources(${TARGET_NAME} ${BASE_TYPE}
				$<BUILD_INTERFACE:${_FILE}>
			)		
			_cs_add_to_target_property_unique_value(${TARGET_NAME} csSourcesToInstall "${_FILE}")
		endforeach()

	endforeach()
endfunction()

# return the csSourcesToInstall property of the target, i.e., a list, eventually empty
function(cs_get_target_sources_to_install TARGET_NAME OUTPUT_VARIABLE_NAME)
  get_target_property(LIST_VALUES ${TARGET_NAME} csSourcesToInstall)
  if(LIST_VALUES)
    # if exists
    set(${OUTPUT_VARIABLE_NAME} ${LIST_VALUES} PARENT_SCOPE)
  else()
    # otherwise set to empty list
    set(${OUTPUT_VARIABLE_NAME} "" PARENT_SCOPE)
  endif()
endfunction()
 
function(cs_print_target_sources_to_install TARGET_NAME)
  set(_VALUES "")
  cs_get_target_sources_to_install("${TARGET_NAME}" _VALUES )
  list(LENGTH _VALUES N)
  if(N GREATER 0)
    message(STATUS "cs_print_target_sources_to_install ${TARGET_NAME}: ${_VALUES}")
  else()
    message(STATUS "cs_print_target_sources_to_install ${TARGET_NAME}: empty")
  endif()
endfunction()
