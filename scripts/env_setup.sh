#!/bin/bash
chmod +x /workspace/scripts/build_templates.py
cd "/workspace/emsdk"
git pull
./emsdk install latest
./emsdk activate latest

source ./emsdk_env.sh

python3 /workspace/scripts/build_templates.py "/workspace/config/data.json"

mv /workspace/godot/bin/. /workspace/output