#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors

# This script is executed (asynchronously) when you get an incoming call
# You can use it to play a ring tone

# $1 = Contact Name or Number (if not in contacts)

# shellcheck source=scripts/core/sxmo_common.sh
. sxmo_common.sh

# Only vibrate if you already got an active call
if sxmo_modemcall.sh list_active_calls \
	| grep -v ringing-in \
	| grep -q .; then
	sxmo_vibrate 1500
	exit
fi

# Shallow if you have more than one ringing call
if ! sxmo_modemcall.sh list_active_calls \
	| grep -c ringing-in \
	| grep -q 1; then
	exit
fi

# Start the mpv ring until another hook kill it or the max SXMO_RINGTIME or SXMO_RINGNUMBER is reached
case "$(cat "$XDG_CONFIG_HOME"/sxmo/.ringmode)" in
	Mute)
	;;
	Vibrate)
		for _ in $(seq 5); do
			sxmo_vibrate 1500
			sleep 0.5
		done
		;;
	Ring)
		timeout "$SXMO_RINGTIME" mpv --no-resume-playback --quiet --no-video \
			--loop="$SXMO_RINGNUMBER" "$SXMO_RINGTONE" &
		MPVID=$!
		echo "$MPVID" > "$XDG_RUNTIME_DIR/sxmo.ring.pid"
	;;
	*) #Default ring and vibrate
		timeout "$SXMO_RINGTIME" mpv --no-resume-playback --quiet --no-video \
			--loop="$SXMO_RINGNUMBER" "$SXMO_RINGTONE" &
		MPVID=$!
		echo "$MPVID" > "$XDG_RUNTIME_DIR/sxmo.ring.pid"
		# Vibrate while mpv is running
		while kill -0 $MPVID; do
				sxmo_vibrate 1500
				sleep 0.5
		done
		;;
esac
