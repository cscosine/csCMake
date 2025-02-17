include_guard(GLOBAL)
include(utils/csDebugMessage)
include(utils/csListUtils)

# target additional properties
# - csTargetDependenciesDebug
# - csTargetDependenciesRelease

function (_cs_recursive_analyze_target TARGET_NAME)
	# get target type
	get_target_property(TARGET_TYPE ${TARGET_NAME} TYPE)
	if(${TARGET_TYPE} STREQUAL "INTERFACE_LIBRARY")
		csDebugMessage("[_cs_recursive_analyze_target] early return for ${base_target}, reason: TARGET_TYPE is INTERFACE_LIBRARY")
		return()
	endif()

	# initialize the iterative list of target to analyze
	set(TARGETS_TO_ANALYZE_LIST ${TARGET_NAME})
	list(LENGTH TARGETS_TO_ANALYZE_LIST TARGETS_TO_ANALYZE_SIZE)

	# loop
	while(TARGETS_TO_ANALYZE_SIZE GREATER 0)
			# get the first target in the list
			list(GET TARGETS_TO_ANALYZE_LIST 0 TARGET_TO_ANALYZE)
			# and remove it
			list(REMOVE_AT TARGETS_TO_ANALYZE_LIST 0)

			# # get target type
			if(TARGET ${TARGET_TO_ANALYZE})
				# get type and imported properties
				get_target_property(TARGET_TO_ANALYZE_TYPE ${TARGET_TO_ANALYZE} TYPE)
				get_target_property(TARGET_TO_ANALYZE_IMPORTED ${TARGET_TO_ANALYZE} IMPORTED)
				
				# check aliasing and retrieve original name
				get_target_property(ALIASED_TARGET_TO_ANALYZE ${TARGET_TO_ANALYZE} ALIASED_TARGET)
				if(ALIASED_TARGET_TO_ANALYZE)
					csDebugMessage("[_cs_recursive_analyze_target] TARGET_TO_ANALYZE ${TARGET_TO_ANALYZE} ALIAS ${ALIASED_TARGET_TO_ANALYZE} TYPE ${TARGET_TO_ANALYZE_TYPE} IMPORTED ${TARGET_TO_ANALYZE_IMPORTED}")
					SET(TARGET_TO_ANALYZE "${ALIASED_TARGET_TO_ANALYZE}")
				else()
					csDebugMessage("[_cs_recursive_analyze_target] TARGET_TO_ANALYZE ${TARGET_TO_ANALYZE} TYPE ${TARGET_TO_ANALYZE_TYPE} IMPORTED ${TARGET_TO_ANALYZE_IMPORTED}")
				endif()

				# get all link libraries of the TARGET_TO_ANALYZE and add as recoursive dependecies to analyze
				set(TARGET_TO_ANALYZE_LINKED_LIBS "")
				_cs_get_all_linked_libs(${TARGET_TO_ANALYZE} TARGET_TO_ANALYZE_LINKED_LIBS)
				csDebugMessage("[_cs_recursive_analyze_target] ${TARGET_TO_ANALYZE} TARGET_TO_ANALYZE_LINKED_LIBS: ${TARGET_TO_ANALYZE_LINKED_LIBS}")
				# add to continue the analysis loop
				_csListAddListUniqueValues(TARGETS_TO_ANALYZE_LIST "${TARGET_TO_ANALYZE_LINKED_LIBS}")

				# if the target is a shared or module library, add its debug and release path
				if(TARGET_TO_ANALYZE_IMPORTED AND ((${TARGET_TO_ANALYZE_TYPE} STREQUAL "MODULE_LIBRARY") OR (${TARGET_TO_ANALYZE_TYPE} STREQUAL "SHARED_LIBRARY")))
					_csPopulateTargetDependencies(${TARGET_NAME} ${TARGET_TO_ANALYZE})
				endif()

			else()
				csDebugMessage("[_cs_recursive_analyze_target] TARGET_TO_ANALYZE ${TARGET_TO_ANALYZE} is not a target")
			endif()


			# finally refresh while condition variable
			list(LENGTH TARGETS_TO_ANALYZE_LIST TARGETS_TO_ANALYZE_SIZE)
	endwhile()

	# print for debug purposes
	get_target_property(TARGET_TO_ANALYZE_DEPENDENCIES_DEBUG ${TARGET_NAME} csTargetDependenciesDebug)
	csDebugMessage("[_cs_recursive_analyze_target] ${TARGET_NAME} csTargetDependenciesDebug: ${TARGET_TO_ANALYZE_DEPENDENCIES_DEBUG}")
	get_target_property(TARGET_TO_ANALYZE_DEPENDENCIES_RELEASE ${TARGET_NAME} csTargetDependenciesRelease)
	csDebugMessage("[_cs_recursive_analyze_target] ${TARGET_NAME} csTargetDependenciesRelease: ${TARGET_TO_ANALYZE_DEPENDENCIES_RELEASE}")
	 
	csDebugMessage("[_cs_recursive_analyze_target] ${TARGET_NAME} end")

endfunction()

function (_cs_recursive_analyze_target_finalize TARGETS_LIST)
  csDebugMessage("[_cs_recursive_analyze_target_finalize] ${TARGETS_LIST}")
  foreach (TARGET IN ITEMS ${TARGETS_LIST})
		message(STATUS "TODO(sc) add recursive algorithm for ${TARGET}")
	endforeach()
endfunction()


function (_csPopulateTargetDependencies TARGET_NAME TARGET_TO_ANALYZE)
	# DEBUG
	get_target_property(IMPORTED_LOCATION_DEBUG ${TARGET_TO_ANALYZE} IMPORTED_LOCATION_DEBUG) 
  _csCheckPathExistsAndAddToTargetProperty(${IMPORTED_LOCATION_DEBUG} ${TARGET_NAME} csTargetDependenciesDebug ${TARGET_TO_ANALYZE})
			
	# RELEASE
	get_target_property(IMPORTED_LOCATION_RELEASE ${TARGET_TO_ANALYZE} IMPORTED_LOCATION_RELEASE) 
  _csCheckPathExistsAndAddToTargetProperty(${IMPORTED_LOCATION_RELEASE} ${TARGET_NAME} csTargetDependenciesRelease ${TARGET_TO_ANALYZE})
        
  # Use release path for libraries that does not have the debug
  if(IMPORTED_LOCATION_RELEASE AND NOT IMPORTED_LOCATION_DEBUG)
    _csCheckPathExistsAndAddToTargetProperty(${IMPORTED_LOCATION_RELEASE} ${TARGET_NAME} csTargetDependenciesDebug ${TARGET_TO_ANALYZE})
		message(NOTICE "[_csPopulatecsTargetDependencies] ${TARGET_TO_ANALYZE} has only a release version, use it also as debug dependencies")
  endif()
endfunction()

function (_csCheckPathExistsAndAddToTargetProperty PATH_VALUE TARGET_NAME TARGET_PROPERTY TARGET_TO_ANALYZE)
	if(PATH_VALUE)
		# check file exist
		if(EXISTS ${PATH_VALUE})
		_csAddToTargetPropertyUniqueValue(${TARGET_NAME} ${TARGET_PROPERTY} ${PATH_VALUE})
		else()
			message(WARNING "[_csPopulatecsTargetDependencies] ${TARGET_TO_ANALYZE} depends on ${PATH_VALUE} but the file does not exists, skip")
		endif()
	endif()
endfunction()

function (_cs_get_all_linked_libs TARGET_TO_ANALYZE TARGET_TO_ANALYZE_LINKED_LIBS_OUT)
	set(TARGET_TO_ANALYZE_LINKED_LIBS "")

  get_target_property(tmp_list ${TARGET_TO_ANALYZE} LINK_LIBRARIES)
	_csListAddListUniqueValues(TARGET_TO_ANALYZE_LINKED_LIBS "${tmp_list}")

  get_target_property(tmp_list ${TARGET_TO_ANALYZE} INTERFACE_LINK_LIBRARIES)
	_csListAddListUniqueValues(TARGET_TO_ANALYZE_LINKED_LIBS ${tmp_list})

  # link dependent
  get_target_property(tmp_list ${TARGET_TO_ANALYZE} IMPORTED_LINK_DEPENDENT_LIBRARIES)
	_csListAddListUniqueValues(TARGET_TO_ANALYZE_LINKED_LIBS ${tmp_list})

  get_target_property(tmp_list ${TARGET_TO_ANALYZE} IMPORTED_LINK_DEPENDENT_LIBRARIES_DEBUG)
	_csListAddListUniqueValues(TARGET_TO_ANALYZE_LINKED_LIBS ${tmp_list})

  get_target_property(tmp_list ${TARGET_TO_ANALYZE} IMPORTED_LINK_DEPENDENT_LIBRARIES_RELEASE)
	_csListAddListUniqueValues(TARGET_TO_ANALYZE_LINKED_LIBS ${tmp_list})

  # link interface
  get_target_property(tmp_list ${TARGET_TO_ANALYZE} IMPORTED_LINK_INTERFACE_LIBRARIES)
	_csListAddListUniqueValues(TARGET_TO_ANALYZE_LINKED_LIBS ${tmp_list})

  get_target_property(tmp_list ${TARGET_TO_ANALYZE} IMPORTED_LINK_INTERFACE_LIBRARIES_DEBUG)
	_csListAddListUniqueValues(TARGET_TO_ANALYZE_LINKED_LIBS ${tmp_list})

  get_target_property(tmp_list ${TARGET_TO_ANALYZE} IMPORTED_LINK_INTERFACE_LIBRARIES_RELEASE)
	_csListAddListUniqueValues(TARGET_TO_ANALYZE_LINKED_LIBS ${tmp_list})

  get_target_property(tmp_list ${TARGET_TO_ANALYZE} MANUALLY_ADDED_DEPENDENCIES)
	_csListAddListUniqueValues(TARGET_TO_ANALYZE_LINKED_LIBS ${tmp_list})

	# set output value
	set(${TARGET_TO_ANALYZE_LINKED_LIBS_OUT} ${TARGET_TO_ANALYZE_LINKED_LIBS} PARENT_SCOPE)
endfunction()
