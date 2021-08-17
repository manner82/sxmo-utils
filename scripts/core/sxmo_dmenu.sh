#!/usr/bin/env sh

TERMMODE=$([ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ] && echo "true")

if [ -z "$BEMENU_OPTS" ]; then
	export BEMENU_OPTS='
		-m -1
		--hb "#222222"
		--tb "#222222"
		--fb "#222222"
		--nb "#222222"
		--sb "#222222"
		--hb "#285577"
		--hf "#222222"
		--tf "#285577"
		--nf "#285577"
		--scb "#222222"
		--scf "#285577"
		--ff "#285577"
		--fn "Monospace 11"
	'
fi

if [ "$TERMMODE" != "true" ]; then
	set -- bemenu -n -w -c -l "$(sxmo_rotate.sh isrotated && printf 7 ||  printf 23)" "$@"
else
	set -- BEMENU_BACKEND=curses bemenu "$@"
fi

exec "$@"
