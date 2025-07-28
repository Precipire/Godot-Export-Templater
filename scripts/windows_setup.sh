#!/bin/bash
chmod +x /workspace/scripts/build_templates.py

python3 /workspace/scripts/build_templates.py "/workspace/config/data.json"

cp -r /workspace/godot/bin /workspace/output