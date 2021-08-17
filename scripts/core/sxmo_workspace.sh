#!/bin/bash

# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. "$(dirname "$0")/sxmo_common.sh"

current() {
	swaymsg -t get_outputs  | \
		jq -r '.[] | select(.focused == true) | .current_workspace'
}

next() {
	printf %s "$(($(current)+1))"
}

previous() {
	printf %s "$(($(current)-1))"
}

case "$1" in
	next)
		printf "workspace "
		next;;
	previous)
		printf "workspace "
		previous;;
	move-next)
		printf "move container to workspace "
		next;;
	move-previous)
		printf "move container to workspace "
		previous;;
esac | xargs swaymsg

