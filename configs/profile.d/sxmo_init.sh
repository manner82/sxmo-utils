#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors

# This script is meant to be sourced on login shells

_sxmo_is_running() {
	unset SXMO_WM

	if [ -f "${XDG_RUNTIME_DIR:-/dev/shm/user/$(id -u)}"/sxmo.swaysock ]; then
		unset SWAYSOCK
		if SWAYSOCK="$(cat "${XDG_RUNTIME_DIR:-/dev/shm/user/$(id -u)}"/sxmo.swaysock)" \
			swaymsg 2>/dev/null; then
			printf "Detected the Sway environment\n" >&2
			export SXMO_WM=sway
			return 0
		fi
	fi

	if DISPLAY=:0 xrandr >/dev/null 2>&1; then
		printf "Detected the Dwm environment\n" >&2
		export SXMO_WM=dwm
		return 0
	fi

	printf "Sxmo is not running\n" >&2
	return 1
}

_sxmo_load_environments() {
	# Determine current operating system see os-release(5)
	# https://www.linux.org/docs/man5/os-release.html
	if [ -e /etc/os-release ]; then
		# shellcheck source=/dev/null
		. /etc/os-release
	elif [ -e /usr/lib/os-release ]; then
		# shellcheck source=/dev/null
		. /usr/lib/os-release
	fi
	export OS="${ID:-unknown}"

	export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
	export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
	export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
	export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
	export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/dev/shm/user/$(id -u)}"

	export SXMO_CACHEDIR="${SXMO_CACHEDIR:-$XDG_CACHE_HOME/sxmo}"
	export SXMO_DEBUGLOG="${SXMO_DEBUGLOG:-$XDG_STATE_HOME/tinydm.log}"

	export SXMO_BLOCKDIR="${SXMO_BLOCKDIR:-$SXMO_CACHEDIR/block}"
	export SXMO_BLOCKFILE="${SXMO_BLOCKFILE:-$SXMO_CACHEDIR/block.tsv}"
	export SXMO_CONTACTFILE="${SXMO_CONTACTFILE:-$SXMO_CACHEDIR/contacts.tsv}"
	export SXMO_STATE="${SXMO_STATE:-$XDG_RUNTIME_DIR/sxmo.state}"
	export SXMO_LOGDIR="${SXMO_LOGDIR:-$XDG_DATA_HOME/sxmo/modem}"
	export SXMO_NOTIFDIR="${SXMO_NOTIFDIR:-$SXMO_CACHEDIR/notifications}"
	export SXMO_UNSUSPENDREASONFILE="${SXMO_UNSUSPENDREASONFILE:-$XDG_RUNTIME_DIR/sxmo.suspend.reason}"

	export BEMENU_OPTS="${BEMENU_OPTS:---fn 'Monospace 14' --scrollbar autohide -s -n -w -c -l8 -M 40 -H 20}"

	export EDITOR="${EDITOR:-vim}"
	export BROWSER="${BROWSER:-firefox}"
	export SHELL="${SHELL:-/bin/sh}"

	#also fall back if user set something that doesn't exist:
	command -v "$BROWSER" >/dev/null || export BROWSER=firefox
	command -v "$EDITOR" >/dev/null || export EDITOR=vim
	command -v "$SHELL" >/dev/null || export SHELL=/bin/sh

	export PATH="$XDG_CONFIG_HOME/sxmo/hooks/:/usr/share/sxmo/default_hooks/:$PATH"

	# The user can already forced a $SXMO_DEVICE_NAME value
	if [ -z "$SXMO_DEVICE_NAME" ] && [ -e /sys/firmware/devicetree/base/compatible ]; then
		SXMO_DEVICE_NAME="$(cut -d ',' -f 2 < /sys/firmware/devicetree/base/compatible | tr -d '\0')"
		export SXMO_DEVICE_NAME
		deviceprofile="$(which "sxmo_deviceprofile_$SXMO_DEVICE_NAME.sh")"
		# shellcheck disable=SC1090
		if [ -f "$deviceprofile" ]; then
			. "$deviceprofile"
			printf "deviceprofile file %s loaded.\n" "$deviceprofile"
		else
			printf "WARNING: deviceprofile file %s not found.\n" "$deviceprofile"
		fi
	fi

	if [ -n "$SXMO_DEVICE_NAME" ]; then
		export PATH="$XDG_CONFIG_HOME/sxmo/hooks/$SXMO_DEVICE_NAME/:/usr/share/sxmo/default_hooks/$SXMO_DEVICE_NAME/:$PATH"
	fi
}

_sxmo_grab_session() {
	if ! _sxmo_is_running; then
		return
	fi

	_sxmo_load_environments

	if [ -f "$XDG_RUNTIME_DIR"/dbus.bus ]; then
		DBUS_SESSION_BUS_ADDRESS="$(cat "$XDG_RUNTIME_DIR"/dbus.bus)"
		export DBUS_SESSION_BUS_ADDRESS
		if ! dbus-send --dest=org.freedesktop.DBus \
			/org/freedesktop/DBus org.freedesktop.DBus.ListNames \
			2> /dev/null; then
				printf "WARNING: The dbus-send test failed with DBUS_SESSION_BUS_ADDRESS=%s. Unsetting...\n" "$DBUS_SESSION_BUS_ADDRESS" >&2
				unset DBUS_SESSION_BUS_ADDRESS
		fi
	else
		printf "WARNING: No dbus cache file found at %s/dbus.bus.\n" "$XDG_RUNTIME_DIR" >&2
	fi

	# We dont export DISPLAY and WAYLAND_DISPLAY on purpose
	case "$SXMO_WM" in
		sway)
			if [ -f "$XDG_RUNTIME_DIR"/sxmo.swaysock ]; then
				SWAYSOCK="$(cat "$XDG_RUNTIME_DIR"/sxmo.swaysock)"
				export SWAYSOCK
			fi
			;;
	esac
}

_sxmo_prepare_dirs() {
	mkdir -p "$XDG_RUNTIME_DIR"
	chmod 700 "$XDG_RUNTIME_DIR"
	chown "$USER:$USER" "$XDG_RUNTIME_DIR"

	mkdir -p "$XDG_CACHE_HOME/sxmo/"
	chmod 700 "$XDG_CACHE_HOME"
	chown "$USER:$USER" "$XDG_CACHE_HOME"
}

_sxmo_grab_session
