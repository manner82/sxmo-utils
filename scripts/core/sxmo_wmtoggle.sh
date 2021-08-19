#!/bin/sh

wm="$(sxmo_wm.sh)"

set -x

sudo rc-service tinydm restart # prevent too much loop
sleep 2

case "$(realpath /var/lib/tinydm/default-session.desktop)" in
	/usr/share/wayland-sessions/swmo.desktop)
		sudo tinydm-set-session -f -s /usr/share/xsessions/sxmo.desktop
		;;
	/usr/share/xsessions/sxmo.desktop)
		sudo tinydm-set-session -f -s /usr/share/wayland-sessions/swmo.desktop
		;;
esac

pkill "$wm"
