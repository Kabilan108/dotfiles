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
  mkdir -p "/vault/work" "/vault/repos" "/vault/journal" "/vault/userdata"
  create_symlink "/vault/work" "$HOME/work"
  create_symlink "/vault/repos" "$HOME/repos"
  create_symlink "/vault/journal" "$HOME/journal"
  create_symlink "/vault/userdata" "$HOME/userdata"
fi

echo "Symlinking ~/dotfiles/bin to ~/bin..."
create_symlink "$DOTFILES/bin" "$HOME/bin"

echo "Symlinking directories in ~/dotfiles/desktop to ~/.config..."
for dir in "$DOTFILES/desktop"/*/; do
  dir_name=$(basename "$dir")
  if [ -d "$dir" ]; then
    create_symlink "$dir" "$CONFDIR/$dir_name"
  fi
done

echo "Symlinking directories in ~/dotfiles/conf to ~/.config..."
for dir in "$DOTFILES/conf"/*/; do
  dir_name=$(basename "$dir")
  if [ -d "$dir" ]; then
    if [[ "$dir_name" == "vscode" || "$dir_name" == "ipython" ]]; then
      continue
    fi
    create_symlink "$dir" "$CONFDIR/$dir_name"
  fi
done

echo "Symlinking files in ~/dotfiles/conf to ~/..."
shopt -s dotglob
for file in "$DOTFILES/conf"/*; do
  if [ -f "$file" ]; then
    file_name=$(basename "$file")
    create_symlink "$file" "$HOME/$file_name"
  fi
done

if [ ! -d $HOME/.tmux/plugins ]; then
  echo "Setting up tmux plugins"
  mkdir -p "$HOME/.tmux/plugins"
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm" > /dev/null
  git clone -b v2.1.3 https://github.com/catppuccin/tmux.git "$HOME/.tmux/plugins/catppuccin/tmux" > /dev/null
fi

echo "Bootstrap script finished."
