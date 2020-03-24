#!/usr/bin/env sh
WIN=$(xdotool getwindowfocus)

programchoicesinit() {
  WMCLASS="${1:-$(xprop -id $(xdotool getactivewindow) | grep WM_CLASS | cut -d ' ' -f3-)}"

  # Default
  CHOICES="$(echo "
    Scripts            ^ 0 ^ sxmo_appmenu.sh scripts
    Apps               ^ 0 ^ sxmo_appmenu.sh applications
    Volume ↑           ^ 1 ^ sxmo_vol.sh up
    Volume ↓           ^ 1 ^ sxmo_vol.sh down
    Camera             ^ 0 ^ sxmo_camera.sh
    Wifi               ^ 0 ^ st -e "nmtui"
    System Config      ^ 0 ^ sxmo_appmenu.sh control
    Logout             ^ 0 ^ pkill -9 dwm
    Close Menu         ^ 0 ^ quit
  ")" && WINNAME=Sys

  echo $WMCLASS | grep -i "applications" && CHOICES="$(echo "
    Surf            ^ 0 ^ surf
    NetSurf         ^ 0 ^ netsurf
    Sacc            ^ 0 ^ st -e sacc i-logout.cz/1/bongusta
    W3M             ^ 0 ^ st -e w3m duck.com
    St              ^ 0 ^ st
    Firefox         ^ 0 ^ firefox
    Foxtrotgps      ^ 0 ^ foxtrotgps
    Close Menu      ^ 0 ^ quit
  ")" && WINNAME=Apps

  echo $WMCLASS | grep -i "scripts" && CHOICES="$(echo "
    Timer           ^ 0 ^ sxmo_timermenu.sh
    Youtube         ^ 0 ^ sxmo_youtube.sh
    Youtube (Audio) ^ 0 ^ sxmo_youtube.sh
    Weather         ^ 0 ^ sxmo_weather.sh
    RSS             ^ 0 ^ sxmo_rss.sh
    Close Menu      ^ 0 ^ quit
  ")" && WINNAME=Scripts

  echo $WMCLASS | grep -i "control" && CHOICES="$(echo "
    Volume ↑           ^ 1 ^ sxmo_vol.sh up
    Volume ↓           ^ 1 ^ sxmo_vol.sh down
    Brightesss ↑       ^ 1 ^ sxmo_brightness.sh up
    Brightness ↓       ^ 1 ^ sxmo_brightness.sh down
    Rotate             ^ 1 ^ rotate
    Wifi               ^ 0 ^ st -e "nmtui"
    Upgrade Pkgs       ^ 0 ^ st -e sxmo_upgrade.sh
    Close Menu         ^ 0 ^ quit
  ")" && WINNAME=Control

  echo $WMCLASS | grep -i "mpv" && CHOICES="$(echo "
   Pause        ^ 0 ^ key space
   Seek ←       ^ 1 ^ key Left
   Seek →       ^ 1 ^ key Right
   App Volume ↑ ^ 1 ^ key 0
   App Volume ↓ ^ 1 ^ key 9
   Speed ↑      ^ 1 ^ key bracketright
   Speed ↓      ^ 1 ^ key bracketleft
   Screenshot   ^ 1 ^ key s
   Loopmark     ^ 1 ^ key l
   Info         ^ 1 ^ key i
   Seek Info    ^ 1 ^ key o
   Close Menu   ^ 0 ^ quit
  ")" && WINNAME=Mpv

  #  St
  echo $WMCLASS | grep -i "st-256color" && CHOICES="$(echo "
      Pastecomplete   ^ 0 ^ key Ctrl+Shift+u
      Paste           ^ 0 ^ key Ctrl+Shift+v
      Pipe Data       ^ 0 ^ 
      Zoom +          ^ 1 ^ key Ctrl+Shift+Prior
      Zoom -          ^ 1 ^ key Ctrl+Shift+Next
      Scroll ↑        ^ 1 ^ key Shift+Prior
      Scroll ↓        ^ 1 ^ key Shift+Next
      Invert          ^ 1 ^ key Ctrl+Shift+x
      Hotkeys         ^ 0 ^ sxmo_appmenu.sh sthotkeys
      Close Menu      ^ 0 ^ quit
  ")" && WINNAME=st

  #  St hotkeys
  echo $WMCLASS | grep -i "sthotkeys" && CHOICES="$(echo "
      Send Ctrl-C      ^ 0 ^ key Ctrl+C
      Send Ctrl-L      ^ 0 ^ key Ctrl+L
      Send Ctrl-      ^ 0 ^ key Ctrl+L
      Close Menu       ^ 0 ^ quit
  ")" && WINNAME=st

  # Surf
  echo $WMCLASS | grep surf && CHOICES="$(echo "
      Navigate    ^ 0 ^ key Ctrl+g
      Link Menu   ^ 0 ^ key Ctrl+d
      Pipe URL    ^ 0 ^ sxmo_urlhandler.sh
      Zoom +      ^ 1 ^ key Ctrl+Shift+k
      Zoom -      ^ 1 ^ key Ctrl+Shift+j
      Scroll ↑    ^ 1 ^ key Ctrl+space
      Scroll ↓    ^ 1 ^ key Ctrl+b
      JS Toggle   ^ 1 ^ key Ctrl+Shift+s
      Search      ^ 1 ^ key Ctrl+f
      History ←    ^ 1 ^ key Ctrl+h
      History →   ^ 1 ^ key Ctrl+l
      Close Menu        ^ 0 ^ quit
  ")" && WINNAME=surf

  echo $WMCLASS | grep -i netsurf && CHOICES="$(echo "
      Pipe URL          ^ 0 ^ sxmo_urlhandler.sh
      Zoom +            ^ 1 ^ key Ctrl+plus
      Zoom -            ^ 1 ^ key Ctrl+minus
      History  ←      ^ 1 ^ key Alt+Left
      History  →   ^ 1 ^ key Alt+Right
      Close Menu        ^ 0 ^ quit
  ")" && WINNAME=netsurf

  echo $WMCLASS | grep -i foxtrot && CHOICES="$(echo "
      Zoom +            ^ 1 ^ key i
      Zoom -            ^ 1 ^ key o
      Panel toggle      ^ 1 ^ key m
      Autocenter toggle ^ 0 ^ key a
      Route             ^ 0 ^ key r
      Gmaps Transfer    ^ 0 ^ key o
      Copy Cords        ^ 0 ^ key o
      Close Menu        ^ 0 ^ quit
  ")" && WINNAME=gps
}

rotate() {
  xrandr | grep primary | cut -d' ' -f 5 | grep right && xrandr -o normal || xrandr -o right
}

key() {
  xdotool windowactivate $WIN
  xdotool key --clearmodifiers $1
  #--window $WIN
}

quit() {
  xset r off
  exit 0
}

boot() {
  DMENUIDX=0
  PICKED=""
  xset r on
  pgrep -f sxmo_appmenu.sh | grep -Ev "^${$}$" | xargs kill -9
  pkill -9 dmenu
}

mainloop() {
  while :
  do
    PICKED=$(
      echo "$CHOICES" | 
      xargs -0 echo | 
      cut -d'^' -f1 | 
      sed '/^[[:space:]]*$/d' |
      awk '{$1=$1};1' |
      dmenu -idx $DMENUIDX -l 14 -c -fn "Terminus-30" -p "$WINNAME"
    )
    LOOP=$(echo "$CHOICES" | grep "$PICKED" | cut -d '^' -f2)
    CMD=$(echo "$CHOICES" | grep "$PICKED" | cut -d '^' -f3)
    DMENUIDX=$(echo $(echo "$CHOICES" | grep -n "$PICKED" | cut -d ':' -f1) - 1 | bc)
    eval $CMD
    echo $LOOP | grep 1 || quit
  done
}

boot
programchoicesinit $@
mainloop
