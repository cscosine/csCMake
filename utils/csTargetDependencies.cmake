include_guard(GLOBAL)
include(utils/csDebugMessage)
include(utils/csListUtils)
include(utils/csDebugUtils)

# target properties added by this function
# - csTargetDependenciesDebug: list of debug dll necessary to the target
# - csTargetDependenciesRelease: list of release dll necessary to the target
# - csTargetDependenciesNotImportedTargets: list of dependent targets that are marked as not imported
# - csTargetDependenciesNonTargets: list of dependencies that are marked as non-target
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

				if(NOT TARGET_TO_ANALYZE_IMPORTED)
					# not imported target, i.e., a target specified inside the project, will be analyzed further for recursive dependencies
					if(NOT ${TARGET_TO_ANALYZE} STREQUAL ${TARGET_NAME})
						_csAddToTargetPropertyUniqueValue(${TARGET_NAME} csTargetDependenciesNotImportedTargets ${TARGET_TO_ANALYZE})
					endif()
				else()
					# if the target is a shared or module library, add its debug and release path
					if((${TARGET_TO_ANALYZE_TYPE} STREQUAL "MODULE_LIBRARY") OR (${TARGET_TO_ANALYZE_TYPE} STREQUAL "SHARED_LIBRARY"))
						_csPopulateTargetDependencies(${TARGET_NAME} ${TARGET_TO_ANALYZE})
					endif()
				endif()

			else()
				csDebugMessage("[_cs_recursive_analyze_target] TARGET_TO_ANALYZE ${TARGET_TO_ANALYZE} is not a target")
				if(NOT ${TARGET_TO_ANALYZE} STREQUAL ${TARGET_NAME})
					_csAddToTargetPropertyUniqueValue(${TARGET_NAME} csTargetDependenciesNonTargets ${TARGET_TO_ANALYZE})
				endif()
			endif()


			# finally refresh while condition variable
			list(LENGTH TARGETS_TO_ANALYZE_LIST TARGETS_TO_ANALYZE_SIZE)
	endwhile()

	# print for debug purposes
	cs_get_target_dependencies_debug_libraries(${TARGET_NAME} TARGET_TO_ANALYZE_DEPENDENCIES_DEBUG)
	csDebugMessage("[_cs_recursive_analyze_target] ${TARGET_NAME} csTargetDependenciesDebug: ${TARGET_TO_ANALYZE_DEPENDENCIES_DEBUG}")

	cs_get_target_dependencies_release_libraries(${TARGET_NAME} TARGET_TO_ANALYZE_DEPENDENCIES_RELEASE)
	csDebugMessage("[_cs_recursive_analyze_target] ${TARGET_NAME} csTargetDependenciesRelease: ${TARGET_TO_ANALYZE_DEPENDENCIES_RELEASE}")

	cs_get_target_dependencies_not_imported_targets(${TARGET_NAME} TARGET_TO_ANALYZE_DEPENDENCIES_NOT_IMPORTED_TARGETS)
	csDebugMessage("[_cs_recursive_analyze_target] ${TARGET_NAME} csTargetDependenciesNotImportedTargets: ${TARGET_TO_ANALYZE_DEPENDENCIES_NOT_IMPORTED_TARGETS}")
		
	cs_get_target_dependencies_not_targets(${TARGET_NAME} TARGET_TO_ANALYZE_DEPENDENCIES_NON_TARGETS)
	csDebugMessage("[_cs_recursive_analyze_target] ${TARGET_NAME} csTargetDependenciesNonTargets: ${TARGET_TO_ANALYZE_DEPENDENCIES_NON_TARGETS}")
	 
	csDebugMessage("[_cs_recursive_analyze_target] ${TARGET_NAME} end")

endfunction()

# return csTargetDependenciesDebug for target
function(cs_get_target_dependencies_debug_libraries TARGET_NAME OUTPUT_VARIABLE_NAME)
	get_target_property(_VALUES ${TARGET_NAME} csTargetDependenciesDebug)
	if(_VALUES)
		set(${OUTPUT_VARIABLE_NAME} ${_VALUES} PARENT_SCOPE)
	else()
		set(${OUTPUT_VARIABLE_NAME} "" PARENT_SCOPE)
	endif()
endfunction()

# return csTargetDependenciesRelease for target
function(cs_get_target_dependencies_release_libraries TARGET_NAME OUTPUT_VARIABLE_NAME)
	get_target_property(_VALUES ${TARGET_NAME} csTargetDependenciesRelease)
	if(_VALUES)
		set(${OUTPUT_VARIABLE_NAME} ${_VALUES} PARENT_SCOPE)
	else()
		set(${OUTPUT_VARIABLE_NAME} "" PARENT_SCOPE)
	endif()
endfunction()

# return csTargetDependenciesNotImportedTargets for target
function(cs_get_target_dependencies_not_imported_targets TARGET_NAME OUTPUT_VARIABLE_NAME)
	get_target_property(_VALUES ${TARGET_NAME} csTargetDependenciesNotImportedTargets)
	if(_VALUES)
		set(${OUTPUT_VARIABLE_NAME} ${_VALUES} PARENT_SCOPE)
	else()
		set(${OUTPUT_VARIABLE_NAME} "" PARENT_SCOPE)
	endif()
endfunction()

# - csTargetDependenciesNonTargets
function(cs_get_target_dependencies_not_targets TARGET_NAME OUTPUT_VARIABLE_NAME)
	get_target_property(_VALUES ${TARGET_NAME} csTargetDependenciesNonTargets)
	if(_VALUES)
		set(${OUTPUT_VARIABLE_NAME} ${_VALUES} PARENT_SCOPE)
	else()
		set(${OUTPUT_VARIABLE_NAME} "" PARENT_SCOPE)
	endif()
endfunction()

# - csTargetDependenciesDebugFinalized: list of debug dll necessary to the target
# - csTargetDependenciesReleaseFinalized: list of release dll necessary to the target
# during the execution a variable csTargetDependenciesToAnalyze is created as temporary, but it will be used as a "buffer", at exist it is empty
function (_cs_recursive_analyze_targets_finalize TARGETS_LIST)
  csDebugMessage("[_cs_recursive_analyze_targets_finalize] targets: ${TARGETS_LIST}")
  
	# for each target, 
  foreach (TARGET_NAME IN ITEMS ${TARGETS_LIST})
		# - copy csTargetDependenciesDebug and csTargetDependenciesRelease to the Finalized copies
		# - create a unique list of target csTargetDependenciesToAnalyze as merge of csTargetDependenciesNotImportedTargets and csTargetDependenciesNonTargets, by selecting only what is effectively a target and removing aliases
		_cs_prepare_finalize_target(${TARGET_NAME})
	endforeach()

	# now, for each target, cumulate in Finalized the Finalized of the dependent target. If fully finalized, remove from the list of targets, otherwise add back at the end
	list(LENGTH TARGETS_LIST TARGETS_LIST_SIZE)

	# backup of target list
	set(TARGETS_LIST_ORIGINAL ${TARGETS_LIST})

	# loop
	while(TARGETS_LIST_SIZE GREATER 0)
		# get the first target in the list
		list(GET TARGETS_LIST 0 TARGET_NAME)
		# and remove it
		list(REMOVE_AT TARGETS_LIST 0)
		
		csDebugMessage("[_cs_recursive_analyze_targets_finalize] analyze target ${TARGET_NAME}")

		_cs_target_is_fully_finalized(${TARGET_NAME} TARGET_FINALIZED)
		if(NOT TARGET_FINALIZED)
			csDebugMessage("[_cs_recursive_analyze_targets_finalize] target ${TARGET_NAME} is not finalized")
			# try to finalize
			_cs_target_try_to_finalize(${TARGET_NAME})
			# and check the result
			_cs_target_is_fully_finalized(${TARGET_NAME} TARGET_FINALIZED)
			if(NOT TARGET_FINALIZED)
				csDebugMessage("[_cs_recursive_analyze_targets_finalize] target ${TARGET_NAME} is not finalized yet, readd it")
				_csListAddUniqueValue(TARGETS_LIST ${TARGET_NAME})
			else()
				csDebugMessage("[_cs_recursive_analyze_targets_finalize] target ${TARGET_NAME} is now finalized!")
			endif()

		else()
			csDebugMessage("[_cs_recursive_analyze_targets_finalize] target ${TARGET_NAME} is finalized!")
		endif()

		# finally refresh while condition variable
		list(LENGTH TARGETS_LIST TARGETS_LIST_SIZE)
	endwhile()

	# print out final dependency list
	csDebugMessage("[_cs_recursive_analyze_targets_finalize] concluded, print final state")
	foreach(TARGET_NAME IN ITEMS ${TARGETS_LIST_ORIGINAL})
		cs_get_target_dependencies_debug_libraries_finalized(${TARGET_NAME} TARGET_TO_ANALYZE_DEPENDENCIES_DEBUG)
		csDebugMessage("[_cs_recursive_analyze_targets_finalize] ${TARGET_NAME} csTargetDependenciesDebug: ${TARGET_TO_ANALYZE_DEPENDENCIES_DEBUG}")

		cs_get_target_dependencies_release_libraries_finalized(${TARGET_NAME} TARGET_TO_ANALYZE_DEPENDENCIES_RELEASE)
		csDebugMessage("[_cs_recursive_analyze_targets_finalize] ${TARGET_NAME} csTargetDependenciesRelease: ${TARGET_TO_ANALYZE_DEPENDENCIES_RELEASE}")		
	endforeach()
	csDebugMessage("[_cs_recursive_analyze_targets_finalize] end")

endfunction()

function(_cs_target_try_to_finalize TARGET_NAME)
	get_target_property(DEP_TARGETS ${TARGET_NAME} csTargetDependenciesToAnalyze)

	set(PENDING_DEP_TARGETS "")
	foreach(DEP_TARGET IN ITEMS "${DEP_TARGETS}")
		_cs_target_is_fully_finalized(${DEP_TARGET} DEP_TARGET_FINALIZED)
		if(DEP_TARGET_FINALIZED)
			# merge the two finalized list of debug and release dependencies
			cs_get_target_dependencies_debug_libraries_finalized(${TARGET_NAME} TARGET_DEBUG)
			cs_get_target_dependencies_release_libraries_finalized(${TARGET_NAME} TARGET_RELEASE)

			cs_get_target_dependencies_debug_libraries_finalized(${DEP_TARGET} TARGET_DEP_DEBUG)
			cs_get_target_dependencies_release_libraries_finalized(${DEP_TARGET} TARGET_DEP_RELEASE)

			_csListAddListUniqueValues(TARGET_DEBUG "${TARGET_DEP_DEBUG}")
			_csListAddListUniqueValues(TARGET_RELEASE "${TARGET_DEP_RELEASE}")

			# and set back
			set_property(TARGET ${TARGET_NAME} PROPERTY csTargetDependenciesDebugFinalized "${TARGET_DEBUG}")
			set_property(TARGET ${TARGET_NAME} PROPERTY csTargetDependenciesReleaseFinalized "${TARGET_RELEASE}")

		else()
			_csListAddUniqueValue(PENDING_DEP_TARGETS ${DEP_TARGET})
		endif()
	endforeach()
	
	csDebugMessage("[_cs_target_try_to_finalize] target ${TARGET_NAME} pending dependencies ${PENDING_DEP_TARGETS}")
	set_property(TARGET ${TARGET_NAME} PROPERTY csTargetDependenciesToAnalyze "${PENDING_DEP_TARGETS}")

endfunction()


# return true if the csTargetDependenciesToAnalyze of the target is empty
function(_cs_target_is_fully_finalized TARGET_NAME TARGET_FINALIZED)
	get_target_property(_VALUES ${TARGET_NAME} csTargetDependenciesToAnalyze)
	if(_VALUES)
		set(${TARGET_FINALIZED} False PARENT_SCOPE)
	else()
		set(${TARGET_FINALIZED} True PARENT_SCOPE)
	endif()
endfunction()


# this function 
# - copy csTargetDependenciesDebug and csTargetDependenciesRelease to the Finalized copy
# - merges the csTargetDependenciesNotImportedTargets and csTargetDependenciesNonTargets and select valid targets, preparing the list in csTargetDependenciesToAnalyze
function(_cs_prepare_finalize_target TARGET_NAME)
	csDebugMessage("[_cs_prepare_finalize_target] process target: ${TARGET_NAME}")

	# copy on Finalized
	cs_get_target_dependencies_debug_libraries(${TARGET_NAME} TARGET_DEBUG_LIBS)
	set_property(TARGET ${TARGET_NAME} PROPERTY csTargetDependenciesDebugFinalized "${TARGET_DEBUG_LIBS}")
	csDebugMessage("[_cs_prepare_finalize_target] ${TARGET_NAME} csTargetDependenciesDebug: ${TARGET_DEBUG_LIBS}")

	cs_get_target_dependencies_release_libraries(${TARGET_NAME} TARGET_RELEASE_LIBS)
	set_property(TARGET ${TARGET_NAME} PROPERTY csTargetDependenciesReleaseFinalized "${TARGET_RELEASE_LIBS}")
	csDebugMessage("[_cs_prepare_finalize_target] ${TARGET_NAME} csTargetDependenciesRelease: ${TARGET_RELEASE_LIBS}")

	# retrieve targets to analyze
	cs_get_target_dependencies_not_imported_targets(${TARGET_NAME} TARGET_NOT_IMPORTED)
	csDebugMessage("[_cs_prepare_finalize_target] ${TARGET_NAME} csTargetDependenciesNotImportedTargets: ${TARGET_NOT_IMPORTED}")
		
	cs_get_target_dependencies_not_targets(${TARGET_NAME} TARGET_NON_TARGETS)
	csDebugMessage("[_cs_prepare_finalize_target] ${TARGET_NAME} csTargetDependenciesNonTargets: ${TARGET_NON_TARGETS}")

	# join the two list
	set(TARGETS_TO_ANALYZE_LIST_RAW "")
	foreach (TARGET_TO_ANALYZE IN ITEMS ${TARGET_NOT_IMPORTED})
		_csListAddUniqueValue(TARGETS_TO_ANALYZE_LIST_RAW "${TARGET_TO_ANALYZE}")
	endforeach()
	foreach (TARGET_TO_ANALYZE IN ITEMS ${TARGET_NON_TARGETS})
		_csListAddUniqueValue(TARGETS_TO_ANALYZE_LIST_RAW "${TARGET_TO_ANALYZE}")
	endforeach()
	csDebugMessage("[_cs_prepare_finalize_target] ${TARGET_NAME} TARGETS_TO_ANALYZE_LIST_RAW ${TARGETS_TO_ANALYZE_LIST_RAW}")

	# select only targets
	set(TARGETS_TO_ANALYZE_LIST "")
	foreach (TARGET_TO_ANALYZE IN ITEMS ${TARGETS_TO_ANALYZE_LIST_RAW})
		if(TARGET ${TARGET_TO_ANALYZE})
			# check aliasing and retrieve original name
			get_target_property(ALIASED_TARGET_TO_ANALYZE ${TARGET_TO_ANALYZE} ALIASED_TARGET)
			if(ALIASED_TARGET_TO_ANALYZE)
				SET(TARGET_TO_ANALYZE "${ALIASED_TARGET_TO_ANALYZE}")
			endif()
			_csListAddUniqueValue(TARGETS_TO_ANALYZE_LIST "${TARGET_TO_ANALYZE}")
		endif()
	endforeach()
	csDebugMessage("[_cs_prepare_finalize_target] ${TARGET_NAME} TARGETS_TO_ANALYZE_LIST ${TARGETS_TO_ANALYZE_LIST}")
	set_property(TARGET ${TARGET_NAME} PROPERTY csTargetDependenciesToAnalyze "${TARGETS_TO_ANALYZE_LIST}")

endfunction()

# return csTargetDependenciesDebug for target
function(cs_get_target_dependencies_debug_libraries_finalized TARGET_NAME OUTPUT_VARIABLE_NAME)
	get_target_property(_VALUES ${TARGET_NAME} csTargetDependenciesDebugFinalized)
	if(_VALUES)
		set(${OUTPUT_VARIABLE_NAME} ${_VALUES} PARENT_SCOPE)
	else()
		set(${OUTPUT_VARIABLE_NAME} "" PARENT_SCOPE)
	endif()
endfunction()

# return csTargetDependenciesRelease for target
function(cs_get_target_dependencies_release_libraries_finalized TARGET_NAME OUTPUT_VARIABLE_NAME)
	get_target_property(_VALUES ${TARGET_NAME} csTargetDependenciesReleaseFinalized)
	if(_VALUES)
		set(${OUTPUT_VARIABLE_NAME} ${_VALUES} PARENT_SCOPE)
	else()
		set(${OUTPUT_VARIABLE_NAME} "" PARENT_SCOPE)
	endif()
endfunction()

function (_csPopulateTargetDependencies TARGET_NAME TARGET_TO_ANALYZE)
  # DEBUG
	get_target_property(IMPORTED_LOCATION_DEBUG ${TARGET_TO_ANALYZE} IMPORTED_LOCATION_DEBUG) 
  _csCheckPathExistsAndAddToTargetProperty(${IMPORTED_LOCATION_DEBUG} ${TARGET_NAME} csTargetDependenciesDebug ${TARGET_TO_ANALYZE})
			
	# RELEASE
	get_target_property(IMPORTED_LOCATION_RELEASE ${TARGET_TO_ANALYZE} IMPORTED_LOCATION_RELEASE) 
  _csCheckPathExistsAndAddToTargetProperty(${IMPORTED_LOCATION_RELEASE} ${TARGET_NAME} csTargetDependenciesRelease ${TARGET_TO_ANALYZE})

  # generic
  get_target_property(IMPORTED_LOCATION ${TARGET_TO_ANALYZE} IMPORTED_LOCATION)
	if(IMPORTED_LOCATION AND IMPORTED_LOCATION_RELEASE)
		if(NOT "${IMPORTED_LOCATION}" STREQUAL "${IMPORTED_LOCATION_RELEASE}")
			message(WARNING "[_csPopulateTargetDependencies] target ${TARGET_TO_ANALYZE} has both IMPORTED_LOCATION=${IMPORTED_LOCATION} and IMPORTED_LOCATION_RELEASE=${IMPORTED_LOCATION_RELEASE} but they are different, IMPORTED_LOCATION will be ignored")
		endif()
	elseif(IMPORTED_LOCATION AND NOT IMPORTED_LOCATION_RELEASE)
		# if imported location and not release, use it for release
			message(WARNING "[_csPopulateTargetDependencies] target ${TARGET_TO_ANALYZE} has IMPORTED_LOCATION=${IMPORTED_LOCATION} but no IMPORTED_LOCATION_RELEASE, use IMPORTED_LOCATION")
		set(IMPORTED_LOCATION_RELEASE "${IMPORTED_LOCATION}")
	endif()
        
  # Use release (or generic if substituted) path for libraries that does not have the debug
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
