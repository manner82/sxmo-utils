#!/usr/bin/env sh
# title="o Waydroid"

# shellcheck source=scripts/core/sxmo_common.sh
. "$(which sxmo_common.sh)"
# shellcheck source=scripts/core/sxmo_icons.sh
. "$(which sxmo_hook_icons.sh)"

set -eu

is_started(){
  pgrep >/dev/null -f "waydroid session start"
}

menu_list(){
  if is_started; then
    if test -f /tmp/waydroid.log; then
      while ! grep -q "is ready" /tmp/waydroid.log; do
        sleep 1s
      done
    fi
    pkill -f /tmp/waydroid.log || true
    cat <<.
o Session stop
o Show full ui
o Close Menu
.
    waydroid app list | sed -n "s,^Name: ,,p" | sort
  else
    cat <<.
o Session start
o Close Menu
.
  fi
}

menu(){
sel="$(menu_list | dmenu -p "Waydroid" -i)"

case "$sel" in
  *"Session start"*)
    #TODO unless already runs
    waydroid session start &>/tmp/waydroid.log &
    sxmo_terminal.sh tail -f /tmp/waydroid.log &
    ;;
  *"Session stop"*)
    waydroid session stop

    while is_started; do sleep 1s; done
    rm -f /tmp/waydroid.log
    ;;
  *"Close Menu"*)
    exit 0
    ;;
  *"Show full ui"*)
    waydroid show-full-ui
    exit 0
    ;;
  *)
    app="$(waydroid app list | sed -n "/Name: $sel/{n;s/packageName: //p;q}")"
    waydroid app launch "$app"
    exit 0
    ;;
esac
}

while true; do
  menu
done
