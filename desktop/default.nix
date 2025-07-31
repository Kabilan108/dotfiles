# Set up X11 and i3wm

{ pkgs, ... }:
{
  imports = [
    ./apps/betterlockscreen.nix
    ./apps/dunst.nix
    ./apps/ghostty.nix
    ./apps/gtk.nix
    ./apps/i3.nix
    ./apps/picom.nix
    ./apps/polybar.nix
    ./apps/rofi
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

  home.file.".config/greenclip.toml".source = ../config/greenclip.toml;

  home.packages = with pkgs; [
    arandr
    autorandr
    betterlockscreen
    cherry-studio
    dunst
    feh
    flameshot
    haskellPackages.greenclip
    light
    nerd-fonts.fira-mono
    networkmanagerapplet
    picom
    pavucontrol
    playerctl
    pulseaudio
    rofi
    xclip
    xdotool
    xorg.xdpyinfo
    xorg.xev
    xorg.xrandr
  ];
}
