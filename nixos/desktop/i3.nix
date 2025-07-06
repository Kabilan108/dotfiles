# Set up X11 and i3wm

{ pkgs, ... }:
{
  services.displayManager.defaultSession = "none+i3";

  security.pam.services.i3lock.enable = true;

  services.xserver = {
    enable = true;

    displayManager = {
      startx.enable = false;
      gdm.enable = true;
      gdm.wayland = false;
    };

    desktopManager.xterm.enable = false;

    windowManager.i3 = {
      enable = true;
      extraPackages = with pkgs; [
        (polybar.override {
          i3Support = true;
          pulseSupport = true;
        })

        arandr
        autorandr
        betterlockscreen
        dunst
        feh
        flameshot
        light
        networkmanagerapplet
        picom
        pavucontrol
        playerctl
        polybar
        pulseaudio
        rofi
        xorg.xdpyinfo
        xorg.xev
        xorg.xrandr
      ];
    };

    xkb = {
      layout = "us";
      variant = "";
    };
  };

  fonts.packages = with pkgs; [
    nerd-fonts.fira-mono
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
}
