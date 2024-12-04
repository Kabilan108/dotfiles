#! /bin/bash

install_neovim() {
  mkdir -p /tmp/nvim && cd /tmp/nvim
  wget https://github.com/neovim/neovim/releases/download/v0.10.2/nvim-linux64.tar.gz
  tar xzf nvim-linux64.tar.gz
  sudo mv nvim-linux64 /opt/

  # TODO: neovim dependencies
}

install_cursor() {
  mkdir $HOME/.local/bin/cursor
  $HOME/.local/bin/scripts/update-cursor
}

install_neovim
install_cursor
sudo update-alternatives --install /usr/bin/editor editor /opt/nvim-linux64/bin/nvim 60
sudo update-alternatives --config editor
