# Use Ubuntu 22.04 as it matches the PCSX2 CI environment
FROM ubuntu:22.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# 1. Install system tools and add LLVM repo for Clang 17
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    software-properties-common \
    git \
    && curl -fSsL https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add - \
    && add-apt-repository "deb http://apt.llvm.org/jammy/ llvm-toolchain-jammy-17 main" \
    && apt-get update

# 2. Install all base build dependencies
RUN apt-get install -y \
    build-essential \
    ccache \
    clang-17 \
    cmake \
    extra-cmake-modules \
    libasound2-dev \
    libaio-dev \
    libcurl4-openssl-dev \
    libdbus-1-dev \
    libdecor-0-dev \
    libegl-dev \
    libevdev-dev \
    libfontconfig-dev \
    libfreetype-dev \
    libfuse2 \
    libgtk-3-dev \
    libgudev-1.0-dev \
    libharfbuzz-dev \
    libinput-dev \
    libopengl-dev \
    libopus-dev \
    libpcap-dev \
    libpipewire-0.3-dev \
    libpulse-dev \
    libssl-dev \
    libudev-dev \
    libva-dev \
    libvpl2 \
    libvpl-dev \
    libwayland-dev \
    libx11-dev \
    libx11-xcb-dev \
    libx264-dev \
    libxcb1-dev \
    libxcb-composite0-dev \
    libxcb-cursor-dev \
    libxcb-damage0-dev \
    libxcb-glx0-dev \
    libxcb-icccm4-dev \
    libxcb-image0-dev \
    libxcb-keysyms1-dev \
    libxcb-present-dev \
    libxcb-randr0-dev \
    libxcb-render0-dev \
    libxcb-render-util0-dev \
    libxcb-shape0-dev \
    libxcb-shm0-dev \
    libxcb-sync-dev \
    libxcb-util-dev \
    libxcb-xfixes0-dev \
    libxcb-xinput-dev \
    libxcb-xkb-dev \
    libxext-dev \
    libxkbcommon-x11-dev \
    libxrandr-dev \
    lld-17 \
    llvm-17 \
    nasm \
    ninja-build \
    patchelf \
    pkg-config \
    zlib1g-dev \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# 3. Set up working directory
WORKDIR /pcsx2

# 4. Copy necessary scripts to build modern dependencies
# We copy only what's needed for the dependency build to keep the image cache efficient
COPY .github/workflows/scripts .github/workflows/scripts
COPY tools tools

# 5. Build the "custom" dependencies (Qt6, SDL3, FFmpeg, etc.)
# This is the step that takes a long time but ensures a perfect build environment.
RUN mkdir -p /deps && \
    export CC=clang-17 && \
    export CXX=clang++-17 && \
    export BUILD_FFMPEG=1 && \
    bash .github/workflows/scripts/linux/build-dependencies-qt.sh /deps

# 6. Set Environment Variables for the final build
ENV CC=clang-17
ENV CXX=clang++-17
ENV CMAKE_PREFIX_PATH=/deps
ENV PKG_CONFIG_PATH=/deps/lib/pkgconfig

# Install AppImage tools at the end to avoid breaking cache for the long builds above
RUN apt-get update && apt-get install -y fuse file wget && rm -rf /var/lib/apt/lists/*

# Enable AppImage packaging by default
ENV BUILD_APPIMAGE=true
# This tells AppImage tools to extract themselves instead of mounting via FUSE
ENV APPIMAGE_EXTRACT_AND_RUN=1

# Default command: generate cmake project, build, and package as AppImage
CMD ["bash", "-c", "git config --global --add safe.directory $(pwd) && \
    # 1. Generate the project \
    cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=/deps -DCMAKE_DISABLE_PRECOMPILE_HEADERS=ON && \
    # 2. Force the version string (v2.7.316) into the build directory \
    mkdir -p build/common/include && \
    echo '#define GIT_TAG \"v2.7.316\"' > build/common/include/svnrev.h && \
    echo '#define GIT_TAGGED_COMMIT 1' >> build/common/include/svnrev.h && \
    echo '#define GIT_TAG_HI 2' >> build/common/include/svnrev.h && \
    echo '#define GIT_TAG_MID 7' >> build/common/include/svnrev.h && \
    echo '#define GIT_TAG_LO 316' >> build/common/include/svnrev.h && \
    echo '#define GIT_REV \"v2.7.316\"' >> build/common/include/svnrev.h && \
    echo '#define GIT_HASH \"docker-build\"' >> build/common/include/svnrev.h && \
    echo \"#define GIT_DATE \\\"$(date)\\\"\" >> build/common/include/svnrev.h && \
    # 3. Build and package \
    ninja -C build && \
    # Force copy resources into the build bin AND ensure AppDir is ready \
    cp -r bin/resources build/bin/ && \
    mkdir -p PCSX2.AppDir/usr/bin/ && \
    cp -r bin/resources PCSX2.AppDir/usr/bin/ || true && \
    if [ \"$BUILD_APPIMAGE\" = \"true\" ]; then \
        bash .github/workflows/scripts/linux/appimage-qt.sh \"$(pwd)\" \"$(pwd)/build\" \"/deps\" \"PCSX2-v2.7.316\"; \
    fi"]
