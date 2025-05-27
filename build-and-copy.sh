#!/usr/bin/env bash
set -euo pipefail           # fail fast

IMAGE=netsurf-builder:latest
DIST_DIR="$(pwd)/dist"      # absolute path is safest

echo "⚙️  Building Docker image…"
docker build --platform linux/386 -t "$IMAGE" .

# 1️⃣  Get rid of any previous build *cleanly*
echo "🧹 Removing old dist directory (if any)…"
rm -rf "$DIST_DIR"

# 2️⃣  Create a stopped container from the image
CID=$(docker create "$IMAGE")

# 3️⃣  Copy the *whole* dist folder onto the host
echo "📦 Copying build from container to host…"
docker cp "$CID:/build-out/WebKitUI/dist" "$DIST_DIR"

# 4️⃣  Throw the temporary container away
docker rm "$CID" >/dev/null

echo "✅ Build copied to $DIST_DIR"
ls -lh "$DIST_DIR"
