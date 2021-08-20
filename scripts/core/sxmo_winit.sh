#!/usr/bin/env sh


envvars() {
	# shellcheck disable=SC1091
	[ -f /etc/profile ] && . /etc/profile
	# shellcheck source=/dev/null
	export BEMENU_OPTS='--fn "Monospace 11"'
	[ -f "$HOME"/.profile ] && . "$HOME"/.profile
	export MOZ_ENABLE_WAYLAND=1
	command -v "$TERMCMD" || export TERMCMD="foot"
	command -v "$BROWSER" || export BROWSER=firefox
	command -v "$EDITOR" || export EDITOR=vis
	command -v "$SHELL" || export SHELL=/bin/sh
	command -v "$KEYBOARD" || defaultkeyboard
	[ -z "$MPV_HOME" ] && export MPV_HOME=/usr/share/sxmo/mpv
	[ -z "$MOZ_USE_XINPUT2" ] && export MOZ_USE_XINPUT2=1
	[ -z "$XDG_CONFIG_HOME" ] && export XDG_CONFIG_HOME=~/.config
	[ -z "$XDG_CACHE_HOME" ] && export XDG_CACHE_HOME=~/.cache
	[ -z "$XDG_DATA_HOME" ] && export XDG_DATA_HOME=~/.local/share
	[ -z "$XDG_RUNTIME_DIR" ] && export XDG_RUNTIME_DIR=~/.local/run
	[ -z "$XDG_PICTURES_DIR" ] && export XDG_PICTURES_DIR=~/Pictures
}

device_envvars() {
	device="$(cut -d ',' -f 2 < /sys/firmware/devicetree/base/compatible)"
	deviceprofile="$(which "sxmo_deviceprofile_$device.sh")"
	# shellcheck disable=SC1090
	[ -f "$deviceprofile" ] && . "$deviceprofile"
}

setupxdgdir() {
	mkdir -p $XDG_RUNTIME_DIR
	chmod 700 $XDG_RUNTIME_DIR
	chown "$USER:$USER" "$XDG_RUNTIME_DIR"

	mkdir -p "$XDG_CACHE_HOME/sxmo/"
	chmod 700 "$XDG_CACHE_HOME"
	chown "$USER:$USER" "$XDG_CACHE_HOME"
}

defaults() {
	alsactl --file /usr/share/sxmo/alsa/default_alsa_sound.conf restore
	[ -e "$HOME"/.Xresources ] && xrdb -merge "$HOME"/.Xresources
}

defaultkeyboard() {
	export KEYBOARD=wvkbd
}

defaultconfig() {
	if [ ! -r "$2" ]; then
		mkdir -p "$(dirname "$2")"
		cp "$1" "$2"
		chmod "$3" "$2"
	fi
}

defaultconfigs() {
	[ -r "$XDG_CONFIG_HOME/sxmo/sway" ] && return

	defaultconfig /usr/share/sxmo/appcfg/sway_template "$XDG_CONFIG_HOME/sxmo/sway" 744
	defaultconfig /usr/share/sxmo/appcfg/mako.conf "$XDG_CONFIG_HOME/mako/config" 744
	defaultconfig /usr/share/sxmo/appcfg/foot.ini "$XDG_CONFIG_HOME/foot/foot.ini" 744
}

startsway() {
	exec dbus-run-session sh -c "
		/usr/bin/sway -c "$XDG_CONFIG_HOME/sxmo/sway" 2> "$XDG_CACHE_HOME/sxmo/sway.log"
	"
}

init() {
	envvars
	device_envvars # set device env vars here to allow potentially overriding envvars

	# include common definitions
	# shellcheck source=scripts/core/sxmo_common.sh
	. "$(dirname "$0")/sxmo_common.sh"

	setupxdgdir
	defaults
	defaultconfigs
	startsway
}

if [ -z "$1" ]; then
	init 2> ~/.init.log #hard-coded location because at this stage we're not sure the xdg dirs exist yet
else
	"$1"
fi
