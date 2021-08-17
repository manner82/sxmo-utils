#!/usr/bin/env sh

TERMMODE=$([ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ] && echo "true")

if [ -z "$BEMENU_OPTS" ]; then
	export BEMENU_OPTS='--fn "Monospace 11"'
fi

if [ "$TERMMODE" != "true" ]; then
	set -- bemenu -n -w -c -l "$(sxmo_rotate.sh isrotated && printf 7 ||  printf 23)" "$@"
else
	set -- BEMENU_BACKEND=curses bemenu "$@"
fi

exec "$@"
