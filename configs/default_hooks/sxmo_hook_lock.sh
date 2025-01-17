#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors
#
# See man 7 sxmo.states.
#
# This will:
# - blink blue led once
# - turn screen on
# - disable input
# - set up a daemon to automatically transition to screenoff state after 8s.

# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. sxmo_common.sh

# This hook is called when the system reaches a locked state

sxmo_led.sh blink blue &

case "$SXMO_WM" in
	sway)
    [ -f /tmp/last-binding-state ] || swaymsg -t get_binding_state | gojq -r .name >/tmp/last-binding-state
		swaymsg mode default
		;;
esac

sxmo_wm.sh dpms off
sxmo_wm.sh inputevent touchscreen off

sxmo_jobs.sh stop periodic_blink
sxmo_jobs.sh stop periodic_wakelock_check

# Go down after 8 seconds of inactivity
if [ -e "$XDG_CACHE_HOME/sxmo/sxmo.noidle" ]; then
	sxmo_jobs.sh stop idle_locker
else
	sxmo_jobs.sh start idle_locker sxmo_idle.sh -w \
		timeout "${SXMO_LOCK_IDLE_TIME:-8}" "sxmo_state.sh idle"
fi

wait
