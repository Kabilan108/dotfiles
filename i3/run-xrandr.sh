#! /bin/bash

source $HOME/.bash_env

if [ -z $XRANDR_LAYOUT ]; then
  echo "XRANDR_LAYOUT is not set";
  exit 1;
fi

# Check the number of connected monitors
# monitor_count=$(xrandr --listmonitors | grep -c "^ ")
monitor_count=$(xrandr | grep " connected" | wc -l)

if [ $monitor_count -eq 1 ]; then
  xrandr --auto
else
  case $XRANDR_LAYOUT in
    "lisan-al-gaib")
      xrandr --output HDMI-0 --primary --mode 1920x1080 --pos 1920x0 --rotate normal --output DP-0 --off --output DP-1 --mode 1920x1080 --pos 0x0 --rotate normal --output DP-2 --off --output DP-3 --off --output DP-4 --off --output DP-5 --off
      ;;
    "moberg-office")
      # Add xrandr command for moberg-work layout
      xrandr --output eDP-1 --primary --mode 1920x1080 --pos 1920x458 --rotate normal --output DP-1 --off --output DP-2 --off --output DP-3 --mode 1920x1080 --pos 0x0 --rotate normal
      ;;
    *)
      echo "Error: Unexpected layout '$XRANDR_LAYOUT'"
      exit 1
      ;;
  esac
fi
