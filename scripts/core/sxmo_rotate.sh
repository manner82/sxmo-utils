#!/usr/bin/env sh

# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. "$(dirname "$0")/sxmo_common.sh"

applyptrmatrix() {
	TOUCH_POINTER_ID="${TOUCH_POINTER_ID:-8}"
	xinput set-prop "$TOUCH_POINTER_ID" --type=float --type=float "Coordinate Transformation Matrix" "$@"
}

swaytransforms() {
	swaymsg -p -t get_outputs | awk '
		/Output/ { printf $2 " " };
		/Transform/ { print $2 }'
}

isrotated() {
	swaytransforms | grep DSI-1 | grep -q 0
}

rotnormal() {
	swaymsg -- output  DSI-1 transform 0
	sxmo_hooks.sh lisgdstart &
	exit 0
}

rotright() {
	swaymsg -- output  DSI-1 transform 90
	sxmo_hooks.sh lisgdstart
	exit 0
}

rotleft() {
	swaymsg -- output  DSI-1 transform 270
	sxmo_hooks.sh lisgdstart
	exit 0
}

rotate() {
	if isrotated; then rotnormal; else rotright; fi
}

if [ -z "$1" ]; then
	rotate
else
	"$1"
fi
