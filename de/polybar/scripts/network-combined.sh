#!/bin/bash

# Source the environment variables
source ~/.bash_env

POLYBAR_TAILSCALE_INTERFACE=tailscale0

# Function to get WiFi info
get_wifi_info() {
    if [ -n "$WLAN_INTERFACE" ]; then
        essid=$(iwgetid -r)
        if [ -n "$essid" ]; then
            echo "󰖩 $essid"
        else
            echo "󰖪"
        fi
    else
        echo "WLAN_IF not set"
    fi
}

# TODO: add ethernet support

# Function to get Tailscale info
get_tailscale_info() {
    if [ -n "$POLYBAR_TAILSCALE_INTERFACE" ]; then
        tailscale_ip=$(ip -4 addr show dev $POLYBAR_TAILSCALE_INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
        if [ -n "$tailscale_ip" ]; then
            echo " 󰒒 $tailscale_ip"
        else
            echo ""
        fi
    else
        echo "TAILSCALE_IF not set"
    fi
}

# Combine the information
wifi_info=$(get_wifi_info)
tailscale_info=$(get_tailscale_info)

echo "$wifi_info $tailscale_info "
