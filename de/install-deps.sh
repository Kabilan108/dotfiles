#! /bin/bash

sudo apt-get update

sudo apt install -y \
    libdbus-1-dev \
    libx11-dev \
    libxinerama-dev \
    libxrandr-dev \
    libxss-dev \
    libglib2.0-dev \
    libpango1.0-dev \
    libgtk-3-dev \
    libxdg-basedir-dev \
    libnotify-dev \
    libgdk-pixbuf2.0-dev \
    libwayland-dev \
    wayland-protocols \
    libxext-dev \
    libxss-dev

mkdir -p /tmp/dunst
cd /tmp/dunst
git clone https://github.com/dunst-project/dunst.git
cd dunst
make
sudo make install

sudo apt-get install -y \
  polybar \
  rofi \
  feh \
  playerctl \
  pactl \
  light \
  picom

sudo update-alternatives --install /usr/bin/editor editor /opt/nvim-linux64/bin/nvim 60
sudo update-alternatives --config editor
