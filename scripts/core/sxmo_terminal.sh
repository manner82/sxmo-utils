#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors
# shellcheck disable=SC2086

if [ -z "$*" ]; then
	set -- $SHELL
fi

if [ -z "$TERMNAME" ]; then
	TERMNAME="$*"
fi

case "$TERMCMD" in
	"st"*)
		set -- $TERMCMD -T "$TERMNAME" -e "$@"
		;;
	"foot"*)
		set -- $TERMCMD -T "$TERMNAME" "$@"
		;;
	"vte-2.91"*)
		set -- ${TERMCMD% --} --title "$TERMNAME" -- "$@"
		;;
	"alacritty"*)
		set -- $TERMCMD -T "$TERMNAME" -e "$@"
		;;
	*)
		printf "%s: '%s'\n" "Not implemented for TERMCMD" "$TERMCMD" >&2
		set -- $TERMCMD "$@"
esac

exec "$@"
