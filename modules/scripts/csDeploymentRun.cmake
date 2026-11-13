# Make a deployment (csDeployment.cmake), in script mode (cmake -P), from its build target cs_deploy_<name> or from the
# normal install: in a configuration the deployment does not list, fail (unlisted FAIL) or skip (unlisted SKIP); else
# empty the folder of the deployment and install its component there.
#
# Reads (-D): name (the deployment), config (being built or installed), configs (of the deployment, comma separated),
# unlisted (FAIL or SKIP), build_dir (top build folder), component, out_dir.
cmake_minimum_required(VERSION 3.31)

string(REPLACE "," ";" configs_list "${configs}")
if(NOT config IN_LIST configs_list AND unlisted STREQUAL "SKIP")
  message(STATUS "[cs_deploy_${name}] ${config}: not made (the deployment is made in ${configs})")
  return()
elseif(NOT config IN_LIST configs_list)
  message(
    FATAL_ERROR
    "[cs_deploy_${name}] the deployment ${name} is made in ${configs}, not in ${config} "
    "(cs_deployment(${name} CONFIGS ...)): build cs_deploy_${name} in one of its configurations"
  )
endif()

file(REMOVE_RECURSE "${out_dir}")
# the folder of the deployment is not under the install prefix: a DESTDIR of the normal install does not apply
set(ENV{DESTDIR} "")
execute_process(
  COMMAND
    "${CMAKE_COMMAND}" --install "${build_dir}" --config "${config}" --component "${component}" --prefix "${out_dir}"
  COMMAND_ERROR_IS_FATAL ANY
)
message(STATUS "[cs_deploy_${name}] ${config}: ${out_dir}")
