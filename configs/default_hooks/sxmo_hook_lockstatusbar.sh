#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors

# For use with peanutbutter (peanutbutter --font Sxmo --statuscommand sxmo_hook_lockstatusbar.sh)
# This filters out the last component (which is usually the time and is already displayed more prominently

# make sure status bar icons are suited for peanutbutter
sxmo_hook_statusbar.sh state_change

# obtain status output to pass to peanutbutter (this keeps running and updating to stdout)
exec sxmo_status_watch.sh -o pango
