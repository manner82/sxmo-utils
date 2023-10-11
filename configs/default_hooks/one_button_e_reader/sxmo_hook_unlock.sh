#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors

# This hook is called when the system becomes unlocked again

# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. sxmo_common.sh

sxmo_wakelock.sh lock sxmo_stay_awake "${SXMO_UNLOCK_IDLE_TIME:-120}s"

sxmo_hook_statusbar.sh state_change &

sxmo_wm.sh dpms off
sxmo_wm.sh inputevent touchscreen on
sxmo_wm.sh inputevent stylus on

if [ ! -e "$XDG_CACHE_HOME"/sxmo/sxmo.nogesture ]; then
	superctl start sxmo_hook_lisgd
fi

# suspend after if no activity after 120s
sxmo_jobs.sh start idle_locker sxmo_idle.sh -w \
	timeout "1" '' \
	resume "sxmo_wakelock.sh lock sxmo_stay_awake \"${SXMO_UNLOCK_IDLE_TIME:-120}s\""

wait
