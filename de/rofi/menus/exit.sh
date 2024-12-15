#!/bin/bash

# Function to show power off confirmation
confirm_power_off() {
  rofi \
    -theme-str 'window {width: 400px; height:150px;}' \
    -dmenu -i -p 'Do you really want to power off?' \
    -lines 2 \
    -line-margin 5 \
    -line-padding 10 \
    -kb-row-tb '' <<< $'No\nYes' \
    | grep -q '^Yes$' && systemctl poweroff
}

# Main menu options
options="Lock\nSuspend\nLogout\nRestart\nPower Off"

# Show the main menu and get user selection
selected=$(echo -e $options | rofi \
  -theme-str 'window {width: 300px; height:250px;}' \
  -dmenu -i -p 'Exit Menu' \
  -lines 5 \
  -line-margin 5 \
  -line-padding 10 \
  -kb-row-tab '')

# Process the user's selection
case $selected in
  Lock)
    betterlockscreen -l dim
      ;;
  Suspend)
    systemctl suspend
    ;;
  Logout)
    i3-msg exit
    ;;
  Restart)
    systemctl reboot
    ;;
  "Power Off")
    confirm_power_off
    ;;
esac
