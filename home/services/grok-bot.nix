{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.services.grok-bot;
in
{
  options.dotfiles.services.grok-bot = {
    enable = lib.mkEnableOption "the official Grok Bot desktop app";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.grok-bot ];

    xdg.mimeApps.defaultApplications = {
      "x-scheme-handler/grokbot" = "grok-bot.desktop";
      "x-scheme-handler/sand" = "grok-bot.desktop";
    };
  };
}
