#!/usr/bin/env python3

import os
import argparse
import sys


# Ensure script runs from its own directory
script_dir = os.path.dirname(os.path.abspath(__file__))
current_dir = os.getcwd()

if current_dir != script_dir:
    print(f"Warning: The current directory ({current_dir}) is not the same as the script's directory ({script_dir}), changing to {script_dir}")
    os.chdir(script_dir)

# Check if GitPython is installed
try:
    from git import Repo, GitCommandError
except ImportError:
    print("GitPython is not installed. Please install it using, for example, pip install GitPython --user", file=sys.stderr)
    sys.exit(1)

def main():
    # TODO(sc): how to produce a complete help ?
    parser = argparse.ArgumentParser(description="Clone or update a csMake meta-project, allow to build and install the subprojects.", add_help=False)
    parser.add_argument("--csCMake-branch", nargs="?", default="main", help="The branch to use for csCMake (default: main)")
    parser.add_argument("--repo_cs_url", nargs="?", default="git@github.com:simoneceriani", help="The base URL for the repositories")
    parser.add_argument("-nc", "--no-checkout", action="store_true", help="Skip checking out the repositories (default: off)")
    
    # parse the base arguments
    args, remaining_args = parser.parse_known_args()
    
    # store in local variables for convenience
    repo_cs_url = args.repo_cs_url
    csCMake_branch = args.csCMake_branch
    checkout_project = not args.no_checkout
    print(f"Repository cs url: {repo_cs_url}")
    print(f"csCMake branch: {csCMake_branch}")
    print(f"Checkout project: {checkout_project}")

    # get the base repository
    csCMake_dir = "csCMake"
    if(checkout_project):
        repo_url = repo_cs_url + "/csCMake.git"
        
        try:
            if not os.path.isdir(csCMake_dir):
                print(f"Cloning the repository {repo_url} on branch {csCMake_branch}...")
                Repo.clone_from(repo_url, csCMake_dir, branch=csCMake_branch)
                print(f"... done")
            else:
                print(f"{csCMake_dir} exists, checking out and pulling branch {csCMake_branch}...")
                repo = Repo(csCMake_dir)
                git = repo.git
                git.checkout(csCMake_branch)
                git.pull("origin", csCMake_branch, ff_only=True)
                print(f"... done")
        except GitCommandError as e:
            print(f"-- Git operation failed: {e}", file=sys.stderr)
            sys.exit(1)
       
    # Add csCMake directory to sys.path to allow module imports
    sys.path.insert(0, os.path.abspath(csCMake_dir))
    try:
        from csCMake.csCMakeProjectManager import csSetupProject
        print("Successfully imported csCMake module.")
        csSetupProject(args = remaining_args, repo_cs_url = repo_cs_url, checkout_project = checkout_project, checkout_func = checkout_func, build_func = build_func)
    except ImportError as e:
        print(f"Failed to import csCMake: {e}", file=sys.stderr)
        sys.exit(1)
    
##########################################################################################################################33

def checkout_func(repo_cs_url, sub_projects_branch):
    from csCMake.csCMakeProjectManager import csGetRepository

    # specify hereafter the list of repository to be checked out / pulled out
    # use csGetRepository(repo_url, repo_dir, branch)
    # - optional param: need_cmakeUserPath = False if a repo does not need cmakeUserPath.json file to be added (default True)
    # - sub_projects_branch is used as a command line configuration parameter
    # example: csGetRepository(repo_cs_url + "/myrepo.git", "myrepo", "devel")
    # example: csGetRepository(repo_cs_url + "/myrepo2.git", "myrepo2", sub_projects_branch)
    # example: csGetRepository(repo_cs_url + "/myrepo3.git", "myrepo3", sub_projects_branch, need_cmakeUserPath = False)

def build_func():
    from csCMake.csCMakeProjectManager import csWorkflow

    # specify hereafter a dictionary of workflow presets to be configured/built/tested/installed
    # dictionary key is the host/target platform, value is a list of presets to execute
    # example:
    #presets = {
    #     "linux": ["linux-ninja-debug", "linux-ninja-release"],
    #     "windows": ["msvc2022-x64", "msvc2022-x64-LLVM"]
    #}
    
    # and then specify the presets to execute on each folder
    # csWorkflow("myrepo", presets)
    # csWorkflow("myrepo2", presets)
    
    # note: presets can be different per each subfolder
    # presets3 = { ... }
    # csWorkflow("myrepo3", presets3)

if __name__ == "__main__":
    main()
