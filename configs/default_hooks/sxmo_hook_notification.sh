#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors

VIBS=5
VIBI=0
while [ $VIBI -lt $VIBS ]; do
	sxmo_vibrate 400 &
	sleep 0.5
	VIBI=$(echo $VIBI+1 | bc)
done
