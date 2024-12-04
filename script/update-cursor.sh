#!/bin/bash

# modify this so it doesn't break cursor if run w/o an internet connection

APPIMAGE_PATH="/home/muaddib/.local/bin/cursor/cursor.AppImage"
APPIMAGE_URL="https://downloader.cursor.sh/linux/appImage/x64"

echo "Starting Cursor AppImage download..."

if [ -f $APPIMAGE_PATH ]; then
    rm $APPIMAGE_PATH
fi

if wget -q -O $APPIMAGE_PATH $APPIMAGE_URL; then
    echo "Cursor AppImage downloaded successfully to $APPIMAGE_PATH"
    echo "Setting executable permissions..."
    if chmod +x $APPIMAGE_PATH; then
        echo "Executable permissions set successfully"
        echo "Cursor AppImage installation completed"
    else
        echo "Failed to set executable permissions"
        exit 1
    fi
else
    echo "Failed to download Cursor AppImage"
    exit 1
fi
