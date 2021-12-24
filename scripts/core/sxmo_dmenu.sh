#!/usr/bin/env sh

# We still use dmenu in dwm|worgs cause pointer/touch events
# are not implemented yet in the X11 library of bemenu

case "$1" in
	isopen)
		case "$(sxmo_wm.sh)" in
			sway|ssh)
				exec pgrep bemenu
				;;
			xorg|dwm)
				exec pgrep dmenu
				;;
		esac
		;;
	close)
		case "$(sxmo_wm.sh)" in
			sway|ssh)
				exec pkill bemenu
				;;
			xorg|dwm)
				exec pkill dmenu
				;;
		esac
		;;
esac > /dev/null

case "$(sxmo_wm.sh)" in
	sway)
		swaymsg mode menu -q # disable default button inputs
		cleanmode() {
			swaymsg mode default -q
		}
		trap 'cleanmode' TERM INT

		bemenu -l "$(sxmo_rotate.sh isrotated > /dev/null && printf 8 ||  printf 15)" "$@"
		returned=$?

		cleanmode
		exit "$returned"
		;;
	xorg|dwm)
		if sxmo_keyboard.sh isopen; then
			exec dmenu -c -l "$(sxmo_rotate.sh isrotated > /dev/null && printf 5 || printf 12)" "$@"
		else
			exec dmenu -c -l "$(sxmo_rotate.sh isrotated > /dev/null && printf 7 || printf 15)" "$@"
		fi
		;;
	ssh)
		export BEMENU_BACKEND=curses
		exec bemenu -w "$@"
		;;
esac
