#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors

sxmo_status_watch.sh -o pango | stdbuf -o0 tr '\n' '\0' | xargs -0 -n1 xsetroot -name
