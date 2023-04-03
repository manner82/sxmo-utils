#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors

# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. sxmo_common.sh

exec 3<> "$SXMO_STATE.lock"
flock -x 3

sxmo_log "transitioning to stage lock"
printf lock > "$SXMO_STATE"

sxmo_wakelock.sh lock not_screenoff infinite

# This hook is called when the system reaches a locked state

sxmo_led.sh blink blue &
sxmo_hook_statusbar.sh state_change &

case "$SXMO_WM" in
	sway)
    [ -f /tmp/last-binding-state ] || swaymsg -t get_binding_state | gojq -r .name >/tmp/last-binding-state
		swaymsg mode default
		;;
esac

sxmo_wm.sh dpms off
sxmo_wm.sh inputevent touchscreen off

sxmo_daemons.sh stop periodic_blink
sxmo_daemons.sh stop periodic_wakelock_check

# Go to screenoff after 8 seconds of inactivity
if ! [ -e "$XDG_CACHE_HOME/sxmo/sxmo.noidle" ]; then
	sxmo_daemons.sh start idle_locker sxmo_idle.sh -w \
		timeout 8 "sxmo_hook_screenoff.sh"
fi

wait
