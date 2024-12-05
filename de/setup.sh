#! /bin/bash

install_deps() {
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
}

install_i3() {
  /usr/lib/apt/apt-helper download-file https://debian.sur5r.net/i3/pool/main/s/sur5r-keyring/sur5r-keyring_2024.03.04_all.deb keyring.deb SHA256:f9bb4340b5ce0ded29b7e014ee9ce788006e9bbfe31e96c09b2118ab91fca734
  sudo apt install ./keyring.deb
  echo "deb http://debian.sur5r.net/i3/ $(grep '^DISTRIB_CODENAME=' /etc/lsb-release | cut -f2 -d=) universe" | sudo tee /etc/apt/sources.list.d/sur5r-i3.list
  sudo apt update
  sudo apt install i3
}

install_dunst() {
  mkdir -p /tmp/dunst
  cd /tmp/dunst
  git clone https://github.com/dunst-project/dunst.git
  cd dunst
  make
  sudo make install
}

sudo apt-get update

install_deps
install_i3
install_dunst

sudo apt-get install -y \
  polybar \
  rofi \
  feh \
  playerctl \
  pulseaudio-utils \
  light \
  picom
