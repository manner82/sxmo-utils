#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors

# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. sxmo_common.sh

if [ -z "$SXMO_DEVICE_NAME" ]; then
	. /etc/profile.d/sxmo_init.sh
	# not grabbed
	if [ -z "$SXMO_DEVICE_NAME" ]; then
		_sxmo_load_environments
	fi
fi

smartdiff() {
	#argument one is the system default
	#argument two is the user version (to be migrated)

	if [ "$SXMO_MIGRATE_ORDER" = "user:system" ]; then
		printf "Your user file is in \e[31mred (-)\e[0m, the system default in \e[32mgreen (+)\e[0m\n"
	else
		printf "The system default is in \e[31mred (-)\e[0m, your user changes in \e[32mgreen (+)\e[0m\n"
		#swap arguments
		set -- "$2" "$1"
		echo "$@"
	fi
	if command -v delta > /dev/null; then
		# shellcheck disable=SC2086
		delta "$@"
	elif command -v colordiff > /dev/null; then
		# shellcheck disable=SC2086
		colordiff -ud "$@"
	else
		# poor man's ad-hoc colordiff
		ESC=$(printf "\e")
		# shellcheck disable=SC1087
		diff -ud "$@" | sed -E -e "s/^-(.*)$/-$ESC[31m\1$ESC[0m/" -e "s/^\+(.*)$/+$ESC[32m\1$ESC[0m/" -e "s/^@@(.*)$/$ESC[34m@@\1$ESC[0m/"
	fi
}

fetchversion() {
	head -n5 "$1" | grep -m1 "configversion: " | sed 's|.*configversion: \(.*\)|\1|'
}

resolvedifference() {
	userfile="$1"
	defaultfile="$2"

	(
		printf "\e[31mThe file \e[32m%s\e[31m differs\e[0m\n" "$userfile"
		smartdiff "$userfile" "$defaultfile"
	) | more

	printf "\e[31mMigration options for \e[32m%s\e[31m:\e[0m\n" "$userfile"

	printf "1 - Use [d]efault. Apply the Sxmo default, discarding all your own changes.\n"
	printf "2 - Open [e]ditor and merge the changes yourself; take care to set the same configversion.\n"
	printf "3 - Use your [u]ser version as-is; you verified it's compatible. (Auto-updates configversion only).\n"
	printf "4 - [i]gnore, do not resolve and don't change anything, ask again next time. (default)\n"
	printf "5 - Change the diff argument [o]rder and ask again\n"

	printf "\e[33mHow do you want to resolve this? Choose one of the options above [1234deui]\e[0m "

	read -r reply < /dev/tty
	abort=0
	case "$reply" in
		[1dD]*)
			#use default
			case "$userfile" in
				*hooks*)
					#just remove the user hook, will use default automatically
					rm "$userfile"
					abort=1 #no need for any further cleanup
					;;
				*)
					cp "$defaultfile" "$userfile" || abort=1
					;;
			esac
			;;
		[2eE]*)
			#open editor with both files and the diff
			export DIFFTOOL="${DIFFTOOL:-vimdiff}"
			if [ -n "$DIFFTOOL" ] && command -v "$DIFFTOOL" >/dev/null; then # ex vimdiff
				if [ "$SXMO_MIGRATE_ORDER" = "user:system" ]; then
					set -- "$DIFFTOOL" "$userfile" "$defaultfile"
				else
					set -- "$DIFFTOOL" "$defaultfile" "$userfile"
				fi
			else
				if [ "$SXMO_MIGRATE_ORDER" = "user:system" ]; then
					diff -u "$userfile" "$defaultfile" > "${XDG_RUNTIME_DIR}/migrate.diff"
				else
					diff -u "$defaultfile" "$userfile" > "${XDG_RUNTIME_DIR}/migrate.diff"
				fi
				# shellcheck disable=SC2086
				set -- $EDITOR "$userfile" "$defaultfile" "${XDG_RUNTIME_DIR}/migrate.diff"
			fi

			if ! "$@"; then
				#user may bail editor, in which case we ignore everything
				abort=1
			fi

			if [ -z "$DIFFTOOL" ]; then
				rm "${XDG_RUNTIME_DIR}/migrate.diff"
			fi
			;;
		[3uU]*)
			#update configversion automatically
			refversion="$(fetchversion "$defaultfile")"
			userversion="$(fetchversion "$userfile")"
			if [ -n "$userversion" ]; then
				sed -i "s/configversion: $userversion/configversion: $refversion/" "$userfile" || abort=1
			elif [ -n "$refversion" ]; then
				refline="$(head -n5 "$defaultfile" | grep -m1 "configversion: ")"
				# fall back in case the userfile doesn't contain a configversion at all yet
				sed -i "2i$refline" "$userfile" || abort=1
			fi
			;;
		[5oO]*)
			if [ "$SXMO_MIGRATE_ORDER" = "user:system" ]; then
				SXMO_MIGRATE_ORDER="system:user"
			else
				SXMO_MIGRATE_ORDER="user:system"
			fi
			;;
		*)
			abort=1
			;;
	esac

	if [ "$abort" -eq 0 ]; then
		#finish the migration, removing .needs-migration and moving to right place
		case "$userfile" in
			*needs-migration)
				mv -f "$userfile" "${userfile%.needs-migration}"
				;;
		esac
	fi
	printf "\n"
}

checkconfigversion() {
	userfile="$1"
	reffile="$2"
	if [ ! -e "$userfile" ] || [ ! -e "$reffile" ]; then
		#if the userfile doesn't exist then we revert to default anyway so it's considered up to date
		return 0
	fi

	refversion="$(fetchversion "$reffile")"
	if [ -z "$refversion" ]; then
		#no ref version found, check file diff instead
		if diff "$reffile" "$userfile" > /dev/null; then
			return 0
		else
			return 1
		fi
	fi

	userversion="$(fetchversion "$userfile")"
	if [ -z "$userversion" ]; then
		#no user version found, check file contents instead
		tmpreffile="${XDG_RUNTIME_DIR}/versioncheck"
		grep -v "configversion: " "$reffile" > "$tmpreffile"
		if diff "$tmpreffile" "$userfile" > /dev/null; then
			rm "$tmpreffile"
			return 0
		else
			rm "$tmpreffile"
			return 1
		fi
	fi

	[ "$refversion" = "$userversion" ]
}

defaultconfig() {
	defaultfile="$1"
	userfile="$2"
	filemode="$3"
	if [ -e "$userfile.needs-migration" ] && { [ "$MODE" = "interactive" ] || [ "$MODE" = "all" ]; }; then
		resolvedifference "$userfile.needs-migration" "$defaultfile"
		chmod "$filemode" "$userfile" 2> /dev/null
	elif [ ! -r "$userfile" ]; then
		mkdir -p "$(dirname "$userfile")"
		sxmo_log "Installing default configuration $userfile..."
		cp "$defaultfile" "$userfile"
		chmod "$filemode" "$userfile"
	elif [ "$MODE" = "reset" ]; then
		if [ ! -e "$userfile.needs-migration" ]; then
			mv "$userfile" "$userfile.needs-migration"
		else
			sxmo_log "$userfile was already flagged for needing migration; not overwriting the older one"
		fi
		cp "$defaultfile" "$userfile"
		chmod "$filemode" "$userfile"
	elif ! checkconfigversion "$userfile" "$defaultfile" || [ "$MODE" = "all" ]; then
		case "$MODE" in
			"interactive"|"all")
				resolvedifference "$userfile" "$defaultfile"
				;;
			"sync")
				sxmo_log "$userfile is out of date, disabling and marked as needing migration..."
				[ ! -e "$userfile.needs-migration" ] && cp "$userfile" "$userfile.needs-migration" #never overwrite older .needs-migration files, they take precendence
				chmod "$filemode" "$userfile.needs-migration"
				cp "$defaultfile" "$userfile"
				chmod "$filemode" "$userfile"
				;;
		esac
	fi
}

checkhooks() {
	if ! [ -e "$XDG_CONFIG_HOME/sxmo/hooks/" ]; then
		return
	fi
	for hook in \
		"$XDG_CONFIG_HOME/sxmo/hooks/"* \
		${SXMO_DEVICE_NAME:+"$XDG_CONFIG_HOME/sxmo/hooks/$SXMO_DEVICE_NAME/"*}; do
		{ [ -e "$hook" ] && [ -f "$hook" ];} || continue #sanity check because shell enters loop even when there are no files in dir (null glob)

		[ -h "$hook" ] && continue # shallow symlink

		if printf %s "$hook" | grep -q "/$SXMO_DEVICE_NAME/"; then
			# We also compare the device user hook to the system
			# default version
			DEFAULT_PATH="$(xdg_data_path sxmo/default_hooks/"$SXMO_DEVICE_NAME"/):$(xdg_data_path sxmo/default_hooks/)"
		else
			# We dont want to compare a default user hook to the device
			# system version
			DEFAULT_PATH="$(xdg_data_path sxmo/default_hooks/)"
		fi

		if [ "$MODE" = "reset" ]; then
			if [ ! -e "$hook.needs-migration" ]; then
				mv "$hook" "$hook.needs-migration" #move the hook away
			else
				sxmo_log "$hook was already flagged for needing migration; not overwriting the older one"
				rm "$hook"
			fi
			continue
		fi
		case "$hook" in
			*.needs-migration)
				defaulthook="$(PATH="$DEFAULT_PATH" command -v "$(basename "$hook" ".needs-migration")")"
				[ "$MODE" = sync ] && continue # ignore this already synced hook
				;;
			*.backup)
				#skip
				continue
				;;
			*)
				#if there is already one marked as needing migration, use that one instead and skip this one
				[ -e "$hook.needs-migration" ] && continue
				defaulthook="$(PATH="$DEFAULT_PATH" command -v "$(basename "$hook")")"
				;;
		esac
		if [ -f "$defaulthook" ]; then
			if diff "$hook" "$defaulthook" > /dev/null && [ "$MODE" != "sync" ]; then
				printf "\e[33mHook %s is identical to the default, so you don't need a custom hook, remove it? [y/N]\e[0m" "$hook"
				read -r reply < /dev/tty
				if [ "y" = "$reply" ]; then
					rm "$hook"
				fi
			elif ! checkconfigversion "$hook" "$defaulthook" || [ "$MODE" = "all" ]; then
				case "$MODE" in
					"interactive"|"all")
						resolvedifference "$hook" "$defaulthook"
						;;
					"sync")
						sxmo_log "$hook is out of date, disabling and marked as needing migration..."
						#never overwrite older .needs-migration files, they take precendence
						if [ ! -e "$hook.needs-migration" ]; then
							mv "$hook" "$hook.needs-migration"
						else
							rm "$hook"
						fi
						;;
				esac
			fi
		elif [ "$MODE" != "sync" ]; then
			(
				smartdiff "$hook" "/dev/null"
				printf "\e[31mThe hook \e[32m%s\e[31m does not exist (anymore), remove it? [y/N] \e[0m\n" "$hook"
			) | more
			read -r reply < /dev/tty
			if [ "y" = "$reply" ]; then
				rm "$hook"
			fi
			printf "\n"
		fi
	done
}

common() {
	defaultconfig "$(xdg_data_path sxmo/appcfg/profile_template)" "$XDG_CONFIG_HOME/sxmo/profile" 644
	defaultconfig "$(xdg_data_path sxmo/appcfg/fontconfig.conf)" "$XDG_CONFIG_HOME/fontconfig/conf.d/50-sxmo.conf" 644
}

sway() {
	defaultconfig "$(xdg_data_path sxmo/appcfg/sway_template)" "$XDG_CONFIG_HOME/sxmo/sway" 644
	defaultconfig "$(xdg_data_path sxmo/appcfg/foot.ini)" "$XDG_CONFIG_HOME/foot/foot.ini" 644
	defaultconfig "$(xdg_data_path sxmo/appcfg/mako.conf)" "$XDG_CONFIG_HOME/mako/config" 644
	defaultconfig "$(xdg_data_path sxmo/appcfg/bonsai_tree.json)" "$XDG_CONFIG_HOME/sxmo/bonsai_tree.json" 644
	defaultconfig "$(xdg_data_path sxmo/appcfg/wob.ini)" "$XDG_CONFIG_HOME/wob/wob.ini" 644
	defaultconfig "$(xdg_data_path sxmo/appcfg/conky.conf)" "$XDG_CONFIG_HOME/sxmo/conky.conf" 644
	defaultconfig "$(xdg_data_path sxmo/appcfg/wofi.config)" "$XDG_CONFIG_HOME/wofi/config" 644
	defaultconfig "$(xdg_data_path sxmo/appcfg/wofi.css)" "$XDG_CONFIG_HOME/wofi/style.css" 644
}

xorg() {
	defaultconfig "$(xdg_data_path sxmo/appcfg/Xresources)" "$HOME/.Xresources" 644
	defaultconfig "$(xdg_data_path sxmo/appcfg/xinit_template)" "$XDG_CONFIG_HOME/sxmo/xinit" 644
	defaultconfig "$(xdg_data_path sxmo/appcfg/dunst.conf)" "$XDG_CONFIG_HOME/dunst/dunstrc" 644
	defaultconfig "$(xdg_data_path sxmo/appcfg/bonsai_tree.json)" "$XDG_CONFIG_HOME/sxmo/bonsai_tree.json" 644
	defaultconfig "$(xdg_data_path sxmo/appcfg/xob_styles.cfg)" "$XDG_CONFIG_HOME/xob/styles.cfg" 644
	defaultconfig "$(xdg_data_path sxmo/appcfg/conky.conf)" "$XDG_CONFIG_HOME/sxmo/conky.conf" 644
}


#set default mode
[ -z "$*" ] && set -- interactive

# Don't allow running with sudo, or as root
if [ -n "$SUDO_USER" ]; then
	echo "$0 can't be run with sudo, it must be run as your user" >&2
	exit 127
fi

if [ "$USER" = "root" ]; then
	echo "$0 can't be run as root, it must be run as your user" >&2
	exit 127
fi

# Execute idempotent migrations
find "$(xdg_data_path sxmo/migrations)" -type f | sort -n | tr '\n' '\0' | xargs -0 sh

if [ -z "$*" ]; then
	set -- sync interactive
fi

#modes may be chained
for MODE in "$@"; do
	case "$MODE" in
		"interactive"|"all")
			common
			sway
			xorg
			checkhooks
			;;
		"sync"|"reset")
			case "$SXMO_WM" in
				sway)
					common
					sway
					;;
				dwm)
					common
					xorg
					;;
				*)
					common
					sway
					xorg
					;;
			esac

			checkhooks
			;;
		"state")
			NEED_MIGRATION="$(find "$XDG_CONFIG_HOME/" -name "*.needs-migration")"
			if [ -n "$NEED_MIGRATION" ]; then
				sxmo_log "The following configuration files need migration: $NEED_MIGRATION"
				exit "$(echo "$NEED_MIGRATION" | wc -l)" #exit code represents number of files needing migration
			else
				sxmo_log "All configuration files are up to date"
			fi
			;;
		*)
			sxmo_log "Invalid mode: $MODE"
			exit 2
			;;
	esac
done
