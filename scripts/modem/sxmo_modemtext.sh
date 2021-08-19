#!/usr/bin/env sh

# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. "$(dirname "$0")/sxmo_common.sh"

err() {
	echo "$1">&2
	echo "$1" | dmenu
	kill $$
}

choosenumbermenu() {
	# Prompt for number
	NUMBER="$(
		printf %b "\n$icon_cls Cancel\n$icon_grp More contacts\n$(sxmo_contacts.sh | grep -E "^\+?[0-9]+:")" |
		awk NF |
		sxmo_dmenu_with_kb.sh -p "Number" -i |
		cut -d: -f1 |
		tr -d -- '- '
	)"
	if echo "$NUMBER" | grep -q "Morecontacts"; then
		NUMBER="$( #joined words without space is not a bug
			printf %b "\nCancel\n$(sxmo_contacts.sh --all)" |
				grep . |
				sxmo_dmenu_with_kb.sh -p "Number" -i |
				cut -d: -f1 |
				tr -d -- '- '
		)"
	fi

	if echo "$NUMBER" | grep -q "Cancel"; then
		exit 1
	elif ! echo "$NUMBER" | grep -qE '^[+0-9]+$'; then
		notify-send "That doesn't seem like a valid number"
	else
		echo "$NUMBER"
	fi
}

sendtextmenu() {
	if [ -n "$1" ]; then
		NUMBER="$1"
	else
		NUMBER="$(choosenumbermenu)"
	fi

	DRAFT="$LOGDIR/$NUMBER/draft.txt"
	if [ ! -f "$DRAFT" ]; then
		mkdir -p "$(dirname "$DRAFT")"
		echo 'Enter text message here' > "$DRAFT"
	fi

	sxmo_terminal.sh "$EDITOR" "$DRAFT"

	while true
	do
		CONFIRM="$(
			printf %b "$icon_edt Edit\n$icon_snd Send\n$icon_cls Cancel" |
			dmenu -i -p "Confirm"
		)" || exit
		if echo "$CONFIRM" | grep -q "Send"; then
			(sxmo_modemsendsms.sh "$NUMBER" - < "$DRAFT") && \
			rm "$DRAFT" && \
			echo "Sent text to $NUMBER">&2 && exit 0
		elif echo "$CONFIRM" | grep -q "Edit"; then
			sendtextmenu "$NUMBER"
		elif echo "$CONFIRM" | grep -q "Cancel"; then
			exit 1
		fi
	done
}

tailtextlog() {
	NUMBER="$1"
	CONTACTNAME="$(sxmo_contacts.sh | grep "^$NUMBER" | cut -d' ' -f2-)"
	[ "Unknown Number" = "$CONTACTNAME" ] && CONTACTNAME="$CONTACTNAME ($NUMBER)"

	TERMNAME="$NUMBER SMS" sxmo_terminal.sh sh -c "tail -n9999 -f \"$LOGDIR/$NUMBER/sms.txt\" | sed \"s|$NUMBER|$CONTACTNAME|g\""
}

readtextmenu() {
	# E.g. only display logfiles for directories that exist and join w contact name
	ENTRIES="$(
	printf %b "$icon_cls Close Menu\n$icon_edt Send a Text\n";
		sxmo_contacts.sh --texted | xargs -IL echo "L logfile"
	)"
	PICKED="$(printf %b "$ENTRIES" | dmenu -p Texts -i)" || exit

	if echo "$PICKED" | grep "Close Menu"; then
		exit 1
	elif echo "$PICKED" | grep "Send a Text"; then
		sendtextmenu
	else
		tailtextlog "$(echo "$PICKED" | cut -d: -f1)"
	fi
}

if [ "2" != "$#" ]; then
	readtextmenu
else
	"$@"
fi
