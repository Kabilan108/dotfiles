#!/bin/bash

# Get connected displays
displays=$(xrandr --listmonitors | tail -n +2 | awk '{print $4}')
display_count=$(echo "$displays" | wc -l)

# Initialize variables
selected_display=":0.0"
resolution=""
offset=""

if [ "$display_count" -gt 1 ]; then
    echo "Multiple displays detected. Please select a display to record:"
    display_number=1
    while IFS= read -r display; do
        geometry=$(xrandr --query | grep "^$display" | awk '{print $3}')
        echo "$display_number) $display ($geometry)"
        ((display_number++))
    done <<< "$displays"

    read -p "Enter display number: " choice
    selected_display=$(echo "$displays" | sed -n "${choice}p")

    # Get resolution and position of selected display
    display_info=$(xrandr --query | grep "^$selected_display" | awk '{print $3}')
    resolution=$(echo "$display_info" | cut -d'+' -f1)
    offset_x=$(echo "$display_info" | cut -d'+' -f2)
    offset_y=$(echo "$display_info" | cut -d'+' -f3)
else
    # Single display, use full resolution
    resolution=$(xdpyinfo | grep dimensions | awk '{print $2}')
    offset_x=0
    offset_y=0
fi

# List audio devices and let user select input
pactl list sources | grep -E 'Name:|Description:'

echo "Enter the audio source name from above (e.g., alsa_output.pci-0000_00_1f.3.analog-stereo.monitor):"
read audio_source

# Start recording with FFmpeg
ffmpeg -f x11grab -r 30 -s "$resolution" -i :0.0+"$offset_x","$offset_y" \
       -f pulse -i "$audio_source" \
       -c:v libx264 -preset ultrafast -crf 18 \
       -c:a aac -b:a 192k \
       "screen_recording_$(date +%Y%m%d_%H%M%S).mp4"
