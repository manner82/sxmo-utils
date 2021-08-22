#!/usr/bin/env sh
trap "gracefulexit" INT TERM

# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. "$(dirname "$0")/sxmo_common.sh"

err() {
	echo "sxmo_modemmonitor: Error: $1">&2
	notify-send "$1"
	gracefulexit
}

gracefulexit() {
	rm "$MODEMSTATEFILE"
	sxmo_statusbarupdate.sh
	sleep 1
	echo "sxmo_modemmonitor: gracefully exiting (on signal or after error)">&2
	kill -9 0
}

modem_n() {
	TRIES=0
	while [ "$TRIES" -lt 10 ]; do
		MODEMS="$(mmcli -L)"
		if ! echo "$MODEMS" | grep -oE 'Modem\/([0-9]+)' > /dev/null; then
			TRIES=$((TRIES+1))
			echo "sxmo_modemmonitor: modem not found, waiting for modem... (try #$TRIES)">&2
			sleep 1
		else
			echo "$MODEMS" | grep -oE 'Modem\/([0-9]+)' | cut -d'/' -f2
			return
		fi
	done
	err "Couldn't find modem - is your modem enabled? Disabling modem monitor"
}

cleanupnumber() {
	if pn valid "$1"; then
		echo "$1"
		return
	fi

	REFORMATTED="$(pn find ${DEFAULT_COUNTRY:+-c "$DEFAULT_COUNTRY"} "$1")"
	if [ -n "$REFORMATTED" ]; then
		echo "$REFORMATTED"
		return
	fi

	echo "$1"
}

lookupnumberfromcallid() {
	VOICECALLID=$1
	mmcli -m "$(modem_n)" --voice-list-calls -o "$VOICECALLID" -K |
		grep call.properties.number |
		cut -d ':' -f 2 |
		tr -d ' '
}

lookupcontactname() {
	if [ "$1" = "--" ]; then
		echo "Unknown number"
	else
		CONTACT=$(sxmo_contacts.sh --all |
			grep "^$1:" |
			cut -d':' -f 2 |
			sed 's/^[ \t]*//;s/[ \t]*$//' #strip leading/trailing whitespace
		)
		if [ -n "$CONTACT" ]; then
			echo "$CONTACT"
		else
			echo "Unknown ($1)"
		fi
	fi
}

checkforfinishedcalls() {
	#find all finished calls
	for FINISHEDCALLID in $(
		mmcli -m "$(modem_n)" --voice-list-calls |
		grep terminated |
		grep -oE "Call\/[0-9]+" |
		cut -d'/' -f2
	); do
		FINISHEDNUMBER="$(lookupnumberfromcallid "$FINISHEDCALLID")"
		FINISHEDNUMBER="$(cleanupnumber "$FINISHEDNUMBER")"
		mmcli -m "$(modem_n)" --voice-delete-call "$FINISHEDCALLID"
		rm -f "$NOTIFDIR/incomingcall_${FINISHEDCALLID}_notification"* #there may be multiple actionable notification for one call

		rm -f "$CACHEDIR/${FINISHEDCALLID}.monitoredcall"

		TIME="$(date --iso-8601=seconds)"
		mkdir -p "$LOGDIR"
		if [ -f "$CACHEDIR/${FINISHEDCALLID}.discardedcall" ]; then
			#this call was discarded
			echo "sxmo_modemmonitor: Discarded call from $FINISHEDNUMBER">&2
			printf %b "$TIME\tcall_discarded\t$FINISHEDNUMBER\n" >> "$LOGDIR/modemlog.tsv"
		elif [ -f "$CACHEDIR/${FINISHEDCALLID}.pickedupcall" ]; then
			#this call was picked up
			pkill -f sxmo_modemcall.sh
			echo "sxmo_modemmonitor: Finished call from $FINISHEDNUMBER">&2
			printf %b "$TIME\tcall_finished\t$FINISHEDNUMBER\n" >> "$LOGDIR/modemlog.tsv"
		elif [ -f "$CACHEDIR/${FINISHEDCALLID}.hangedupcall" ]; then
			#this call was hung up by the user
			echo "sxmo_modemmonitor: Finished call from $FINISHEDNUMBER">&2
			printf %b "$TIME\tcall_finished\t$FINISHEDNUMBER\n" >> "$LOGDIR/modemlog.tsv"
		elif [ -f "$CACHEDIR/${FINISHEDCALLID}.initiatedcall" ]; then
			#this call was hung up by the contact
			pkill -f sxmo_modemcall.sh
			echo "sxmo_modemmonitor: Finished call from $FINISHEDNUMBER">&2
			printf %b "$TIME\tcall_finished\t$FINISHEDNUMBER\n" >> "$LOGDIR/modemlog.tsv"
		elif [ -f "$CACHEDIR/${FINISHEDCALLID}.mutedring" ]; then
			#this ring was muted up
			echo "sxmo_modemmonitor: Muted ring from $FINISHEDNUMBER">&2
			printf %b "$TIME\tring_muted\t$FINISHEDNUMBER\n" >> "$LOGDIR/modemlog.tsv"
		else
			#this is a missed call
			# Add a notification for every missed call
			pkill -f sxmo_modemcall.sh
			echo "sxmo_modemmonitor: Missed call from $FINISHEDNUMBER">&2
			printf %b "$TIME\tcall_missed\t$FINISHEDNUMBER\n" >> "$LOGDIR/modemlog.tsv"

			echo "sxmo_modemmonitor: Invoking missed call hook (async)">&2
			sxmo_hooks.sh missed_call "$CONTACTNAME" &

			CONTACT="$(lookupcontactname "$FINISHEDNUMBER")"
			sxmo_notificationwrite.sh \
				random \
				"st -f Terminus-20 -e sh -c \"echo 'Missed call from $CONTACT at $(date)' && read\"" \
				none \
				"Missed call - $CONTACT"

			if grep -q modem "$UNSUSPENDREASONFILE" && grep -q crust "$CACHEDIR/${FINISHEDCALLID}.laststate"; then
				sleep 5 # maybe user just is too late
				if [ "$(sxmo_screenlock.sh getCurState)" != "unlock" ]; then
					sxmo_screenlock.sh crust
				fi
			fi
		fi
	done
}

checkforincomingcalls() {
	VOICECALLID="$(
		mmcli -m "$(modem_n)" --voice-list-calls -a |
		grep -Eo '[0-9]+ incoming \(ringing-in\)' |
		grep -Eo '[0-9]+'
	)"
	[ -z "$VOICECALLID" ] && return

	[ -f "$CACHEDIR/${VOICECALLID}.monitoredcall" ] && return # prevent multiple rings
	find "$CACHEDIR" -name "$VOICECALLID.*" -delete # we cleanup all dangling event files
	touch "$CACHEDIR/${VOICECALLID}.monitoredcall" #this signals that we handled the call

	cat "$LASTSTATE" > "$CACHEDIR/${VOICECALLID}.laststate"

	# Determine the incoming phone number
	echo "sxmo_modemmonitor: Incoming Call:">&2
	INCOMINGNUMBER=$(lookupnumberfromcallid "$VOICECALLID")
	INCOMINGNUMBER="$(cleanupnumber "$INCOMINGNUMBER")"
	CONTACTNAME=$(lookupcontactname "$INCOMINGNUMBER")

	echo "sxmo_modemmonitor: Invoking ring hook (async)">&2
	sxmo_hooks.sh ring "$CONTACTNAME" &

	TIME="$(date --iso-8601=seconds)"
	mkdir -p "$LOGDIR"
	printf %b "$TIME\tcall_ring\t$INCOMINGNUMBER\n" >> "$LOGDIR/modemlog.tsv"

	sxmo_notificationwrite.sh \
		"$NOTIFDIR/incomingcall_${VOICECALLID}_notification" \
		"sxmo_modemcall.sh incomingcallmenu '$VOICECALLID'" \
		none \
		"Incoming Call - $CONTACTNAME" &
	sxmo_modemcall.sh incomingcallmenu "$VOICECALLID" &

	echo "sxmo_modemmonitor: Call from number: $INCOMINGNUMBER (VOICECALLID: $VOICECALLID)">&2
}

checkfornewtexts() {
	TEXTIDS="$(
		mmcli -m "$(modem_n)" --messaging-list-sms |
		grep -Eo '/SMS/[0-9]+ \(received\)' |
		grep -Eo '[0-9]+'
	)"
	echo "$TEXTIDS" | grep -v . && return

	# Loop each textid received and read out the data into appropriate logfile
	for TEXTID in $TEXTIDS; do
		TEXTDATA="$(mmcli -m "$(modem_n)" -s "$TEXTID" -K)"
		TEXT="$(echo "$TEXTDATA" | grep sms.content.text | sed -E 's/^sms\.content\.text\s+:\s+//')"
		NUM="$(
			echo "$TEXTDATA" |
			grep sms.content.number |
			sed -E 's/^sms\.content\.number\s+:\s+//'
		)"
		NUM="$(cleanupnumber "$NUM")"
		TIME="$(echo "$TEXTDATA" | grep sms.properties.timestamp | sed -E 's/^sms\.properties\.timestamp\s+:\s+//')"

		mkdir -p "$LOGDIR/$NUM"
		echo "sxmo_modemmonitor: Text from number: $NUM (TEXTID: $TEXTID)">&2
		printf %b "Received from $NUM at $TIME:\n$TEXT\n\n" >> "$LOGDIR/$NUM/sms.txt"
		printf %b "$TIME\trecv_txt\t$NUM\t${#TEXT} chars\n" >> "$LOGDIR/modemlog.tsv"
		mmcli -m "$(modem_n)" --messaging-delete-sms="$TEXTID"
		CONTACTNAME=$(lookupcontactname "$NUM")

		sxmo_notificationwrite.sh \
			random \
			"sxmo_modemtext.sh tailtextlog '$NUM'" \
			"$LOGDIR/$NUM/sms.txt" \
			"Message - $CONTACTNAME: $TEXT"

		sxmo_hooks.sh sms "$CONTACTNAME" "$TEXT"
	done

	if grep -q modem "$UNSUSPENDREASONFILE" && grep -q crust "$LASTSTATE"; then
		sleep 5 # maybe user just is too late
		if [ "$(sxmo_screenlock.sh getCurState)" != "unlock" ]; then
			sxmo_screenlock.sh crust
		fi
	fi
}

initialmodemstatus() {
	touch "$MODEMSTATEFILE"
	state=$(mmcli -m "$(modem_n)")
	if echo "$state" | grep -q -E "^.*state:.*connected.*$"; then
		echo connected > "$MODEMSTATEFILE"
	elif echo "$state" | grep -q -E "^.*state:.*registered.*$"; then
		echo registered > "$MODEMSTATEFILE"
	elif echo "$state" | grep -q -E "^.*state:.*locked.*$"; then
		echo locked > "$MODEMSTATEFILE"
		pidof unlocksim || sxmo_hooks.sh unlocksim &
	else
		echo unknown > "$MODEMSTATEFILE"
	fi
}

mainloop() {
	#these may be premature and return nothing yet (because modem/sim might not be ready yet)
	checkforfinishedcalls
	checkforincomingcalls
	checkfornewtexts


	# Monitor for incoming calls
	dbus-monitor --system "interface='org.freedesktop.ModemManager1.Modem.Voice',type='signal',member='CallAdded'" | \
		while read -r line; do
			echo "$line" | grep -E "^signal" && checkforincomingcalls
		done &

	# Monitor for incoming texts
	dbus-monitor --system "interface='org.freedesktop.ModemManager1.Modem.Messaging',type='signal',member='Added'" | \
		while read -r line; do
			echo "$line" | grep -E "^signal" && checkfornewtexts
		done &

	# Monitor for finished calls
	dbus-monitor --system "interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',arg0='org.freedesktop.ModemManager1.Call'" | \
		while read -r line; do
			echo "$line" | grep -E "^signal" && checkforfinishedcalls
		done &

	#Monitor for modem state changes
	# arg1 holds the new state: MM_MODEM_STATE_FAILED = -1, MM_MODEM_STATE_UNKNOWN = 0, ... MM_MODEM_STATE_REGISTERED=8, MM_MODEM_STATE_CONNECTED = 11
	initialmodemstatus
	sxmo_statusbarupdate.sh

	dbus-monitor --system "interface='org.freedesktop.ModemManager1.Modem',type='signal',member='StateChanged'" | \
		while read -r line; do
			if echo "$line" | grep -E "^signal.*StateChanged"; then
				# shellcheck disable=SC2034
				read -r oldstate #unused but we need to read past it
				read -r newstate
				if echo "$newstate" | grep "int32 2"; then
					echo locked > "$MODEMSTATEFILE"
					pidof unlocksim || sxmo_hooks.sh unlocksim &
				elif echo "$newstate" | grep "int32 8"; then
					echo registered > "$MODEMSTATEFILE"
					#if there is a PIN entry menu open, kill it:
					# shellcheck disable=SC2009
					ps aux | grep dmenu | grep PIN | gawk '{ print $1 }' | xargs kill
					checkforfinishedcalls
					checkforincomingcalls
					checkfornewtexts
				elif echo "$newstate" | grep "int32 11"; then
					echo connected > "$MODEMSTATEFILE"
					#3G/2G/4G available
				elif echo "$newstate" | grep "int32 -1"; then
					echo failed > "$MODEMSTATEFILE"
				elif echo "$newstate" | grep "int32 3"; then
					echo disabled > "$MODEMSTATEFILE"
				else
					echo unknown > "$MODEMSTATEFILE"
				fi
				sxmo_statusbarupdate.sh
			fi
		done &

	(   #check whether the modem is still alive every minute, reset the modem if not
		while :
		do
			sleep 60
			TRIES=0
			while [ "$TRIES" -lt 10 ]; do
				MODEMS="$(mmcli -L)"
				if echo "$MODEMS" | grep -oE 'Modem\/([0-9]+)' > /dev/null; then
					break
				elif grep -q rtc "$UNSUSPENDREASONFILE"; then
					#don't bother checking in rtc-wake situations
					TRIES=0
					break
				else
					TRIES=$((TRIES+1))
					echo "sxmo_modemmonitor: modem not found, waiting for modem... (try #$TRIES)">&2
					sleep 3
					if [ "$TRIES" -eq 10 ]; then
						echo failed > "$MODEMSTATEFILE"
						echo "sxmo_modemmonitor: forcing modem restart">&2
						sxmo_modemmonitortoggle.sh restart #will kill the modemmonitor too
						break
					fi
				fi
			done
		done
	) &

	wait
	wait
	wait
	wait
	wait

	rm "$MODEMSTATEFILE" 2>/dev/null
	sxmo_statusbarupdate.sh
}


echo "sxmo_modemmonitor: starting -- $(date)" >&2
rm -f "$CACHEDIR"/*.pickedupcall 2>/dev/null #new session, forget all calls we picked up previously
mainloop
echo "sxmo_modemmonitor: exiting -- $(date)" >&2
