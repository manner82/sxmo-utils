#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors
# title="$icon_cam Screenshot"
# scrot refuses to work with double quotes
# shellcheck disable=SC2016


exit_msg() {
	printf "%s\n" "$1" > /dev/stderr
	notify-send "$1"
	exit 1
}

check_command() {
	command -v "$1" > /dev/null
}

sway_screenshot() {
	check_command grim || exit_msg "grim command must be available to take a screenshot."
	check_command slurp || exit_msg "slurp command must be available to make a selection."

	area="$(slurp -o)"
	if [ -z "$area" ]; then
		area="$(swaymsg -t get_outputs | jq -r '.[] |select (.focused) | .rect | "\(.x),\(.y) \(.width)x\(.height)"')"
	fi
	wxh=$(echo "$area" | cut -d " " -f 2)
	w=$(echo "$wxh" | cut -d "x" -f 1)
	h=$(echo "$wxh" | cut -d "x" -f 2)
	if [ -n "$wxh" ] && [ "$w" -gt 9 ] && [ "$h" -gt 9 ]; then
		#we have a selection (bigger than 9x9)
		grim -g "$area" "$1" || exit_msg "Screenshot failed"
	else
		exit_msg "Invalid screenshot selection (too small)"
	fi
}

xorg_screenshot() {
	check_command scrot || exit_msg "scrot command must be available to take a screenshot"

	scrot -d 1 -q 1 -s "$1"
}

screenshot() {
	case "$SXMO_WM" in
		sway)
			sway_screenshot "$@"
			;;
		dwm)
			xorg_screenshot "$@"
			;;
		*)
			exit_msg "We dont know the WM, cannot screenshot."
			;;
	esac
}

yank() {
	printf %s "$1" | case "$SXMO_WM" in
		sway)
			wl-copy
			;;
		dwm)
			xsel -b -i
			;;
		*)
			exit_msg "We dont know the WM, cannot yank."
			;;
	esac
}

SXMO_SCREENSHOT_DIR="${SXMO_SCREENSHOT_DIR:-$HOME/screenshots}"
mkdir -p "$SXMO_SCREENSHOT_DIR"
FILENAME="$SXMO_SCREENSHOT_DIR/$(date +%Y-%m-%d-%T).png"

screenshot "$FILENAME"
yank "$FILENAME"
printf %s "$FILENAME"

notify-send --urgency=low "Screenshot taken" "$FILENAME"
