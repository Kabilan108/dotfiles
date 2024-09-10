#!/bin/bash

APPIMAGE_PATH="/home/muaddib/.local/bin/cursor/cursor.AppImage"
APPIMAGE_URL="https://downloader.cursor.sh/linux/appImage/x64"

echo "Starting Cursor AppImage download..."

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
