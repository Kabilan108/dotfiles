#!/bin/bash

# Get current status
current_song=$(playerctl -p spotify metadata --format "{{ artist }} - {{ title }}")
status=$(playerctl -p spotify status)

# Define the options with status
options="⏯️ Play/Pause ($status)\n⏭️ Next\n⏮️ Previous\n🔄 Shuffle\n🔊 Volume Up\n🔉 Volume Down\n📑 Show Current"

# Show the menu
chosen=$(echo -e "$options" | rofi -dmenu -p "Now Playing: $current_song")

case "$chosen" in
    *"Play/Pause"*)
        playerctl -p spotify play-pause
        ;;
    *"Next"*)
        playerctl -p spotify next
        ;;
    *"Previous"*)
        playerctl -p spotify previous
        ;;
    *"Shuffle"*)
        playerctl -p spotify shuffle toggle
        ;;
    *"Volume Up"*)
        playerctl -p spotify volume 0.1+
        ;;
    *"Volume Down"*)
        playerctl -p spotify volume 0.1-
        ;;
    *"Show Current"*)
        notify-send "Now Playing" "$current_song"
        ;;
esac
