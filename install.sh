#! /bin/bash
#
#       ########   #######  ######## ######## #### ##       ########  ######
#       ##     ## ##     ##    ##    ##        ##  ##       ##       ##    ##
#       ##     ## ##     ##    ##    ##        ##  ##       ##       ##
#       ##     ## ##     ##    ##    ######    ##  ##       ######    ######
#       ##     ## ##     ##    ##    ##        ##  ##       ##             ##
#       ##     ## ##     ##    ##    ##        ##  ##       ##       ##    ##
#       ########   #######     ##    ##       #### ######## ########  ######
#
# -------------------------------------------------------------------------------------

INSTALL_LOG="dotfiles.log"
USERBIN=$HOME/.local/bin
CONFDIR=$HOME/.config
DOTFILES=$(dirname $(realpath $0))

# -------------------------------------------------------------------------------------

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

install_fzf() {
  log i "installing fzf"
  mkdir -p /tmp/fzf && cd /tmp/fzf
  wget https://github.com/junegunn/fzf/releases/download/v0.56.3/fzf-0.56.3-linux_amd64.tar.gz
  tar xzvf fzf-0.56.3-linux_amd64.tar.gz
  sudo mv fzf /usr/bin/
}

install_fuse() {
  log i "installing fuse"
  sudo add-apt-repository universe
  if [[ $(lsb_release -rs) == "22.04" ]]; then
    sudo apt install libfuse2
  elif [[ $(lsb_release -rs) == "24.04" ]]; then
    sudo apt install libfuse2t64
  else
    log e "failed to install fuse: unsupported os"
  fi
}

install_gh() {
  log i "installing up gh"
  (type -p wget >/dev/null || (sudo apt update && sudo apt-get install wget -y)) \
    && sudo mkdir -p -m 755 /etc/apt/keyrings \
    && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && sudo apt update \
    && sudo apt install gh -y
}

install_node_bun() {
  log i "setting up nvm, node, bun"
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
  source $HOME/.bashrc
  nvm install 20.16.0
  curl -fsSL https://bun.sh/install | bash
}

setup_kitty() {
  log i "setting up kitty"
  curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin
  ln -sf $HOME/.local/kitty.app/bin/kitty $HOME/.local/kitty.app/bin/kitten $USERBIN
  cp \
    $HOME/.local/kitty.app/share/applications/kitty.desktop \
    $HOME/.local/kitty.app/share/applications/kitty-open.desktop \
    $HOME/.local/share/applications/
  sed -i "s|Icon=kitty|Icon=$HOME/.local/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|g" $HOME/.local/share/applications/kitty*.desktop
  sed -i "s|Exec=kitty|Exec=$HOME/.local/kitty.app/bin/kitty|g" $HOME/.local/share/applications/kitty*.desktop
  sudo update-desktop-database
  ln -s $DOTFILES/sys/kitty $CONFDIR/kitty
}

setup_docker() {
  log i "setting up docker"
  for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done

  # Add Docker's official GPG key:
  sudo apt-get update
  sudo apt-get install ca-certificates curl
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc

  # Add the repository to Apt sources:
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update

  sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  sudo groupadd docker
  sudo usermod -aG docker $USER

  sudo systemctl enable docker.service
  sudo systemctl enable containerd.service
  sudo ln -s $DOTFILES/sys/docker/daemon-gpupoor.json /etc/docker/daemon.json
}

setup_ufw() {
  log i "setting up ufw"
  sudo ufw enable
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  sudo ufw status
}

setup_tailscale() {
  log i "setting up tailscale"
  curl -fsSL https://tailscale.com/install.sh | sh
  sudo tailscale up
  tailscale ip -4
}

install_zoom() {
  log i "installing zoom"
  mkdir -p /tmp/zoom && cd /tmp/zoom
  wget https://zoom.us/client/6.2.11.5069/zoom_amd64.deb
  sudo apt-get install libxcb-xtest0
  sudo dpkg -i zoom_amd64.deb
}

install_zotero() {
  log i "installing zotero"
  mkdir -p /tmp/zotero && cd /tmp/zotreo
  wget -O zotero.tar.bz2 'https://www.zotero.org/download/client/dl?channel=release&platform=linux-x86_64&version=7.0.10'
  tar xvf zotero.tar.bz2
  sudo mv Zotero_linux-x86_64/ /opt/zotero
  cd /opt/zotero/
  bash /opt/zotero/set_launcher_icon
  ln -s /opt/zotero/zotero.desktop $HOME/.local/share/applications/zotero.desktop
  sudo update-desktop-database
}

install_brave() {
  log i "installing brave"
  sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main"|sudo tee /etc/apt/sources.list.d/brave-browser-release.list
  sudo apt update
  sudo apt install brave-browser
}

install_inkscape() {
  log i "installing inkscape"
  sudo add-apt-repository universe
  sudo add-apt-repository ppa:inkscape.dev/stable
  sudo apt-get update
  sudo apt install inkscape
}

install_pia() {
  log i "installing inkscape"
  mkdir -p /tmp/pia && cd /tmp/pia
  wget https://installers.privateinternetaccess.com/download/pia-linux-3.6.1-08339.run
  bash ./pia-linux-3.6.1-08339.run
}

install_jetbrains_toolbox() {
  log i "installing jetbrains"
  mkdir -p /tmp/jetbrains && cd /tmp/jetbrains
  wget https://download.jetbrains.com/toolbox/jetbrains-toolbox-2.5.2.35332.tar.gz
  tar xzf jetbrains-toolbox-2.5.2.35332.tar.gz
  mv jetbrains-toolbox-2.5.2.35332/jetbrains-toolbox  $USERBIN/
}

# -------------------------------------------------------------------------------------

log i "updating packages"
sudo apt update
sudo apt upgrade -y

log i "install dependencies"
sudo apt install -y \
  git \
  make \
  cmake \
  curl \
  wget \
  htop \
  ffmpeg \
  openvpn \
  bzip2

setup_ufw
setup_tailscale

install_fzf
install_fuse
install_gh
install_node_bun

log i "setting up rust stuff"
curl https://sh.rustup.rs -sSf | sh
curl -LsSf https://astral.sh/uv/install.sh | sh
cargo install ripgrep
cargo install fd-find
cargo install sd

log i "installing python tools"
uv tool install pre-commit
uv tool install ipython
uv tool install ruff

mkdir -p $USERBIN $CONFDIR

log i "setting up script/*"
ln -s $DOTFILES/scripts $USERBIN/scripts

log i "setting up de/*"
bash $DOTFILES/de/setup.sh
for d in $(find $DOTFILES/de -mindepth 1 -maxdepth 1 -type d); do
  ln -s $d "$CONFDIR/$(basename $d)"
done

log i "setting up editor/*"
bash $DOTFILES/editor/setup.sh
ln -s $DOTFILES/editor/vimrc $HOME/.vimrc
ln -s $DOTFILES/editor/vimrc $HOME/.ideavimrc
ln -s $DOTFILES/editor/nvim $CONFDIR/nvim
mkdir -p $CONFDIR/Cursor/User
for x in $(find $DOTFILES/editor/vscode -mindepth 1 -maxdepth 1); do
  ln -s $x "$CONFDIR/Cursor/User/$(basename $x)"
done

log i "setting up services/*"
# TODO: get the timer to actually work
systemctl --user enable $DOTFILES/services/update-cursor.service
systemctl --user enable $DOTFILES/services/update-cursor.timer
systemctl --user start update-cursor.timer
systemctl --user daemon-reload

log i "setting up sys/*"
ln -s $DOTFILES/sys/ipython $CONFDIR/ipython
ln -s $DOTFILES/sys/ruff $CONFDIR/ruff
rm $HOME/.bashrc && ln -s $DOTFILES/sys/bashrc $HOME/.bashrc
rm $HOME/.gitconfig && ln -s $DOTFILES/sys/gitconfig $HOME/.gitconfig
rm $CONFDIR/user-dirs.dirs && ln -s $DOTFILES/sys/user-dirs.dirs $CONFDIR/user-dirs.dirs
setup_kitty
setup_docker

log i "installing desktop programs"
sudo snap install libreoffice slack discord telegram-desktop whatsapp-linux-app thunderbird spotify
sudo snap install --classic obsidian
sudo snap install --classic kotlin
install_brave
install_inkscape
install_jetbrains_toolbox
install_pia
install_zoom
install_zotero
