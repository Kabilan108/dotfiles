#! /bin/bash

# stop running bar instances
killall -q polybar

# wait until process have shut down
while pgrep -u $UID -x polybar > /dev/null; do sleep 1; done

change this
echo "--> $(date +'%Y.%m.%d - %H:%M:%S') -----------" | tee -a /tmp/polybar-main.log
polybar main --config=$HOME/.config/polybar/config.ini 2>&1 \
  | tee -a /tmp/polybar-main.log & disown
