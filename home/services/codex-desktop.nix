{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.services.codex-desktop;
  runtimeDir = "/run/user/1000";
in
{
  options.dotfiles.services.codex-desktop = {
    enable = lib.mkEnableOption "Codex Desktop Linux user-local install helpers";

    ydotool.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to run ydotoold for Computer Use input fallback.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.codexDesktopLinux = {
      enable = true;
      linuxFeatures = [
        "frameless-titlebar"
        "remote-control-ui"
        "remote-mobile-control"
      ];
    };

    home.packages = with pkgs; [
      at-spi2-core
      grim
      ydotool
    ];

    home.sessionVariables = lib.mkIf cfg.ydotool.enable {
      YDOTOOL_SOCKET = "${runtimeDir}/.ydotool_socket";
    };

    systemd.user.sessionVariables = lib.mkIf cfg.ydotool.enable {
      YDOTOOL_SOCKET = "${runtimeDir}/.ydotool_socket";
    };

    systemd.user.services.ydotoold = lib.mkIf cfg.ydotool.enable {
      Unit = {
        Description = "ydotool input daemon";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        Type = "simple";
        ExecStart = "${lib.getExe' pkgs.ydotool "ydotoold"} --socket-path=${runtimeDir}/.ydotool_socket --socket-perm=0600";
        Restart = "on-failure";
        RestartSec = 5;
      };

      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
