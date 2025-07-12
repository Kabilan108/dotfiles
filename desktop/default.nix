# Set up X11 and i3wm

{ pkgs, ... }:
{
  imports = [
    ./apps/betterlockscreen.nix
    ./apps/ghostty.nix
    ./apps/i3.nix
    ./apps/picom.nix
    ./apps/polybar.nix
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
    ".config/dunst".source = ./config/dunst;
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
    pulseaudio
    rofi
    xorg.xdpyinfo
    xorg.xev
    xorg.xrandr
  ];
}
