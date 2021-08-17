#!/usr/bin/env sh

change() {
	echo "Changing timezone to $1"
	sudo setup-timezone -z "$1"
	sxmo_statusbarupdate.sh
	echo Timezone changed ok
	read -r
}

menu() {
	T="$(
		find /usr/share/zoneinfo -type f |
		sed  's#^/usr/share/zoneinfo/##g' |
		sort |
		sxmo_dmenu_with_kb.sh -p Timezone -i
	)"
	sxmo_terminal.sh "$0" change "$T"
}

if [ $# -gt 0 ]; then
	"$@"
else
	menu
fi
