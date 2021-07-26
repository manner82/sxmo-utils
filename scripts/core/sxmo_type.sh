#!/bin/sh

if [ -n "$WAYLAND_DISPLAY" ]; then
	wtype "$@"
fi
