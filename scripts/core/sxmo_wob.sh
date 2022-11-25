#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors

# This script is responsible for starting wob, and making sure it exits cleanly

# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. sxmo_common.sh

wob_sock="$XDG_RUNTIME_DIR"/sxmo.wobsock
rm -f "$wob_sock"
mkfifo "$wob_sock"

# By opening the socket as read-write it isn't closed after the first write
# see https://unix.stackexchange.com/questions/392697
wob <> "$wob_sock" &
WOBPID=$!

finish() {
	# Only finish once
	trap - TERM INT EXIT
	kill "$WOBPID"
	rm -f "$wob_sock"
}
trap 'finish' TERM INT EXIT

wait "$WOBPID"
