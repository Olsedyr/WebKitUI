#!/bin/sh
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
export LD_LIBRARY_PATH="$SCRIPT_DIR/libs"
export NETSURFRES="$SCRIPT_DIR/share/netsurf"
export FRAMEBUFFER=/dev/fb0
exec "$SCRIPT_DIR/netsurf-fb" "file://$SCRIPT_DIR/index.html"
