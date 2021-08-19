#!/usr/bin/env sh

TERMMODE=$([ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ] && echo "true")

if [ -z "$BEMENU_OPTS" ]; then
	export BEMENU_OPTS='--fn "Monospace 11"'
fi

if [ "dwm" = "$(sxmo_wm.sh)" ]; then
	if [ "$1" = isopen ]; then
		exec pgrep dmenu > /dev/null
	elif [ "$1" = close ]; then
		exec pkill dmenu
	else
		exec dmenu -c -l "$(sxmo_rotate.sh isrotated && printf 7 || printf 23)" "$@"
	fi
fi

if [ "$1" = isopen ]; then
	exec pgrep bemenu > /dev/null
elif [ "$1" = close ]; then
	exec pkill bemenu
fi

if [ "$TERMMODE" != "true" ]; then
	set -- bemenu --scrollbar autohide -n -w -c -l "$(sxmo_rotate.sh isrotated && printf 7 ||  printf 23)" "$@"
else
	set -- BEMENU_BACKEND=curses bemenu "$@"
fi

exec "$@"
