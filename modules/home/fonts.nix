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

  home.packages = [
    pkgs.nerd-fonts.fira-mono
    pkgs.nerd-fonts.jetbrains-mono
    pkgs.inter
    pkgs.ibm-plex
    pkgs.material-symbols
  ];
}
