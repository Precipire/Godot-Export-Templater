#!/bin/bash
GODOT_DIR=/workspace/godot
GODOT_VERSION="4.4.1-stable"

ENCRYPTION_KEY=""
PROFILE=""
TARGET="template_release"
PLATFORM="linuxbsd"
ARCH=""
SCONS_ARGS=""

usage() { echo "Usage: $0 [-b godot version (e.g. 4.4.1-stable) <string>] [-p <string>]" 1>&2; exit 1; }

while getopts "b:k:c:r:p:a:" opt; do
    case ${opt} in
        b)
            GODOT_VERSION=$OPTARG
            ;;
        k)
            ENCRYPTION_KEY=$OPTARG
            ;;
        c)
            PROFILE=$OPTARG
            ;;
        r)
            TARGET=$OPTARG
            ;;
        p)
            PLATFORM=$OPTARG
            ;;
        a)
            ARCH=$OPTARG
            ;;
        \? )
            usage
            exit 1
            ;;
        
    esac
done

if [ -z "$ENCRYPTION_KEY" ]; then
    echo "Error: Encryption key (-k) is required."
    exit 1
fi    

export SCRIPT_AES256_ENCRYPTION_KEY=$ENCRYPTION_KEY

if [ ! -d "$GODOT_DIR" ]; then
    git clone https://github.com/godotengine/godot.git "$GODOT_DIR"
fi

cd "$GODOT_DIR"
git fetch
git checkout "$GODOT_VERSION" || { echo "Git checkout failed: version '$GODOT_VERSION' not found"; exit 1; }

case "$TARGET" in
    editor|template_debug|template_release)
        echo "Target $TARGET selected"
        SCONS_ARGS="$SCONS_ARGS target=$TARGET"
        ;;
    *)
        echo "Error: Invalid target '$TARGET'. Must be one of: editor, template_debug, template_release."
        exit 1
        ;;
esac

case "$ARCH" in
    auto|x86_32|x86_64|arm32|arm64|rv64|ppc32|ppc64|wasm32)
        echo "Architecture $ARCH selected"
        SCONS_ARGS="$SCONS_ARGS arch=$ARCH"
        ;;
    *)
        echo "No Architecture specified, using auto. Valid architectures are: auto, x86_32, x86_64, arm32, arm64, rv64, ppc32, ppc64, wasm32"
        SCONS_ARGS="$SCONS_ARGS arch=auto"
        ;;
esac

case "$PLATFORM" in
    windows)
        echo "Platform $PLATFORM selected"
        #Add the extras for windows
        SCONS_ARGS="$SCONS_ARGS p=$PLATFORM use_mingw=yes use_llvm=true"
        ;;
    android|ios|linuxbsd|macos|web|windows)
        # valid platform, do nothing or echo confirmation
        echo "Platform $PLATFORM selected"
        SCONS_ARGS="$SCONS_ARGS p=$PLATFORM"
        ;;
    *)
        echo "Error: Invalid platform '$PLATFORM'. Must be one of: android, ios, linuxbsd, macos, web, windows."
        exit 1
        ;;
esac
cd /workspace/godot
scons $SCONS_ARGS
mv ./bin/* ../output/