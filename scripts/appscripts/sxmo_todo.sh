#!/usr/bin/env sh

# shellcheck source=scripts/core/sxmo_common.sh
. "$(which sxmo_common.sh)"
# shellcheck source=scripts/core/sxmo_icons.sh
. "$(which sxmo_hook_icons.sh)"

set -euo pipefail

DIR="$XDG_CONFIG_HOME/sxmo/todos"

show_todos() {
    list_file="$DIR/$1"
    while true; do
      task="$({
        cat "$list_file" | sed "s,^,$icon_fil ,"
        cat <<EOF
$icon_pls Add Item
$icon_del Delete List
$icon_del Rename List
$icon_cls Back
EOF
      } | sxmo_dmenu_with_kb.sh -p "$1" -i)"
      if [ "${task}" = "" ]; then
        break
      fi

      case "$task" in
        *"Add Item")
          task=$(cat "$DIR/.suggestions" | sxmo_dmenu_with_kb.sh -p "Add item" -i)
          if [ "$task" != "" ]; then
            echo "${task}" >>"$list_file"
          fi
          ;;

        *"Delete List")
          confirm=$(echo -e "Yes\nNo" | dmenu -p "Really delete $1?" -i)
	  #TODO check and fix extra item accept
	  # TODO: sanitize input
	  if [ "$confirm" = "Yes" ]; then
	    rm -f "$list_file"
	  fi
	  return 0
          ;;

        *"Rename List")
          new_name=$(sxmo_dmenu_with_kb.sh -p "New name: " -i </dev/null)
	  # TODO: sanitize input
	  if [ "$new_name" != "" ]; then
	    mv "$list_file" "$DIR/$new_name"
	  fi
	  return 0
          ;;

         ""|*"Back")
          return 0
          ;;

        *)
	  task="$(echo "$task" | sed -e "s,^$icon_fil ,," | sed -e "s,/,\\\/,g")"
	  echo "XXX >$task<"
          if grep -q "$task" "${list_file}"; then  # Remove the entry
            # TODO escaping
            sed -i -e "/${task}/d" "${list_file}"
            echo "${task}" >>"$DIR/.suggestions"
          else   # Add the entry
            echo "${task}" >>"$list_file"
          fi
          ;;

      esac

    done
}

main_list() {
    while true; do
      todo_file=$({
        ls -1 "$DIR" | sed "s,^,$icon_dir ,"
        cat <<EOF
$icon_pls Add List
$icon_mnu System Menu
$icon_cls Close Menu
EOF
      } | sxmo_dmenu_with_kb.sh -p "Lists" -i)

      case "${todo_file}" in
        *"Add List")
          todo_file="$(sxmo_dmenu_with_kb.sh -p "Name:" -i </dev/null)"
          if [ "$todo_file" = "" ]; then
            continue
          fi
          touch "$DIR/${todo_file}"
          ;;
        *"System Menu")
          sxmo_appmenu.sh sys
          return 0
          ;;
        ""|*"Close Menu")
          return 0
          ;;
        *)
	  todo_file="$(echo "$todo_file" | sed "s,^$icon_dir ,,")"
          if ! [ -f "$DIR/${todo_file}" ]; then
            touch "$DIR/${todo_file}"
          fi
          show_todos "${todo_file}"
          ;;
      esac

    done
}

init_examples() {
  mkdir -p "$DIR"
  echo "Type sg to create new item" >>"$DIR/Tutorial list"
  echo "Select sg to delete it" >>"$DIR/Tutorial list"
  echo "Bread" >>"$DIR/Shopping list"
  echo "Milk" >>"$DIR/Shopping list"
}

if ! [ -d "$DIR" ]; then
  init_examples
fi

main_list
