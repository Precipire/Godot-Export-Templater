# Using Ubuntu
FROM ubuntu:22.04

# disables questions?? (assuming this removes the installer stuff)
ENV DEBIAN_FRONTEND=noninteractive

# Install the packages required

RUN apt update && apt install -y \
    git scons python3 build-essential \
    pkg-config libssl-dev \
    zip wget \
    mingw-w64 \
    libx11-dev \
    libxcursor-dev \
    libxinerama-dev \
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    libasound2-dev \
    libpulse-dev \
    libudev-dev \
    libxi-dev \
    libxrandr-dev \
    libwayland-dev \
    && apt clean

# Set MinGW to use the POSIX threading model (required for Godot)
RUN update-alternatives --set x86_64-w64-mingw32-gcc /usr/bin/x86_64-w64-mingw32-gcc-posix && \
    update-alternatives --set x86_64-w64-mingw32-g++ /usr/bin/x86_64-w64-mingw32-g++-posix

WORKDIR /workspace

COPY ./scripts/build_templates.sh /workspace/scripts/build_templates.sh
RUN chmod +x /workspace/scripts/build_templates.sh

RUN git clone https://github.com/godotengine/godot.git /workspace/godot
RUN git clone https://github.com/emscripten-core/emsdk.git /workspace/emsdk
RUN git config --global advice.detachedHead false

CMD ["/bin/bash"]
