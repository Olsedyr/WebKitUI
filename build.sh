#!/bin/bash
set -euxo pipefail

echo "🔍 Verifying tools..."
command -v make
command -v gcc

echo "🧹 Cleaning..."
rm -rf /tmp/build
mkdir -p /tmp/build
cp -r /build/* /tmp/build
cd /tmp/build

echo "🔧 Building..."
make clean || true
CFLAGS="-m32 -Os -pipe -s $(pkg-config --cflags gtk+-3.0 webkit2gtk-4.0) -Wl,-rpath='\$\$ORIGIN/libs' -DGDK_DISABLE_DEPRECATED" \
make minimal-ui

echo "📦 Bundling..."
make bundle

echo "🔐 Fixing permissions..."
chmod +x dist/minimal-ui || true
chmod +x dist/xserver/Xorg || true

echo "📤 Copying result..."
cp -r dist /build/
echo "✅ Done!"