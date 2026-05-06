#!/bin/bash

# Exit on error
set -e

IMAGE_NAME="pcsx2-builder"

echo "=== PCSX2 Docker Build Helper ==="

# 1. Build the Docker image (if it doesn't exist or needs update)
echo "Step 1: Preparing the build environment (this may take a long time on first run)..."
docker build -t $IMAGE_NAME .

# 2. Run the build
echo "Step 2: Compiling PCSX2..."
# We mount the current directory into /pcsx2 inside the container
# We also use a volume for the build directory to speed up subsequent compiles
docker run --rm \
    -v "$(pwd):/pcsx2" \
    -u "$(id -u):$(id -g)" \
    $IMAGE_NAME

echo "=== Build Complete! ==="
echo "You can find the results in your project folder:"
echo " - Standard binary: build/bin/pcsx2-qt"
echo " - AppImage: PCSX2-Custom.AppImage"
