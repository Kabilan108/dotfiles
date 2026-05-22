{ config, lib, ... }:
{
  stylix.targets.btop.enable = true;

  programs.btop = {
    enable = true;
    settings = {
      theme_background = false;
    };
    themes.stylix =
      with config.lib.stylix.colors.withHashtag;
      lib.mkAfter ''
        theme[div_line]="${base04}"
      '';
  };
}
