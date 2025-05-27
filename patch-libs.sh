#!/bin/sh
set -eux

BUILD_OUT=/build-out
LIBDIR=$BUILD_OUT/libs
BIN=$BUILD_OUT/netsurf-fb

copy_dep_recursive() {
  dep="$1"

  # Skip if empty or special system libraries (optional)
  [ -z "$dep" ] && return
  case "$dep" in
    linux-vdso.so*|ld-linux.so*|ld-*.so*) return ;;
  esac

  # Avoid duplicates by checking if already copied
  target_path="$LIBDIR$dep"
  if [ -f "$target_path" ]; then
    echo "Already copied $dep"
    return
  fi

  echo "Copying $dep to $target_path"
  mkdir -p "$(dirname "$target_path")"
  cp -v "$dep" "$target_path"

  # Recursively copy dependencies of this lib
  ldd "$dep" | awk '/=>/ {print $3}' | while read -r nested_dep; do
    copy_dep_recursive "$nested_dep"
  done
}

# Clear libs folder to start fresh (optional)
rm -rf "$LIBDIR"
mkdir -p "$LIBDIR"

# Copy the interpreter (ld-linux.so) first
INTERP=$(readelf -l "$BIN" | awk '/interpreter/ {print $NF}' | tr -d '[]')

cp -v "$INTERP" "$LIBDIR"

# Recursively copy dependencies of the binary
ldd "$BIN" | awk '/=>/ {print $3}' | while read -r lib; do
  copy_dep_recursive "$lib"
done

# Now patch all copied libraries
find "$LIBDIR" -type f -name "*.so*" | while read -r lib; do
  echo "Patching $lib"
  patchelf --set-rpath '$ORIGIN' "$lib"
  patchelf --print-needed "$lib" | while read -r dep; do
    base_dep=$(basename "$dep")
    patchelf --replace-needed "$dep" "$base_dep" "$lib"
  done
done

# Patch the main binary
patchelf --set-rpath '$ORIGIN/libs' "$BIN"
patchelf --set-interpreter '$ORIGIN/libs/ld-linux.so.2' "$BIN"

echo "Binary RPATH:"
patchelf --print-rpath "$BIN"

echo "Binary interpreter:"
readelf -l "$BIN" | grep 'interpreter'
