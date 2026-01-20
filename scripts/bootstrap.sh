#!/usr/bin/env bash

CONFDIR="$HOME/.config"
DOTFILES="$(dirname "$(realpath "$0")")"

safe_remove() {
  local target="$1"
  if [ -L "$target" ]; then
    echo "Removing existing symlink: $target"
    rm "$target"
  elif [ -d "$target" ]; then
    echo "Removing existing directory: $target"
    rm -r "$target"
  elif [ -f "$target" ]; then
    echo "Removing existing file: $target"
    rm "$target"
  fi
}

create_symlink() {
  local source="$1"
  local dest="$2"
  local dest_parent=$(dirname "$dest")

  mkdir -p "$dest_parent"
  safe_remove "$dest"

  echo "Creating symlink: $dest -> $source"
  ln -s "$source" "$dest"
}

mkdir -p "$CONFDIR"

echo "Creating user directories..."
mkdir -p "$HOME/downloads" \
         "$HOME/media/screenshots" \
         "$HOME/media/screencaps" \
         "$HOME/media/wallpapers"

if [ -d "/vault" ]; then
  mkdir -p "/vault/work" "/vault/repos" "/vault/journal" "/vault/userdata" "/vault/experiments"
  create_symlink "/vault/work" "$HOME/work"
  create_symlink "/vault/repos" "$HOME/repos"
  create_symlink "/vault/experiments" "$HOME/experiments"
  if [ -d "/vault/notes/coppermind" ]; then
    create_symlink "/vault/notes/coppermind" "$HOME/notes"
  fi
fi

if [ ! -d $HOME/.tmux/plugins ]; then
  echo "Setting up tmux plugins"
  mkdir -p "$HOME/.tmux/plugins"
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm" > /dev/null
  git clone -b v2.1.3 https://github.com/catppuccin/tmux.git "$HOME/.tmux/plugins/catppuccin/tmux" > /dev/null
fi

echo "Bootstrap script finished."
