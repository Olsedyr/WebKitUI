#!/bin/bash
set -e

# Create fresh build directory
rm -rf /tmp/build
mkdir -p /tmp/build
cp -r /build/* /tmp/build
cd /tmp/build

# Build and bundle with X11 support
make clean
CFLAGS="-m32 -Os -pipe -s $(pkg-config --cflags gtk+-3.0 webkit2gtk-4.0) -Wl,-rpath='$$ORIGIN/libs' -DGDK_DISABLE_DEPRECATED" make
make bundle

# Copy results back to host
cp -r dist /build/