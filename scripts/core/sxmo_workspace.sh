#!/bin/bash

current() {
	swaymsg -t get_outputs  | \
		jq -r '.[] | select(.focused == true) | .current_workspace'
}

next() {
	value="$(($(current)+1))"
	if [ "$value" -gt 4 ]; then
		printf 1
	else
		printf %s "$value"
	fi
}

previous() {
	value="$(($(current)-1))"
	if [ "$value" -lt 1 ]; then
		printf 4
	else
		printf %s "$value"
	fi
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

