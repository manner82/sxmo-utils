#!/bin/sh

# shellcheck source=scripts/core/sxmo_common.sh
. "$(dirname "$0")/sxmo_common.sh"

set -e

MMSCONFIG="$HOME"/.mms/modemmanager/mms

defaultconfig() {
	cat <<EOF
[Modem Manager]
CarrierMMSC=http://wholesale.mmsmvno.com/mms/wapenc
MMS_APN=Ultra
CarrierMMSProxy=NULL
DefaultModemNumber=NULL
AutoProcessOnConnection=true
AutoProcessSMSWAP=true

[Settings]
UseDeliveryReports=false
AutoCreateSMIL=false
ForceCAres=false
TotalMaxAttachmentSize=1100000
MaxAttachments=25
EOF
}

confirm() {
	printf "No\nYes\n" | dmenu -p "Are you sure ?" | grep -q "^Yes$"
}

valuemenu() {
	printf %s "$2" | dmenu -p "$1"
}

editfile() {
	FILE="$1"

	while : ; do
		CHOICE="$(grep "=" < "$FILE" |
			xargs -0 printf "$icon_ret Close Menu\n$icon_rol Default Config\n%b" |
			dmenu -p "MMS Config"
		)"

		case "$CHOICE" in
			"$icon_ret Close Menu")
				return
				;;
			"$icon_rol Default Config")
				confirm && defaultconfig > "$FILE"
				continue
				;;
		esac

		KEY="$(printf %s "$CHOICE" | cut -d= -f1)"
		VALUE="$(printf %s "$CHOICE" | cut -d= -f2-)"
		NEWVALUE="$(valuemenu "$KEY" "$VALUE")"

		sed -i "$FILE" -e "s|^$CHOICE$|$KEY=$NEWVALUE|"
	done
}

newfile() {
	tmp="$(mktemp)"
	defaultfile > "$tmp"
	editfile "$tmp"
	mv "$tmp" "$MMSCONFIG"
}

if pgrep mmsdtng > /dev/null; then
	pkill mmsdtng
fi

finish() {
	setsid -f mmsdtng
}
trap 'finish' EXIT

if [ -f "$HOME"/.mms/modemmanager/mms ]; then
	editfile "$HOME"/.mms/modemmanager/mms
else
	newfile
fi
