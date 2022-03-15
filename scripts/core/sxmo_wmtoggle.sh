#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors

not_ready_yet() {
	sxmo_notify_user.sh "Your device looks not ready yet"
	exit 1
}

case "$(realpath /var/lib/tinydm/default-session.desktop)" in
	/usr/share/wayland-sessions/swmo.desktop)
		command -v dwm >/dev/null || not_ready_yet
		doas tinydm-set-session -f -s /usr/share/xsessions/sxmo.desktop
		pkill sway
		;;
	/usr/share/xsessions/sxmo.desktop)
		command -v sway >/dev/null || not_ready_yet
		doas tinydm-set-session -f -s /usr/share/wayland-sessions/swmo.desktop
		pkill dwm
		;;
esac
