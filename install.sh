#! /bin/bash

INSTALL_LOG="install.log"
> "$INSTALL_LOG"

log() {
  local level="info"
  local color="\033[34m"
  if [ "$1" = "e" ]; then
    level="error"
    color="\033[31m"
  fi
  local timestamp=$(date +"%H:%M:%S")
  local message="${@:2}"
  local formatted_log="$timestamp | $level | $message"
  echo -e "${color}${formatted_log}\033[0m"
  echo "$formatted_log" >> "$INSTALL_LOG"
}

log i "Updating and upgrading packages"
sudo apt update
sudo apt upgrade -y


# install (confirm versions)
# - nvim
#   - nvim dependencies & plugins
#   - potentially lua for the image plugin
# - uv (use this for ruff, pre-commit, ipython (global) and other python tools)
# - cursor
#   - will need fuse for appimages
# - kitty
# - i3wm
#   - rofi
#   - dunst
#   - picom
#   - polybar
#   - feh??
# - docker
# - jetbrains installer
# - zotero
# - brave
# - spotify
# - obsidian
# - zoom
# - inkscape
# - telegram
# - whatsapp client
# - discord
# - nvm, node, npm, bun
# - ffmpeg
# - rust/cargo
# - ripgrep, fd-find, sd
