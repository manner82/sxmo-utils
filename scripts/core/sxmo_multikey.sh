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

sleep "$threshold"

if [ ! -f "$count_file" ]; then
	exit
fi

new_counter="$(cat "$count_file")"
if [ "$counter" != "$new_counter" ]; then
	exit
fi

shift "$counter"
rm "$count_file"
eval "$1"

