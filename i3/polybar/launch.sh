#! /bin/bash

start_polybar() {
  MONITOR=$1 polybar main --config=$HOME/.config/polybar/config.ini 2>&1 \
    | tee -a /tmp/polybar-$1.log & disown
}

# stop running bar instances
killall -q polybar

# wait until processes have shut down
while pgrep -u $UID -x polybar > /dev/null; do sleep 1; done

# Get the list of connected monitors
connected_monitors=$(xrandr --query | grep " connected" | cut -d" " -f1)

# Start polybar on each connected monitor
for monitor in $connected_monitors; do
  start_polybar $monitor
done
