#!/bin/sh
export LD_LIBRARY_PATH=.
export NETSURFRES=./share/netsurf
exec ./netsurf-fb file://./index.html
