#!/bin/sh
# shellcheck disable=SC2086

if [ -z "$*" ]; then
	set -- $SHELL
fi

if [ -z "$TERMNAME" ]; then
	TERMNAME="$*"
fi

case "$TERMCMD" in
	"st -e")
		set -- st -T "$TERMNAME" -e "$@"
		;;
	"foot")
		set -- foot -T "$TERMNAME" "$@"
		;;
	"vte-2.91"*)
		set -- ${TERMCMD% --} --title "$TERMNAME" -- "$@"
		;;
	*)
		printf "%s: '%s'\n" "Not implemented for TERMCMD" "$TERMCMD" >&2
		set -- $TERMCMD "$@"
esac

exec "$@"
