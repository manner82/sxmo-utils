#!/bin/sh

identifier="$1"
threshold="${SXMO_THRESHOLD:-0.30}"

count_file="$XDG_RUNTIME_DIR"/sxmo.multikey.count."$identifier"

if [ -f "$count_file" ]; then
	counter="$(($(cat "$count_file")+1))"
else
	counter=1
fi

printf %s "$counter" > "$count_file"
shift "$counter"
if [ "$#" -eq 1 ]; then
	last_action=1
elif [ "$#" -eq 0 ]; then
	exit
fi

sleep "$threshold"

if [ ! -f "$count_file" ]; then
	exit
fi

new_counter="$(cat "$count_file")"
if [ "$counter" != "$new_counter" ]; then
	if [ -n "$last_action" ] && [ "$new_counter" -gt "$counter" ]; then
		count_overflow=1
	else
		exit
	fi
fi

eval "$1"

if [ -n "$count_overflow" ]; then
	sleep "$threshold" # prevent too long long presses to chain
fi

rm "$count_file"

