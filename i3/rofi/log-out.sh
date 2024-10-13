#! /bin/bash

rofi \
    -theme-str 'window {width: 400px; height:150px;}' \
    -dmenu -i -p 'Do you really want to exit i3?' \
    -lines 2 \
    -line-margin 5 \
    -line-padding 10 \
    -kb-row-select 'Tab' \
    -kb-row-tab '' <<< $'No\nYes' \
    | grep -q '^Yes$' && i3-msg exit
