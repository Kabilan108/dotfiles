# Set up X11 and i3wm

{ pkgs, theme, ... }:
{
  imports = [
    ./apps/ghostty.nix
    ./apps/i3.nix
  ];

  fonts.fontconfig = {
    enable = true;
    defaultFonts = {
      serif = [ "Noto Serif" ];
      sansSerif = [ "Noto Sans" ];
      monospace = [
        "FiraMono Nerd Font"
        "Fira Mono"
      ];
    };
  };

  home.file = {
    ".config/betterlockscreen".source = ./config/betterlockscreen;
    ".config/dunst".source = ./config/dunst;
    # ".config/i3".source = ./config/i3;
    ".config/picom".source = ./config/picom;
    ".config/polybar".source = ./config/polybar;
    ".config/rofi".source = ./config/rofi;

    ".config/vscode".source = ./config/vscode;
    ".config/Cursor/User/extensions.json".source = ./config/vscode/extensions.json;
    ".config/Cursor/User/keybindings.json".source = ./config/vscode/keybindings.json;
    ".config/Cursor/User/settings.json".source = ./config/vscode/settings.json;
    ".config/Cursor/User/snippets".source = ./config/vscode/snippets;
  };

  home.packages = with pkgs; [
    arandr
    autorandr
    betterlockscreen
    cherry-studio
    dunst
    feh
    flameshot
    light
    nerd-fonts.fira-mono
    networkmanagerapplet
    picom
    pavucontrol
    playerctl
    (polybar.override {
      i3Support = true;
      pulseSupport = true;
    })
    pulseaudio
    rofi
    xorg.xdpyinfo
    xorg.xev
    xorg.xrandr
  ];
}
