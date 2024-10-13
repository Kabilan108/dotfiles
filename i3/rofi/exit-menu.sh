#!/bin/bash

# Function to lock the screen
lock_screen() {
    # Take a fullscreen screenshot
    scrot /tmp/currentworkspace.png

    # Blur the screenshot
    convert /tmp/currentworkspace.png -blur 0x5 /tmp/currentworkspaceblur.png

    # Composite the overlay onto the blurred screenshot
    overlay=/usr/share/pixmaps/lockoverlay.png
    composite -gravity center $overlay /tmp/currentworkspaceblur.png /tmp/lockbackground.png

    # Lock the screen with the final image
    i3lock -i /tmp/lockbackground.png --nofork &

    # Wait a moment for the lock screen to activate
    sleep 1

    # Clean up temporary files
    rm /tmp/currentworkspace.png /tmp/currentworkspaceblur.png /tmp/lockbackground.png
}

# Function to show power off confirmation
confirm_power_off() {
    rofi \
        -theme-str 'window {width: 400px; height:150px;}' \
        -dmenu -i -p 'Do you really want to power off?' \
        -lines 2 \
        -line-margin 5 \
        -line-padding 10 \
        -kb-row-select 'Tab' \
        -kb-row-tab '' <<< $'No\nYes' \
        | grep -q '^Yes$' && systemctl poweroff
}

# Main menu options
options="Lock\nSuspend\nLogout\nPower Off"

# Show the main menu and get user selection
selected=$(echo -e $options | rofi \
    -theme-str 'window {width: 300px; height:200px;}' \
    -dmenu -i -p 'Exit Menu' \
    -lines 4 \
    -line-margin 5 \
    -line-padding 10 \
    -kb-row-select 'Tab' \
    -kb-row-tab '')

# Process the user's selection
case $selected in
    Lock)
        lock_screen
        ;;
    Suspend)
        lock_screen
        systemctl suspend
        ;;
    Logout)
        i3-msg exit
        ;;
    "Power Off")
        confirm_power_off
        ;;
esac
