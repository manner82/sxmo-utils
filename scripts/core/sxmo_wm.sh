#!/bin/sh

# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. "$(dirname "$0")/sxmo_common.sh"

swaydpms() {
	STATE=off
	if swaymsg -t get_outputs \
		| jq '.[] | select(.name == "DSI-1") | .dpms' \
		| grep -q "false"; then
		STATE=on
	fi

	if [ "$1" = on ] && [ "$STATE" != on ]; then
		swaymsg -- output DSI-1 dpms false
	elif [ "$1" = off ] && [ "$STATE" != off ] ; then
		swaymsg -- output DSI-1 dpms true
	else
		printf %s "$STATE"
	fi
}

swayinputevent() {
	DEVICE=1046:4097:Goodix_Capacitive_TouchScreen
	STATE=on
	if swaymsg -t get_inputs \
		| jq -r '.[] | select(.type == "touch" ) | .libinput.send_events' \
		| grep -q "disabled"; then
		STATE=off
	fi

	if [ "$1" = on ] && [ "$STATE" != on ]; then
		swaymsg -- input "$DEVICE" events enabled
	elif [ "$1" = off ] && [ "$STATE" != off ] ; then
		swaymsg -- input "$DEVICE" events disabled
	else
		printf %s "$STATE"
	fi
}

swayfocusedwindow() {
	swaymsg -t get_tree \
		| jq -r '
			recurse(.nodes[]) |
			select(.focused == true) |
			{app_id: .app_id, name: .name} |
			"app: " + .app_id, "title: " + .name
		'
}

guesswm() {
	if [ -n "$WAYLAND_DISPLAY" ]; then
		printf "sway"
	fi
}

wm="$(guesswm)"

echo "$wm$1" "$2"
"$wm$1" "$2"
