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

sxmo_led.sh blink blue red &
sxmo_hook_statusbar.sh state_change &

[ "$SXMO_WM" = "sway" ] && swaymsg mode default
sxmo_wm.sh dpms on
sxmo_wm.sh inputevent touchscreen off

case "$SXMO_WM" in
	dwm)
		# dmenu will grab input focus (i.e. power button) so kill it before going to
		# screenoff unless proximity lock is running (i.e. there's a phone call).
		if ! sxmo_daemons.sh running proximity_lock -q; then
			sxmo_dmenu.sh close
		fi
		;;
esac

sxmo_hook_check_state_mutexes.sh

# Start a periodic daemon (8s) "try to go to crust" after 8 seconds
# Start a periodic daemon (2s) blink after 5 seconds
# Resume tasks stop daemons
sxmo_daemons.sh start idle_locker sxmo_idle.sh -w \
	timeout 2 'sxmo_daemons.sh start periodic_blink sxmo_run_periodically.sh 2 sxmo_led.sh blink red blue' \
	resume 'sxmo_daemons.sh stop periodic_blink' \
	timeout 10 'sxmo_daemons.sh start periodic_state_mutex_check sxmo_run_periodically.sh 10 sxmo_hook_check_state_mutexes.sh' \
	resume 'sxmo_daemons.sh stop periodic_state_mutex_check'

wait

if [ -f /sys/power/wake_unlock ]; then
	echo not_screenoff | doas tee -a /sys/power/wake_unlock > /dev/null
fi
