#!/bin/bash

# Get the screen resolution
resolution=$(xdpyinfo | grep dimensions | awk '{print $2}')

# List audio devices and let user select input
pactl list sources | grep -E 'Name:|Description:'

echo "Enter the audio source name from above (e.g., alsa_output.pci-0000_00_1f.3.analog-stereo.monitor):"
read audio_source

# Start recording with FFmpeg
ffmpeg -f x11grab -r 30 -s "$resolution" -i :0.0 \
       -f pulse -i "$audio_source" \
       -c:v libx264 -preset ultrafast -crf 18 \
       -c:a aac -b:a 192k \
       "screen_recording_$(date +%Y%m%d_%H%M%S).mp4"
