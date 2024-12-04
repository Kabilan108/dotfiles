#!/bin/bash

rofi_finder() {
    fdfind . "$HOME" "/mnt" --type f --type d | rofi -dmenu -i -p "Search files and folders"
}

# Use fdfind to list files and directories, then pipe to rofi for selection
selected_item=$(rofi_finder)

# If an item was selected, open it
if [ -n "$selected_item" ]; then
    if [ -d "$selected_item" ]; then
        # If it's a directory, open it in the file manager
        xdg-open "$selected_item"
    else
        # If it's a file, open it with the default application
        xdg-open "$selected_item"
    fi
fi
