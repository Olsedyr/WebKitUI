#!/bin/sh
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
export LD_LIBRARY_PATH="$SCRIPT_DIR/libs"
"$SCRIPT_DIR/netsurf-fb" "file://$SCRIPT_DIR/index.html"

