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

def csWorkflow(repo_dir, os_presets_dict):
    original_dir = os.getcwd()
    os.chdir(repo_dir)
    cmake_command_base = ["cmake", "--workflow"] 

    os_name = csGetOS()
    os_list = os_presets_dict[os_name]
            
    for preset in os_list:
        cmake_command = list(cmake_command_base)
        cmake_command.append(preset)

        try:
            print("CMake run with command ", " ".join(["cmake", "--workflow"]))
            subprocess.run(cmake_command, check=True)
            print("CMake succesfully run")
        except subprocess.CalledProcessError as e:
            print(f"Error during CMake execution: {e}")
                
    os.chdir(original_dir)

def csSetupProject(args, repo_cs_url, checkout_project, checkout_func, build_func):
    from csCMake.csCMakeProjectManager import csGetRepository, csWorkflow

    # additional arguments
    parser = argparse.ArgumentParser()
    parser.add_argument("--sub-projects-branch", nargs="?", default="main", help="The branch to use for the sub projects (default: main)")
    parser.add_argument("-b", "--build", action="store_true", help="Enable build mode (default: off)")
    parser.add_argument("-cb", "--clear-build", action="store_true", help="Clear (delete) the build folder (default: off)")
    parser.add_argument("-ci", "--clear-install", action="store_true", help="Clear (delete) the install folder (default: off)")
    args = parser.parse_args(args)
    sub_projects_branch = args.sub_projects_branch
    build_project = args.build
    clear_build = args.clear_build
    clear_install = args.clear_install

    print(f"Subprojects branch: {sub_projects_branch}")
    print(f"Build project: {build_project}")
    print(f"Clear build: {clear_build}")
    print(f"Clear install: {clear_install}")

    # clear build if required
    if(clear_build):
        confirm = input(f"Are you sure you want to delete the build folder? (y/N): ").strip().lower()
        if confirm == "y":
            print("removing build...")        
            shutil.rmtree("build", ignore_errors=True)
            print("...done")        
    # clear install if required
    if(clear_install):
        confirm = input(f"Are you sure you want to delete the install folder? (y/N): ").strip().lower()
        if confirm == "y":        
            print("removing install...")        
            shutil.rmtree("install", ignore_errors=True)
            print("...done")        

    # --- get all repos ---
    if(checkout_project):
        checkout_func(repo_cs_url, sub_projects_branch)

    # --- build all repos ---
    if(build_project):
        build_func()
