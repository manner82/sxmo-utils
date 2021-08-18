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

swayexec() {
	swaymsg exec -- "$@"
}

swayexecwait() {
	PIDFILE="$(mktemp)"
	printf '"%s" & printf %%s "$!" > "%s"' "$*" "$PIDFILE" \
		| xargs swaymsg exec -- sh -c
	while : ; do
		sleep 0.5
		kill -0 "$(cat "$PIDFILE")" 2> /dev/null || break
	done
	rm "$PIDFILE"
}

guesswm() {
	if [ -n "$SWAYSOCK" ]; then
		printf "sway"
	fi
}

wm="$(guesswm)"

action="$1"
shift
"$wm$action" "$@"
