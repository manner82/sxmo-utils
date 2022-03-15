#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors
trap "gracefulexit" INT TERM

# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. "$(dirname "$0")/sxmo_common.sh"

stderr() {
	sxmo_log "$*"
}

gracefulexit() {
	stderr "gracefully exiting (on signal or after error)"
	sxmo_daemons.sh stop modem_monitor_voice
	sxmo_daemons.sh stop modem_monitor_text
	sxmo_daemons.sh stop modem_monitor_finished_voice
	sxmo_daemons.sh stop modem_monitor_state_change
	sxmo_daemons.sh stop modem_monitor_check_daemons
	sxmo_daemons.sh stop modem_monitor_mms
	sxmo_daemons.sh stop modem_monitor_vvm
	exit
}

# see networkmananger documentation for these state names
statenumtoname() {
	case "$1" in
		"int32 -1") printf "failed"
			;;
		"int32 0") printf "unknown"
			;;
		"int32 1") printf "initializing"
			;;
		"int32 2") printf "locked"
			;;
		"int32 3") printf "disabled"
			;;
		"int32 4") printf "disabling"
			;;
		"int32 5") printf "enabling"
			;;
		"int32 6") printf "enabled"
			;;
		"int32 7") printf "searching"
			;;
		"int32 8") printf "registered"
			;;
		"int32 9") printf "disconnecting"
			;;
		"int32 10") printf "connecting"
			;;
		"int32 11") printf "connected"
			;;
		*) printf "ERROR"
			;;
	esac
}

mainloop() {
	# Display the icon
	sxmo_hook_statusbar.sh modem_monitor

	PIDS=""

	# get initial modem state
	(
		while ! newstate="$(mmcli -m any -K | grep "^modem.generic.state " | cut -d':' -f2 | sed 's/^ //')" || [ -z "$newstate" ]; do
			sleep 5
		done

		# fake oldstate (boot) and reason (0)
		sxmo_hook_modem.sh "boot" "$newstate" "0"
		sxmo_hook_statusbar.sh modem
	) &
	PIDS="$PIDS $!"

	# Monitor for incoming calls
	sxmo_daemons.sh start modem_monitor_voice \
		dbus-monitor --system "interface='org.freedesktop.ModemManager1.Modem.Voice',type='signal',member='CallAdded'" | \
		while read -r line; do
			echo "$line" | grep -qE "^signal" && sxmo_modem.sh checkforincomingcalls
		done &
	PIDS="$PIDS $!"

	# Monitor for incoming texts
	sxmo_daemons.sh start modem_monitor_text \
		dbus-monitor --system "interface='org.freedesktop.ModemManager1.Modem.Messaging',type='signal',member='Added'" | \
		while read -r line; do
			echo "$line" | grep -qE "^signal" && sxmo_modem.sh checkfornewtexts
		done &
	PIDS="$PIDS $!"

	# Monitor for finished calls
	sxmo_daemons.sh start modem_monitor_finished_voice \
		dbus-monitor --system "interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',arg0='org.freedesktop.ModemManager1.Call'" | \
		while read -r line; do
			echo "$line" | grep -qE "^signal" && sxmo_modem.sh checkforfinishedcalls
		done &
	PIDS="$PIDS $!"

	# Monitor for modem state change
	sxmo_daemons.sh start modem_monitor_state_change \
		dbus-monitor --system "interface='org.freedesktop.ModemManager1.Modem',type='signal',member='StateChanged'" | \
		while read -r line; do
			if echo "$line" | grep -qE "^signal.*StateChanged"; then
				read -r oldstate
				read -r newstate
				read -r reason
				sxmo_hook_modem.sh "$(statenumtoname "$oldstate")" \
					"$(statenumtoname "$newstate")" \
					"$(echo "$reason" | sed 's/uint32 //')"
				sxmo_hook_statusbar.sh modem
			fi
		done &
	PIDS="$PIDS $!"

	if [ -f "${SXMO_MMS_BASE_DIR:-"$HOME"/.mms/modemmanager}/mms" ]; then
		# monitor for mms
		sxmo_daemons.sh start modem_monitor_mms \
			dbus-monitor "interface='org.ofono.mms.Service',type='signal',member='MessageAdded'" | \
			while read -r line; do
				if echo "$line" | grep -q '^object path'; then
					MESSAGE_PATH="$(echo "$line" | cut -d\" -f2)"
				fi
				if echo "$line" | grep -q 'string "received"'; then
					sxmo_mms.sh processmms "$MESSAGE_PATH" "Received"
				fi
			done &
		PIDS="$PIDS $!"
	fi

	if [ -f "${SXMO_VVM_BASE_DIR:-"$HOME"/.vvm/modemmanager}/vvm" ]; then
		# monitor for vvm (Visual Voice Mail)
		VVM_START=0
		sxmo_daemons.sh start modem_monitor_vvm \
			dbus-monitor "interface='org.kop316.vvm.Service',type='signal',member='MessageAdded'" | \
			while read -r line; do
				if echo "$line" | grep -q '^object path'; then
					VVM_ID="$(echo "$line" | cut -d\" -f2 | rev | cut -d'/' -f1 | rev)"
					VVM_START=1
				fi

				if echo "$line" | grep -q '^]'; then
					VVM_START=0
					sxmo_vvm.sh processvvm "$VVM_DATE" "$VVM_SENDER" "$VVM_ID" "$VVM_ATTACHMENT"
				fi

				if [ "$VVM_START" -eq 1 ]; then
					if echo "$line" | grep -q '^string "Date"'; then
						read -r line
						VVM_DATE="$(echo "$line" | cut -d\" -f2)"
					elif echo "$line" | grep -q '^string "Sender"'; then
						read -r line
						VVM_SENDER="$(echo "$line" | cut -d\" -f2)"
					elif echo "$line" | grep -q '^string "Attachments"'; then
						read -r line
						VVM_ATTACHMENT="$(echo "$line" | cut -d\" -f2)"
					fi
				fi
			done &
		PIDS="$PIDS $!"
	fi

	for PID in $PIDS; do
		wait "$PID"
	done
}

# new session, clean up all phone related files
rm -f "$XDG_RUNTIME_DIR"/*.monitoredcall 2>/dev/null
rm -f "$XDG_RUNTIME_DIR"/*.mutedring 2>/dev/null
rm -f "$XDG_RUNTIME_DIR"/*.hangedupcall 2>/dev/null
rm -f "$XDG_RUNTIME_DIR"/*.discardedcall 2>/dev/null
rm -f "$XDG_RUNTIME_DIR"/*.initiatedcall 2>/dev/null
rm -f "$XDG_RUNTIME_DIR"/*.pickedupcall 2>/dev/null
rm -f "$XDG_RUNTIME_DIR"/sxmo.ring.pid 2>/dev/null
rm -f "$SXMO_NOTIFDIR"/incomingcall* 2>/dev/null
mainloop
