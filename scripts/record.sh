#!/bin/bash

# Check for required tools
for cmd in xrandr ffmpeg pactl; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: $cmd is not installed. Please install it and try again."
        exit 1
    fi
done

# Get connected displays
displays=$(xrandr --listmonitors | tail -n +2 | awk '{print $4}')
display_count=$(echo "$displays" | wc -l)

# Initialize variables
selected_display=""
resolution=""
offset_x=""
offset_y=""

if [ "$display_count" -gt 1 ]; then
    echo "Multiple displays detected. Please select a display to record:"
    display_number=1
    while IFS= read -r display; do
        geometry=$(xrandr --query | grep "^$display" | grep -oP '\d+x\d+\+\d+\+\d+')
        if [ -n "$geometry" ]; then
            resolution=$(echo "$geometry" | cut -d'+' -f1)
            offset_x=$(echo "$geometry" | cut -d'+' -f2)
            offset_y=$(echo "$geometry" | cut -d'+' -f3)
            echo "$display_number) $display ($geometry)"
            ((display_number++))
        fi
    done <<< "$displays"

    read -p "Enter display number (1-$((display_count))): " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "$display_count" ]; then
        echo "Error: Invalid display number. Exiting."
        exit 1
    fi

    selected_display=$(echo "$displays" | sed -n "${choice}p")
    geometry=$(xrandr --query | grep "^$selected_display" | grep -oP '\d+x\d+\+\d+\+\d+')
    resolution=$(echo "$geometry" | cut -d'+' -f1)
    offset_x=$(echo "$geometry" | cut -d'+' -f2)
    offset_y=$(echo "$geometry" | cut -d'+' -f3)
else
    resolution=$(xdpyinfo | grep dimensions | awk '{print $2}')
    offset_x=0
    offset_y=0
fi

# List audio devices
echo "Available audio sources:"
pactl list sources short | awk '{print $1 "\t" $2}'
echo "Enter the audio source name from above (e.g., alsa_input.usb-...):"
read -r audio_source

# Validate audio source
if ! pactl list sources short | grep -q "$audio_source"; then
    echo "Error: Invalid audio source. Exiting."
    exit 1
fi

# Start recording with FFmpeg
output_file="screen_recording_$(date +%Y%m%d_%H%M%S).mp4"
ffmpeg -f x11grab -r 30 -s "$resolution" -i ":0.0+$offset_x,$offset_y" \
       -f pulse -i "$audio_source" \
       -c:v libx264 -preset ultrafast -crf 18 -pix_fmt yuv420p \
       -c:a aac -b:a 192k \
       "$output_file"

# Check FFmpeg exit status
exit_status=$?
if [ $exit_status -eq 0 ]; then
    echo "Recording saved to $output_file"
elif [ $exit_status -eq 130 ]; then  # SIGINT (Ctrl+C) typically returns 130
    echo "Recording stopped by user. File saved to $output_file"
else
    echo "Error: Recording failed with exit code $exit_status."
    exit 1
fi
