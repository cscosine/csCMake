#!/usr/bin/env python3

import os
import sys
import shutil
import argparse
import subprocess


# Check if GitPython is installed
try:
    from git import Repo, GitCommandError
except ImportError:
    print("GitPython is not installed. Please install it using, for example, pip install GitPython --user", file=sys.stderr)
    sys.exit(1)

def csGetRepository(repo_url, repo_dir, branch, need_cmakeUserPath = True):
    try:
        if not os.path.isdir(repo_dir):
            print(f"Cloning the repository {repo_url} on branch {branch}...")
            Repo.clone_from(repo_url, repo_dir, branch=branch)
            print(f"... done")
        else:
            print(f"{repo_dir} exists, checking out and pulling branch {branch}...")
            repo = Repo(repo_dir)
            git = repo.git
            git.checkout(branch)
            git.pull("origin", branch, ff_only=True)
            print(f"... done")
        
        # Define the path to the default cmakeUserPath
        default_cmake_user_path = os.path.join("csCMake", "defaults", "cmakeUserPath-default.json")
        target_cmake_user_path = os.path.join(repo_dir, "cmakeUserPath.json")

        if need_cmakeUserPath:
            # Check if cmakeUserPath.json exists in the repo_dir
            if not os.path.isfile(target_cmake_user_path):
                print(f"'{target_cmake_user_path}' does not exist. Copying default from '{default_cmake_user_path}'...")

                # Ensure the default file exists
                if os.path.isfile(default_cmake_user_path):
                    shutil.copy(default_cmake_user_path, target_cmake_user_path)
                    print(f"... done")
                else:
                    print(f"Error: Default file '{default_cmake_user_path}' not found.")
            else:
                print(f"'{target_cmake_user_path}' exist. ")

    except GitCommandError as e:
        print(f"-- Git operation failed: {e}", file=sys.stderr)
        sys.exit(1)

def csGetOS():
    if os.name == 'posix':
        return "linux"
    elif os.name == 'nt':
        return "windows"
    else:
        return "unknown OS"

#TODO(sc): change to a class and use members, then inherit in the projects
_global_build_only = None

def csWorkflow(repo_dir, os_presets_dict):
    print(f"*** csWorkflow for ${repo_dir}, _global_build_only = {_global_build_only}")
    
    if(_global_build_only and _global_build_only != repo_dir):
        print(f"skip {repo_dir} because only {_global_build_only} is requested!")
        return
        
    original_dir = os.getcwd()
    os.chdir(repo_dir)
    cmake_command_base = ["cmake", "--workflow"] 

    os_name = csGetOS()
    #TODO(sc): add a check on os_name existence
    os_list = os_presets_dict[os_name]
            
    for preset in os_list:
        cmake_command = list(cmake_command_base)
        cmake_command.append(preset)

        try:
            print(f"{repo_dir}:: CMake run with command ", " ".join(["cmake", "--workflow"]))
            subprocess.run(cmake_command, check=True)
            print(f"CMake succesfully run")
        except subprocess.CalledProcessError as e:
            print(f"{repo_dir}::Error during CMake execution: {e}")
                
    os.chdir(original_dir)
    
def askConfirmAndClear(path):
    confirm = input(f"Are you sure you want to delete the {path} folder? (y/N): ").strip().lower()
    if confirm == "y":
        print(f"removing {path}...")        
        shutil.rmtree(path, ignore_errors=True)
        print(f"...done")        


def csSetupProject(args, repo_cs_url, checkout_project, checkout_func, build_func):
    from csCMake.csCMakeProjectManager import csGetRepository, csWorkflow

    # additional arguments
    parser = argparse.ArgumentParser()
    parser.add_argument("--sub-projects-branch", nargs="?", default="main", help="The branch to use for the sub projects (default: main)")
    parser.add_argument("-b", "--build", action="store_true", help="Enable build mode (default: off). If --build-only is specified, will be forced to True.")
    parser.add_argument("-cb", "--clear-build", action="store_true", help="Clear (delete) the build folder (default: off).  If --build-only is specified, only the specific subfolder will be deleted.")
    parser.add_argument("-ci", "--clear-install", action="store_true", help="Clear (delete) the install folder (default: off).  If --build-only is specified, only the specific subfolder will be deleted.")
    parser.add_argument("-bo", "--build-only", type=str, default="", help="Build a specified subdir only")    
    args = parser.parse_args(args)
    
    sub_projects_branch = args.sub_projects_branch
    build_project = args.build
    clear_build = args.clear_build
    clear_install = args.clear_install
    build_only = args.build_only
    
    # store in a global variable
    global _global_build_only
    _global_build_only = build_only

    print(f"Subprojects branch: {sub_projects_branch}")
    print(f"Build project: {build_project}")
    print(f"Build Only: {build_only}")
    print(f"Clear build: {clear_build}")
    print(f"Clear install: {clear_install}")
    
    if(build_only):
        print(f"* force build project, but only {build_only}")
        build_project = True

    # clear build if required
    if(clear_build):
        if(build_only):
            askConfirmAndClear("build/"+build_only)
        else:
            askConfirmAndClear("build")
    # clear install if required
    if(clear_install):
        if(build_only):
            askConfirmAndClear("install/"+build_only)
        else:
            askConfirmAndClear("install")

    # --- get all repos ---
    if(checkout_project):
        checkout_func(repo_cs_url, sub_projects_branch)

    # --- build all repos ---
    if(build_project):
        build_func()
