{
  pkgs,
  lib,
  config,
  ...
}:
let
  home = config.users.users.kabilan.home;
in
{
  imports = [
    ./modules/agents.nix
    ./modules/systemd-dictator.nix
  ];

  users.users.kabilan = {
    isNormalUser = true;
    description = "Tony Kabilan Okeke";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "plugdev"
    ];
    packages = with pkgs; [
      # desktop apps
      brave
      code-cursor
      discord
      inkscape
      libreoffice-fresh
      nautilus
      obsidian
      slack
      spotify
      telegram-desktop
      vlc
      zoom-us
      zotero

      # themes
      lxappearance
      whitesur-gtk-theme
      whitesur-icon-theme

      # media/file handling
      baobab
      ffmpeg-full
      gparted
      imagemagick
      jmtpfs
      libmtp
      yt-dlp
    ];
    shell = pkgs.bashInteractive;
  };

  age.identityPaths = [ "${home}/.ssh/id_ed25519" ];
  age.secrets."secrets/env.age" = {
    file = ./secrets/env.age;
    path = "${home}/.bashenv";
    mode = "0600"; # read/write for owner only
    owner = "kabilan";
    group = "users";
  };

  environment.variables = rec {
    FZF_DEFAULT_OPTS = "--reverse";
    GTK_THEME = "WhiteSur-Dark";
    UV_LINK_MODE = "copy";
    UV_SYSTEM_PYTHON = "1";

    CAPSCREEN_OUTPUT_DIR = "$HOME/media/screencasts";
    PYREPL_PORT = "5678";

    USER_DATA = "/vault/userdata";
    FASTAI_HOME = "${USER_DATA}/fastai";
    GOPATH = "${USER_DATA}/go";
    HF_HOME = "${USER_DATA}/huggingface";
    HF_DATASETS_CACHE = "$HF_HOME/datasets";
    LLM_USER_PATH = "${USER_DATA}/datasette-llm";
    OLLAMA_MODELS = "${USER_DATA}/ollama/models";
    TORCH_HOME = "${USER_DATA}/torch";
  };

  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };
}
