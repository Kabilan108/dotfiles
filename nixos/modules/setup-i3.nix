# Set up X11 and i3wm

{ pkgs, ... }:
{
  services.displayManager.defaultSession ="none+i3";

  services.xserver = {
    enable = true;

    displayManager = {
      startx.enable = false;
      gdm.enable = true;
    };

    desktopManager.xterm.enable = false;

    windowManager.i3 = {
      enable = true;
      extraPackages = with pkgs; [
        (polybar.override { pulseSupport = true; })

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
    (nerdfonts.override { fonts = [ "FiraMono" ]; })
    fira-mono
  ];

  fonts.fontconfig = {
    enable = true;
    defaultFonts = {
      serif = [ "Noto Serif" ];
      sansSerif = [ "Noto Sans" ];
      monospace = ["FiraMono Nerd Font" "Fira Mono" ];
    };
  };
}
