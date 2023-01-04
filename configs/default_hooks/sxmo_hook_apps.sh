#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors
# shellcheck disable=SC2154

# include common definitions \
# shellcheck source=configs/default_hooks/sxmo_hook_icons.sh
. sxmo_hook_icons.sh

write_line() {
	printf "%s ^ 0 ^ %s\n" "$1" "$2"
}

write_line_app() {
	executable="$1"
	label="$2"
	command="$3"
	if command -v "$executable" >/dev/null; then
		write_line "$label" "$command"
	fi
}

write_line_app jami-qt "$icon_msg Jami" "jami-qt"
write_line_app aerc "$icon_eml Aerc" "sxmo_terminal.sh aerc"
write_line_app amfora "$icon_glb Amfora" "sxmo_terminal.sh amfora"
write_line_app alpine "$icon_eml Alpine" "sxmo_terminal.sh alpine"
write_line_app anbox-launch "$icon_and Anbox" "anbox"
write_line_app anki "$icon_str Anki" "anki"
write_line_app audacity "$icon_mic Audacity" "audacity"
write_line_app gnome-calculator "$icon_clc Calculator" "gnome-calculator"
write_line_app calcurse "$icon_clk Calcurse" "sxmo_terminal.sh calcurse"
write_line_app cmus "$icon_mus Cmus" "sxmo_terminal.sh cmus"
write_line_app dino "$icon_msg Dino" "GDK_SCALE=1 dino"
write_line_app dolphin "$icon_dir Dolphin" "dolphin"
write_line_app emacs "$icon_edt Emacs (Terminal)" "sxmo_terminal.sh emacs -nw"
write_line_app emacs "$icon_edt Emacs (X)" "emacs"
write_line_app epiphany "$icon_glb Epiphany" "epiphany"
write_line_app epy "$icon_bok Epy" "sxmo_terminal.sh epy"
write_line_app evince "$icon_bok Evince" "evince"
write_line_app falkon "$icon_flk Falkon" "falkon"
write_line_app firefox "$icon_ffx Firefox" "firefox"
write_line_app firefox-esr "$icon_ffx Firefox ESR" "firefox-esr"
write_line_app foliate "$icon_bok Foliate" "foliate"
( [ "$SXMO_WM" = sway ] && command -v foot >/dev/null) && \
	write_line "$icon_trm Foot" "foot $SHELL"
write_line_app foxtrotgps "$icon_gps Foxtrotgps" "foxtrotgps"
write_line_app geany "$icon_eml Geany" "geany"
write_line_app gedit "$icon_edt Gedit" "gedit"
write_line_app geeqie "$icon_img Geeqie" "geeqie"
write_line_app geopard "$icon_glb Geopard" "geopard"
write_line_app gerbil "$icon_glb Gerbil" "gerbil"
write_line_app giara "$icon_red Giara" "giara"
write_line_app gnome-chess "$icon_chs Gnome Chess" "gnome-chess"
write_line_app gomuks "$icon_msg Gomuks" "sxmo_terminal.sh gomuks"
write_line_app gpodder "$icon_rss gPodder" "gpodder"
write_line_app gucharmap "$icon_inf Gucharmap" "gucharmap"
write_line_app hexchat "$icon_msg Hexchat" "hexchat"
write_line_app htop "$icon_cfg Htop" "sxmo_terminal.sh htop"
write_line_app irssi "$icon_msg Irssi" "sxmo_terminal.sh irssi"
write_line_app ii "$icon_msg Ii" "sxmo_terminal.sh ii"
write_line_app ipython "$icon_trm IPython" "sxmo_terminal.sh ipython"
write_line_app kasts "$icon_rss Kasts" "kasts"
write_line_app kmail "$icon_eml KMail" "kmail"
write_line_app kontact "$icon_msg Kontact" "kontact"
write_line_app konversation "$icon_msg Konversation" "konversation"
write_line_app kwrite "$icon_edt Kwrite" "kwrite"
write_line_app lagrange "$icon_glb Lagrange" "lagrange"
write_line_app lf "$icon_dir Lf" "sxmo_terminal.sh lf"
write_line_app lollypop "$icon_mus Lollypop" "lollypop"
write_line_app luakit "$icon_glb Luakit" "luakit"
write_line_app marble "$icon_map Marble" "marble"
write_line_app micro "$icon_edt Micro" "sxmo_terminal.sh micro"
write_line_app midori "$icon_glb Midori" "midori"
write_line_app mutt "$icon_eml Mutt" "sxmo_terminal.sh mutt"
write_line_app nano "$icon_edt Nano" "sxmo_terminal.sh nano"
write_line_app navit "$icon_gps Navit" "navit"
write_line_app ncmpcpp "$icon_mus Ncmpcpp" "sxmo_terminal.sh ncmpcpp"
write_line_app neomutt "$icon_eml Neomutt" "sxmo_terminal.sh neomutt"
write_line_app nheko "$icon_msg Nheko" "nheko"
write_line_app nvim "$icon_vim Neovim" "sxmo_terminal.sh nvim"
write_line_app netsurf "$icon_glb Netsurf" "netsurf"
write_line_app newsboat "$icon_rss Newsboat" "sxmo_terminal.sh newsboat"
write_line_app nnn "$icon_dir Nnn" "sxmo_terminal.sh nnn"
write_line_app pidgin "$icon_msg Pidgin" "pidgin"
write_line_app pulsemixer "$icon_mus Pulsemixer" "sxmo_terminal.sh pulsemixer"
write_line_app pure-maps "$icon_map Pure-Maps" "pure-maps"
write_line_app mepo "$icon_map mepo" "mepo"
write_line_app podboat "$icon_rss Podboat" "sxmo_terminal.sh podboat"
write_line_app profanity "$icon_msg Profanity" "sxmo_terminal.sh profanity"
write_line_app qutebrowser "$icon_glb Qutebrowser" "qutebrowser"
write_line_app ranger "$icon_dir Ranger" "sxmo_terminal.sh ranger"
write_line_app sacc "$icon_glb Sacc" "sxmo_terminal.sh sacc i-logout.cz/1/bongusta"
write_line_app senpai "$icon_msg Senpai" "sxmo_terminal.sh senpai"
write_line_app sic "$icon_msg Sic" "sxmo_terminal.sh sic"
([ "$SXMO_WM" = dwm ] && command -v st >/dev/null) && \
	write_line "$icon_trm St" "st -e $SHELL"
write_line_app surf "$icon_glb Surf" "surf"
write_line_app syncthing "$icon_rld Syncthing" "syncthing"
write_line_app telegram-desktop "$icon_tgm Telegram" "telegram-desktop"
write_line_app termite "$icon_trm Termite" "termite -e $SHELL"
write_line_app thunar "$icon_dir Thunar" "sxmo_terminal.sh thunar"
write_line_app thunderbird "$icon_eml Thunderbird" "thunderbird"
write_line_app com.github.bleakgrey.tootle "$icon_msg Tootle" "com.github.bleakgrey.tootle"
write_line_app totem "$icon_mvi Totem" "totem"
write_line_app tuir "$icon_red Tuir" "sxmo_terminal.sh tuir"
write_line_app tut "$icon_msg Tut" "sxmo_terminal.sh tut"
write_line_app weechat "$icon_msg Weechat" "sxmo_terminal.sh weechat"
write_line_app pavucontrol "$icon_mus Pavucontrol" "pavucontrol"
write_line_app w3m "$icon_glb W3m" "sxmo_terminal.sh w3m duck.com"
write_line_app vim "$icon_vim Vim" "sxmo_terminal.sh vim"
write_line_app vimb "$icon_glb Vimb" "vimb"
write_line_app vis "$icon_vim Vis" "sxmo_terminal.sh vis"
write_line_app vlc "$icon_mvi Vlc" "vlc"
write_line_app vte-2.91 "$icon_trm VTE 3" "vte-2.91"
([ "$SXMO_WM" = dwm ] && command -v xcalc >/dev/null) && \
	write_line "$icon_clc Xcalc" "xcalc"
write_line_app xournal "$icon_bok Xournal" "xournal"
write_line_app xournalpp "$icon_bok Xournalpp" "xournalpp"
write_line_app zathura "$icon_bok Zathura" "zathura"
write_line_app j4-dmenu-desktop "$icon_grd All apps" "j4-dmenu-desktop --dmenu=sxmo_dmenu.sh --term=sxmo_terminal.sh"
