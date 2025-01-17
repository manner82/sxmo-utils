#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors
# Wileyfox Swift (wileyfox-crackling)

export SXMO_TOUCHSCREEN_ID="10"
export SXMO_POWER_BUTTON="0:0:pm8941_pwrkey"
export SXMO_VOLUME_BUTTON="1:1:GPIO_Buttons 0:0:pm8941_resin"
export SXMO_VIBRATE_DEV="/dev/input/by-path/platform-200f000.spmi-platform-200f000.spmi:pmic@1:vibrator@c000-event"
export SXMO_SWAY_SCALE="2"
