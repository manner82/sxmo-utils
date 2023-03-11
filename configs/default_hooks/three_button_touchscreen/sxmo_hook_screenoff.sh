#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors

# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. sxmo_common.sh

# This hook is called when the system reaches a off state (screen off)

exec 3<> "$SXMO_STATE.lock"
flock -x 3

sxmo_log "transitioning to stage off"
printf screenoff > "$SXMO_STATE"
sxmo_hook_statusbar.sh state_change &

[ "$SXMO_WM" = "sway" ] && swaymsg mode default
sxmo_wm.sh dpms on
sxmo_wm.sh inputevent touchscreen off

sxmo_daemons.sh start periodic_blink sxmo_run_periodically.sh 2 sxmo_led.sh blink red blue

case "$SXMO_WM" in
	dwm)
		# dmenu will grab input focus (i.e. power button) so kill it before going to
		# screenoff unless proximity lock is running (i.e. there's a phone call).
		if ! sxmo_daemons.sh running proximity_lock -q; then
			sxmo_dmenu.sh close
		fi
		;;
esac

sxmo_hook_wakelocks.sh

# Start a periodic daemon (10s) to check wakelocks and go to suspend
# Start a periodic daemon (2s) to blink leds
sxmo_daemons.sh start idle_locker sxmo_idle.sh -w \
	timeout 10 'sxmo_daemons.sh start periodic_wakelock_check sxmo_run_periodically.sh 10 sxmo_hook_wakelocks.sh' \
	resume 'sxmo_daemons.sh stop periodic_wakelock_check'

wait

sxmo_wakelock.sh lock hold_a_bit 3s # avoid immediate suspension
sxmo_wakelock.sh unlock not_screenoff
