#!/bin/bash
set -e

# Create fresh build directory
rm -rf /tmp/build
mkdir -p /tmp/build
cp -r /build/* /tmp/build
cd /tmp/build

# Build and bundle
make clean
make
make bundle

# Copy results back to host
cp -r dist /build/