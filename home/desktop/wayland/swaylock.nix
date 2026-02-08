{ config, theme, pkgs, ... }:
let
  palette = theme.palette;
in
{
  programs.swaylock = {
    enable = true;
    package = pkgs.swaylock-effects;
  };

  xdg.configFile."swaylock/config".text = ''
    image=${config.wallpaper.lockscreen}
    fade-in=0

    clock
    timestr=%I:%M
    datestr=
    font=FiraMono Nerd Font
    font-size=28

    indicator
    indicator-radius=100
    indicator-thickness=8

    ring-color=${palette.base05}cc
    inside-color=${palette.base00}cc
    text-color=${palette.base05}
    line-color=00000000
    separator-color=00000000
    key-hl-color=${palette.base0B}
    bs-hl-color=${palette.base08}

    ring-ver-color=${palette.base0B}cc
    inside-ver-color=${palette.base00}cc
    text-ver-color=${palette.base05}

    ring-wrong-color=${palette.base08}cc
    inside-wrong-color=${palette.base00}cc
    text-wrong-color=${palette.base08}

    ring-clear-color=${palette.base0A}cc
    inside-clear-color=${palette.base00}cc
    text-clear-color=${palette.base05}

    show-failed-attempts
  '';
}
