{ pkgs, ... }:
{
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

  home.packages = [ pkgs.nerd-fonts.fira-mono ];
}
