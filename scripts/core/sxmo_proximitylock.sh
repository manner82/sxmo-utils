#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors

isLocked() {
	! grep -q unlock "$SXMO_STATE"
}

finish() {
	sxmo_mutex.sh can_suspend free "Proximity lock is running"
	sxmo_hook_"$INITIALSTATE".sh
	exit 0
}

INITIALSTATE="$(cat "$SXMO_STATE")"
trap 'finish' TERM INT

sxmo_mutex.sh can_suspend lock "Proximity lock is running"

proximity_raw_bus="$(find /sys/devices/platform/soc -name 'in_proximity_raw')"
distance() {
	cat "$proximity_raw_bus"
}

TARGET=30

mainloop() {
	while true; do
		distance="$(distance)"
		if isLocked && [ "$distance" -lt "$TARGET" ]; then
			sxmo_hook_unlock.sh
		elif ! isLocked && [ "$distance" -gt "$TARGET" ]; then
			sxmo_hook_screenoff.sh
		fi
		sleep 0.5
	done
}

mainloop
