#!/usr/bin/env sh

TERMMODE=$([ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ] && echo "true")

if [ "$TERMMODE" != "true" ]; then
	wasopen="$(sxmo_keyboard.sh isopen && echo "yes")"
	sxmo_keyboard.sh open
fi

OUTPUT="$(cat | sxmo_dmenu.sh "$@")"
exitcode=$?

if [ "$TERMMODE" != "true" ]; then
	[ -z "$wasopen" ] && sxmo_keyboard.sh close
fi

printf %s "$OUTPUT"
exit $exitcode
