#!/bin/sh

# TODO: use this to set the layout
# TODO: make this accept flags, and if not show a rofi menu to select the layout
XRANDR_LAYOUT="lisan-al-gaib"

# Get the number of connected monitors
MONITOR_COUNT=$(xrandr --query | grep " connected" | wc -l)
echo $MONITOR_COUNT > /tmp/monitor_count

xrandr --output HDMI-0 --primary --mode 1920x1080 --pos 1920x0 --rotate normal --output DP-0 --off --output DP-1 --mode 1920x1080 --pos 0x0 --rotate normal --output DP-2 --off --output DP-3 --off --output DP-4 --off --output DP-5 --off
