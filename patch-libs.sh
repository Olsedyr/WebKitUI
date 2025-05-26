#!/bin/sh
set -eux

BIN=./netsurf-fb
LIBDIR=./libs

mkdir -p "$LIBDIR"

# Copy actual interpreter (not $ORIGIN)
cp -v /lib/ld-linux.so.2 "$LIBDIR/"

# Copy all needed libraries
ldd "$BIN" | awk '{print $3}' | grep -v '^(' | while read lib; do
  [ -f "$lib" ] && cp -v --parents "$lib" "$LIBDIR/"
done

# Patch all copied libraries
find "$LIBDIR" -type f -name "*.so*" | while read lib; do
  echo "Patching $lib"
  patchelf --set-rpath '$ORIGIN' "$lib"
  for dep in $(patchelf --print-needed "$lib"); do
    patchelf --replace-needed "$dep" "$(basename "$dep")" "$lib"
  done
done

# Patch the binary
patchelf --set-rpath '$ORIGIN/libs' "$BIN"
patchelf --set-interpreter '$ORIGIN/libs/ld-linux.so.2' "$BIN"
