#!/usr/bin/env bash
set -e

# Variables
APPDIR=./minimalui.AppDir
BINARY=./minimal-ui
ICON=./minimalui.png       # icon in project root
DESKTOP=minimalui.desktop
TOOL=./appimagetool-i686.AppImage

# 1. Clean old AppDir but *don’t* remove existing top-level icon
rm -rf "$APPDIR"/{usr,var,AppRun,$DESKTOP}
mkdir -p "$APPDIR"/{usr/bin,usr/lib/i386-linux-gnu,icons}

# 2. Copy the 32-bit binary
cp "$BINARY" "$APPDIR/usr/bin/"
chmod +x "$APPDIR/usr/bin/$(basename $BINARY)"

# 3. Create or overwrite AppRun
cat > "$APPDIR/AppRun" << 'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "${0}")")"
export LD_LIBRARY_PATH="$HERE/usr/lib/i386-linux-gnu"
exec "$HERE/usr/bin/minimal-ui" "$@"
EOF
chmod +x "$APPDIR/AppRun"

# 4. Ensure we have an icon at AppDir root
if [[ ! -f "$APPDIR/minimalui.png" ]]; then
  if [[ -f "$ICON" ]]; then
    cp "$ICON" "$APPDIR/minimalui.png"
  else
    # generate a placeholder 256×256 PNG
    convert -size 256x256 canvas:lightgray \
            -gravity center -pointsize 48 \
            -annotate +0+0 "UI" \
            "$APPDIR/minimalui.png"
  fi
fi

# 5. Write the desktop file at AppDir root
cat > "$APPDIR/$DESKTOP" <<EOF
[Desktop Entry]
Name=Minimal UI
Exec=minimal-ui
Icon=minimalui
Type=Application
Categories=Utility;
EOF

# 6. Bundle all shared libs
ldd "$BINARY" \
  | awk '/=> \/.*\// { print $3 }' \
  | xargs -I '{}' cp '{}' "$APPDIR/usr/lib/i386-linux-gnu/"

# 7. Build the AppImage
chmod +x "$TOOL"
"$TOOL" "$APPDIR"
