#!/usr/bin/env sh
# title="$icon_tmr Alarms"

# shellcheck source=scripts/core/sxmo_common.sh
. "$(which sxmo_common.sh)"
# shellcheck source=scripts/core/sxmo_icons.sh
. "$(which sxmo_hook_icons.sh)"

set -eu

# Configurable variables
ALARM_PATH="${ALARM_PATH:-${XDG_CONFIG_HOME}/sxmo/alarm.mp3}"
ALARM_VOLUME="${ALARM_VOLUME:-20}"
ALARM_AUDIOOUT="${ALARM_AUDIOOUT:-Speaker}"

if ! [ -f "$ALARM_PATH" ]; then
  ALARM_PATH=/usr/share/sxmo/ring.ogg
fi

self_path=$(realpath "$0")

# the comment around the cron entries managed by this program
# it will not edit anything else
GUARD="# sxmo-alarm entries"

# display our entries
crontab_entries() {
  crontab -l | sed -n -e "/^$GUARD - begin/,\${/^$GUARD/!p;/^$GUARD - end/q;}"
}

# display the rest of crontab (without our entries)
crontab_without_entries() {
  crontab -l | sed -e "/^$GUARD - begin/,/^$GUARD - end/d"
}

# Generate a crontab entry from a "human readable" one:
# "08:30 Mon-Fri" -> "30 8 * * 1-5"
crontab_entry_gen_time() {
  # split at spaces
  # shellcheck disable=SC2048,SC2086
  set -- $*

  # it is important to remove leading zeros otherwise it will not match the cron entry
  # ("10#" specifies that it is decimal instead of octal: by default 0 beginnings are treated so)
  hour="$((10#${1%:*}))"  # 08:05 -> 8
  min="$((10#${1#*:}))"   # 08:05 -> 5

  day="$(cronday_from_human "${2:-*}")"
  printf "%s" "${min} ${hour} * * ${day}"
}

# Create the command part of the crontab entry
crontab_entry_gen_cmd() {
  log_path="${XDG_CACHE_DIR:-~/.cache}/sxmo-alarm.log"
  printf "%s" "sxmo_rtcwake.sh \"${self_path}\" ring &>>${log_path}"
}

cronday_to_human() {
  if [ "$1" = "*" ]; then
    # every day -> this is the default for the user
    true
  else
    printf "%s" "$1" | sed -e 's,1,Mon,g' -e 's,2,Tue,g' -e 's,3,Wed,g' -e 's,4,Thu,g' \
        -e 's,5,Fri,g' -e 's,6,Sat,g' -e 's,[07],Sun,g'
  fi
}

cronday_from_human() {
  if [ "${1:-}" = "" ]; then
    printf "%s" "*"
  else
    printf "%s" "$1" | sed -e 's,Mon,1,g' -e 's,Tue,2,g' -e 's,Wed,3,g' -e 's,Thu,4,g' \
        -e 's,Fri,5,g' -e 's,Sat,6,g' -e 's,Sun,0,g'
  fi
}

crontab_to_human() {
  while read -r line; do
    # skip empty lines
    [ "$line" != "" ] || continue

    # break string at whitespaces
    set -f
    # shellcheck disable=SC2086
    set -- $line
    set +f
    disabled="[x]"
    if [ "${1}" = "#" ]; then
      disabled="[ ]"
      shift
    fi
    hour="${2}"
    min="${1}"
    day="$(cronday_to_human "${5}")"
    printf "%s %02d:%02d %s\n" "${disabled}" "${hour}" "${min}" "${day}"
  done
}

list_cron() {
  if [ "${1:-}" = "-v" ]; then
    crontab_without_entries
  else
    crontab_entries
  fi
}

list() {
  command="${1:-}"
  shift 2>/dev/null || true
  case "${command}" in
    "cron")
      list_cron "$@"
      ;;
    ""|"human")
      list_cron | crontab_to_human
      ;;
    *)
      printf >&2 "Unknown argument to list: '%s'\n" "$command"
      return 1
      ;;
  esac
}

ring() {
  sxmo_audio.sh device set "${ALARM_AUDIOOUT}"
  sxmo_audio.sh vol set "${ALARM_VOLUME}"
  if sxmo_audio.sh vol ismuted; then
    sxmo_audio.sh vol togglemute
  fi
  # a notification which is able to stop the alarm
  sxmo_notificationwrite.sh \
          random \
          "pkill -f \"$ALARM_PATH\"" \
          none \
          "Alarm running"

  mpv --quiet --no-video --no-resume-playback --loop-file=inf "$ALARM_PATH"
}

# Apply a regexp on current crontab entries.
# Used by add / toggle / del.
crontab_edit() {
  modification="$1"
  append="${2:-}"
  {
    crontab_without_entries
    printf "%s - begin\n" "$GUARD"
    crontab_entries | sed "$modification"
    [ "$append" = "" ] || printf "%s\n" "$append"
    printf "%s - end\n" "$GUARD"
  } | crontab -
}

add() {
  entry="$(crontab_entry_gen_time "$@")"
  printf "Adding '%s'\n" "$entry"
  entry="${entry} $(crontab_entry_gen_cmd)"
  crontab_edit "" "${entry}"
}

del() {
  entry="$(crontab_entry_gen_time "$@" | sed 's,\*,\\\*,g')"
  printf "Removing: %s\n" "${entry}"
  crontab_edit "/^[# ]*${entry}/d"
}

toggle() {
  entry="$(crontab_entry_gen_time "$@" | sed 's,\*,\\\*,g')"
  printf "Toggle: %s\n" "${entry}"
  crontab_edit "/^${entry}/{s/^#* */# /;b;};/^# *${entry}/{s/^#* *//;b;}"
}

menu_edit_alarm() {
  toggle_menu="$icon_pau Disable"
  case "$*" in
    "[ ]"*)
      toggle_menu="$icon_ffw Enable"
      ;;
  esac

  alarm="$(printf "%s" "$*" | cut -b 5-)"
  picked="$(
    dmenu -p "Edit $alarm" <<EOF
$toggle_menu
$icon_del Delete
$icon_cls Cancel
EOF
)"
  case "$picked" in
    *Disable|*Enable)
      toggle "$alarm"
      ;;
    *Delete)
      del "$alarm"
      ;;
    *Cancel)
      return 1
      ;;
  esac
}

menu_select_numbers() {
  # Select a number from a range
  picked=
  min="$1"
  step="$2"
  max="$3"
  prompt="$4"

  while true; do
    picked="$(seq "$min" "$step" "$max" | sxmo_dmenu_with_kb.sh -p "$prompt" -i)"

    if [ "$picked" = "" ]; then
      return 1  # cancel
    fi

    if [ "$picked" -ge "$min" ] && [ "$picked" -le "$max" ]; then
      printf "%s" "$picked"
      return 0
    fi
  done
}

menu_select_days__itemlist() {
  enabled_string="$1"

  # $2 is a list separated by whitespaces
  # shellcheck disable=SC2086
  for day in $2; do
    printf "%s %s\n" "${enabled_string}" "${day}"
  done
}

menu_select_days__resultlist() {
  # Transform the itemlist ("[x] Monday...") into a result list
  # which only contains the selected items separated by commas, like:
  #   Mon,Tue,Wed
  sed -n -e 's/\[x\] \(...\).*/\1/p' | sed -e ':0;N;s/\n/,/;b0'
}

menu_select_days__result_simplify() {
  # The purpose would be to make lists smaller to fit into the menu.
  # Eg. transform "Mon,Tue,Wed,Fri" to "Mon-Wed,Fri"
  # The idea is to connect sequential numbers by a minus, and
  # remove the inner items: -> Mon-Tue-Wed,Fri -> Mon-Wed,Fri
  sed -e 's/Mon,Tue/Mon-Tue/' \
      -e 's/Tue,Wed/Tue-Wed/' \
      -e 's/Wed,Thu/Wed-Thu/' \
      -e 's/Thu,Fri/Thu-Fri/' \
      -e 's/Fri,Sat/Fri-Sat/' \
      -e 's/Sat,Sun/Sat-Sun/' \
      -e 's/\(...-\)\(...-\)*/\1/g'
}

menu_select_days() {
  weekdays="Monday Tuesday Wednesday Thursday Friday"
  weekend="Saturday Sunday"
  days="$weekdays $weekend"
  dayitems="$(menu_select_days__itemlist "[x]" "$days")"

  while true; do
    picked="$({
      printf "%s\n" "$dayitems"
      cat <<EOF
$icon_itm Select None
$icon_itm Select All
$icon_itm Select Weekdays
$icon_itm Select Weekend
$icon_ret Ok
$icon_cls Cancel
EOF
    } | dmenu -p "Select days" -i)"

    case "$picked" in
    *All)
        dayitems="$(menu_select_days__itemlist "[x]" "$days")"
        ;;
    *None)
        dayitems="$(menu_select_days__itemlist "[ ]" "$days")"
        ;;
    *Weekend)
        dayitems="$(menu_select_days__itemlist "[ ]" "$weekdays";
                    menu_select_days__itemlist "[x]" "$weekend")"
        ;;
    *Weekdays)
        dayitems="$(menu_select_days__itemlist "[x]" "$weekdays";
                    menu_select_days__itemlist "[ ]" "$weekend")"
        ;;
    *Ok)
        printf "%s" "$dayitems" | menu_select_days__resultlist | menu_select_days__result_simplify
        return 0
        ;;
    *Cancel|"")
      return 1
      ;;
    *)
      # toggle a day
      day="$(printf "%s" "${picked}" | cut -b 5-)"
      printf >&2 "Toggle day: '%s'\n" "$day"

      # we replace "[ ] $day" -> "[x] $day" or the opposite
      dayitems="$(printf "%s\n" "$dayitems" |
        sed -n "/\[ \] $day/{s/\[ \]/\[x\]/p;b;};/\[x\] $day/{s/\[x\]/\[ \]/p;b;};p")"
      ;;
    esac
  done
}

menu_add_alarm() {
  # some defaults for a new entry:
  hour=6
  min=0
  day="Mon-Sun"

  while true; do
    picked="$(
      dmenu -p "Add alarm" -i <<EOF
$icon_clk Hour: $hour
$icon_clk Minute: $min
$icon_clk Days: $day
$icon_pls Add
$icon_cls Cancel
EOF
    )"
    case "$picked" in
      *Hour:*)
        new_hour="$(menu_select_numbers 0 1 23 "Select hour")"
        if [ "${new_hour}" != "" ]; then
          hour="${new_hour}"
        fi
        ;;
      *Minute:*)
        new_min="$(menu_select_numbers 0 5 59 "Select minute")"
        if [ "${new_min}" != "" ]; then
          min="${new_min}"
        fi
        ;;
      *Days:*)
        new_day="$(menu_select_days)"
        if [ "${new_day}" != "" ]; then
          day="${new_day}"
        fi
        ;;
      *Add)
        add "$hour:$min" "$day"
        return $?
        ;;
      ""|*Cancel)
        return 1
        ;;
    esac
  done
}

menu() {
  while true; do
    picked="$({
      list
      cat <<EOF
$icon_pls Add New
$icon_mnu System Menu
$icon_cls Close Menu
EOF
    } | dmenu -p "Alarms" -i)"
    case "$picked" in
      *"System Menu")
        sxmo_appmenu.sh sys
        return 0
        ;;
      ""|*"Close Menu")
        return 0
        ;;
      *"Add New")
        menu_add_alarm || continue
        ;;
      *)
        menu_edit_alarm "$picked" || continue
        ;;
    esac
  done
}

help() {
  cat <<EOF
$(basename "$0") [help|ring|list|add|del|toggle|menu]

Handle alarms through user cron entries.
The cron entries are managed between comment guards, other
entries will not get touched.

To display the menu, just run this command without arguments.
The subcommands are mainly for debugging. Choose from:

help     Get this help

ring     Start ringing immediately.

list     List the entries of the alarms in human readable format.
         Specify the following subcommands to have a different list:
         
         list cron      Lists the alarm entries in cron format.
         list cron -v   List the non-alarm related cron entries.

add      Add a new alarm. The entry should be in "human readable" format,
         eg. "06:30 Tue,Thu-Sun"

del      Delete an existing alarm. The entry should be in "human readable"
         format.

toggle   Enable/disable an existing alarm. The entry should be in "human
         readable" format.

menu     Displays the menu. (This is the default behavour.)
EOF
}

command="${1:-}"
shift 2>/dev/null || true
case "$command" in
  ring)
    ring
    ;;
  help|"-h"|"--help")
    help
    ;;
  list)
    list "$@"
    ;;
  add)
    add "$@"
    ;;
  del)
    del "$@"
    ;;
  toggle)
    toggle "$@"
    ;;
  "menu"|"")
    menu
    ;;
  *)
    printf >&2 "Unknown command '%s'. See --help\n" "$command"
    exit 1
    ;;
esac
