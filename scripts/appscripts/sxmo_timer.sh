#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors
# title="$icon_clk Timer"
# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. sxmo_common.sh

timerrun() {
	TIME=$(
		echo "$@" |
		sed 's/\([^0-9]\)\([0-9]\)/\1+\2/g; s/h/*60m/g; s/m/*60s/g; s/s//g' |
		bc
	)

	DATE1=$(($(date +%s) + TIME));
	while [ "$DATE1" -ge "$(date +%s)" ]; do
		printf %b "$(date -u --date @$((DATE1 - $(date +%s))) +%H:%M:%S) \r";
		sleep 0.1
	done
	echo "Done with $*"

	while :;
		do notify-send  "Done with $*";
		sxmo_vibrate 1000
		sleep 0.5
	done
}

stopwatchrun() {
	start="$(date +%s)"
	while true; do
		time="$(($(date +%s) - start))"
		printf '%s\r' "$(date -u -d "@$time" +%H:%M:%S)"
	done
	sleep 0.1
}

menu() {
	TIMEINPUT="$(
		echo "
			Stopwatch
			1h
			10m
			9m
			8m
			7m
			6m
			5m
			4m
			3m
			2m
			1m
			30s
			Close Menu
		" | awk 'NF' | awk '{$1=$1};1' | sxmo_dmenu_with_kb.sh -p Timer
	)" || exit 0
	case "$TIMEINPUT" in
	"Close Menu") exit 0 ;;
	"Stopwatch")
		sxmo_terminal.sh "$0" stopwatchrun
		;;
	*)
		sxmo_terminal.sh "$0" timerrun "$TIMEINPUT"
		;;
	esac
}

if [ $# -gt 0 ]; then "$@"; else menu; fi
