#!/usr/bin/env python3

import shutil
import os
import sys

def copy_template(destination_folder):
    # Get the directory of the script
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Define the source file path
    source_file = os.path.join(script_dir, "templates", "csMetaProjectTemplate.py")
    
    # Check if the source file exists
    if not os.path.exists(source_file):
        print(f"Error: Source file '{source_file}' does not exist.")
        sys.exit(1)
    
    # Check if the destination folder exists, create it if not
    if not os.path.exists(destination_folder):
        os.makedirs(destination_folder)
    
    # Define the destination file path
    destination_file = os.path.join(destination_folder, "project.py")
    
    # Copy the file
    try:
        shutil.copy2(source_file, destination_file)
        print(f"File copied successfully to {destination_file}")
    except Exception as e:
        print(f"Error copying file: {e}")
        sys.exit(1)

if __name__ == "__main__":
    # Check if a folder path is provided as an argument
    if len(sys.argv) != 2:
        print("Usage: python script.py <destination_folder>")
        sys.exit(1)
    
    destination_folder = sys.argv[1]
    copy_template(destination_folder)