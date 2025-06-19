import json
import subprocess
import sys
import shutil
import os

def run_scons(args):
    result = subprocess.run(["scons", *args], text=True, cwd="/workspace/godot")
    if result.returncode != 0:
        sys.exit("Build Failed")

def checkout_godot_version(version):
    result = subprocess.run(["git", "checkout", version], cwd="/workspace/godot", text=True, capture_output=True)
    if result.returncode != 0:
        print(f"Git checkout failed:\n{result.stderr}")
        sys.exit(1)
    print(f"Checked out Godot version: {version}")

def main(json_path):

    with open(json_path) as f:
        config = json.load(f)
    
    #checkout Godot Version
    checkout_godot_version(config["godot_version"])

    # Set the base args that are always required
    args = [
        f"platform={config['platform']}",
        f"target={config['target']}"
    ]

    # Add in extra args that are required for certain platforms (like windows using mingw and llvm)
    for key, val in config.get("platform_settings", {}).items():
        args.append(f"{key}={val}")
    
    # If we are supplied an encryption key add it
    if config.get("encryption_key"):
        os.environ["SCRIPT_AES256_ENCRYPTION_KEY"] = config["encryption_key"]

    run_scons(args)

if __name__ == "__main__":
    main(sys.argv[1])