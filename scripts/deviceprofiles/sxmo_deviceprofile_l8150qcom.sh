#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors
# Wileyfox Swift (wileyfox-crackling)

export SXMO_TOUCHSCREEN_ID="10"

export SXMO_ROTATION_GRAVITY="500"
export SXMO_ROTATION_THRESHOLD="60"
export LED_WHITE_TYPE="kbd_backlight"
export SXMO_SYS_FILES="/sys/power/state /sys/power/mem_sleep /sys/bus/usb/drivers/usb/unbind /sys/bus/usb/drivers/usb/bind /dev/rtc0"
