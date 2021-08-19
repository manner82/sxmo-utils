#!/usr/bin/env sh

# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. "$(dirname "$0")/sxmo_common.sh"

trap "update" USR1

update() {
	# In-call.. show length of call
	CALLINFO=" "
	if pgrep -f sxmo_modemcall.sh; then
		NOWS="$(date +"%s")"
		CALLSTARTS="$(date +"%s" -d "$(
			grep -aE 'call_start|call_pickup' "$XDG_DATA_HOME"/sxmo/modem/modemlog.tsv |
			tail -n1 |
			cut -f1
		)")"
		CALLSECONDS="$(echo "$NOWS" - "$CALLSTARTS" | bc)"
		CALLINFO="${CALLSECONDS}s"
	fi

	# symbol if wireguard/vpn is connected
	VPN=""
	VPNDEVICE="$(nmcli con show | grep vpn | awk '{ print $4 }')"
	WGDEVICE="$(nmcli con show | grep wireguard | awk '{ print $4 }')"
	if [ -n "$VPNDEVICE" ] && [ "$VPNDEVICE" != "--" ]; then
		VPN=""
	elif [ -n "$WGDEVICE" ] && [ "$WGDEVICE" != "--" ]; then
		VPN=""
	fi

	# W symbol if wireless is connect
	WIRELESS=""
	WLANSTATE="$(tr -d "\n" < /sys/class/net/wlan0/operstate)"
	if [ "$WLANSTATE" = "up" ]; then
		WIRELESS=""
	fi

	# M symbol if modem monitoring is on & modem present
	MODEMMON=""
	if [ -f "$MODEMSTATEFILE" ]; then
		MODEMSTATE="$(cat "$MODEMSTATEFILE")"
		if [ locked = "$MODEMSTATE" ]; then
			MODEMMON=""
		elif [ registered = "$MODEMSTATE" ]; then
			MODEMMON=""
		elif [ connected = "$MODEMSTATE" ]; then
			MODEMMON=""
		elif [ failed = "$MODEMSTATE" ] || [ disconnected = "$MODEMSTATE" ]; then
			MODEMMON=""
		else
			MODEMMON=""
		fi
	fi

	# Battery pct
	BATTERY_DEVICE="${BATTERY_DEVICE:-"/sys/class/power_supply/axp20x-battery"}"
	PCT="$(cat "$BATTERY_DEVICE"/capacity)"
	BATSTATUS="$(
		cut -c1 "$BATTERY_DEVICE"/status
	)"
	if [ "$BATSTATUS" = "C" ]; then
		if [ "$PCT" -lt 20 ]; then
			BATSTATUS="$PCT% "
		elif [ "$PCT" -lt 30 ]; then
			BATSTATUS="$PCT% "
		elif [ "$PCT" -lt 40 ]; then
			BATSTATUS="$PCT% "
		elif [ "$PCT" -lt 60 ]; then
			BATSTATUS="$PCT% "
		elif [ "$PCT" -lt 80 ]; then
			BATSTATUS="$PCT% "
		elif [ "$PCT" -lt 90 ]; then
			BATSTATUS="$PCT% "
		else
			BATSTATUS="$PCT% "
		fi
	else
		if [ "$PCT" -lt 10 ]; then
			BATSTATUS="$PCT% "
		elif [ "$PCT" -lt 20 ]; then
			BATSTATUS="$PCT% "
		elif [ "$PCT" -lt 30 ]; then
			BATSTATUS="$PCT% "
		elif [ "$PCT" -lt 40 ]; then
			BATSTATUS="$PCT% "
		elif [ "$PCT" -lt 50 ]; then
			BATSTATUS="$PCT% "
		elif [ "$PCT" -lt 60 ]; then
			BATSTATUS="$PCT% "
		elif [ "$PCT" -lt 70 ]; then
			BATSTATUS="$PCT% "
		elif [ "$PCT" -lt 80 ]; then
			BATSTATUS="$PCT% "
		elif [ "$PCT" -lt 90 ]; then
			BATSTATUS="$PCT% "
		else
			BATSTATUS="$PCT% "
		fi
	fi

	# Volume
	AUDIODEV="$(sxmo_audiocurrentdevice.sh)"
	AUDIOSYMBOL=$(echo "$AUDIODEV" | cut -c1)
	if [ "$AUDIOSYMBOL" = "L" ] || [ "$AUDIOSYMBOL" = "N" ]; then
		AUDIOSYMBOL="" #speakers or none, use no special symbol
	elif [ "$AUDIOSYMBOL" = "H" ]; then
		AUDIOSYMBOL=" "
	elif [ "$AUDIOSYMBOL" = "E" ]; then
		AUDIOSYMBOL=" " #earpiece
	fi
	VOL=0
	[ "$AUDIODEV" = "None" ] || VOL="$(
		amixer sget "$AUDIODEV" |
		grep -oE '([0-9]+)%' |
		tr -d ' %' |
		awk '{ s += $1; c++ } END { print s/c }'  |
		xargs printf %.0f
	)"
	if [ "$AUDIODEV" != "None" ]; then
		if [ "$VOL" -eq 0 ]; then
			VOLUMESYMBOL="ﱝ"
		elif [ "$VOL" -lt 25 ]; then
			VOLUMESYMBOL="奄"
		elif [ "$VOL" -gt 75 ]; then
			VOLUMESYMBOL="墳"
		else
			VOLUMESYMBOL="奔"
		fi
	fi
	# Time
	TIME="$(date +%R)"

	BAR="$(echo "${CALLINFO} ${MODEMMON} ${WIRELESS} ${VPN} ${AUDIOSYMBOL}${VOLUMESYMBOL} ${BATSTATUS} ${TIME}" | sed 's| \+| |g')"

	case "$(sxmo_wm.sh)" in
		sway) printf "%s\n" "$BAR";;
		dwm) xsetroot -name "$BAR";;
	esac
}

# E.g. on first boot justs to make sure the bar comes in quickly
update

while :
do
	sleep 30 & wait
	update
done
