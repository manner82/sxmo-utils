#!/usr/bin/env sh

# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. "$(dirname "$0")/sxmo_common.sh"

[ -z "$SXMO_SUBREDDITS" ] && SXMO_SUBREDDITS="pine64official pinephoneofficial unixporn postmarketos linux"

menu() {
	sxmo_keyboard.sh open
	SUBREDDIT="$(
		printf %b "Close Menu\n$(echo "$SXMO_SUBREDDITS" | tr " " '\n')" |
		sxmo_dmenu.sh -p "Subreddit:"
	)"
	sxmo_keyboard.sh close
	[ "Close Menu" = "$SUBREDDIT" ] && exit 0

	REDDITRESULTS="$(
		reddit-cli "$SUBREDDIT" |
			grep -E '^((created_utc|ups|title|url):|===)' |
			sed -E 's/^(created_utc|ups|title|url):\s+/\t/g' |
			tr -d '\n' |
			sed 's/===/\n/g' |
			sed 's/^\t//g' |
			sort -t"$(printf '%b' '\t')" -rnk4 |
			awk -F'\t' '{ printf "↑%4s", $3; print " " $4 " " $1 " " $2 }'
	)"

	while true; do
		RESULT="$(
			printf %b "Close Menu\n$REDDITRESULTS" |
			sxmo_dmenu.sh -fn Terminus-20
		)"

		[ "Close Menu" = "$RESULT" ] && exit 0
		URL=$(echo "$RESULT" | awk -F " " '{print $NF}')

		sxmo_urlhandler.sh "$URL" fork
	done
}

menu
