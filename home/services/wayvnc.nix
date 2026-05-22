{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.services.wayvnc;

  startWayvnc = pkgs.writeShellScript "wayvnc-tailscale-start" ''
    set -eu

    TAILNET_IP="$(${pkgs.tailscale}/bin/tailscale ip -4 | ${pkgs.coreutils}/bin/head -n1)"

    exec ${pkgs.wayvnc}/bin/wayvnc "$TAILNET_IP" "${toString cfg.port}"
  '';
in
{
  options.dotfiles.services.wayvnc = {
    enable = lib.mkEnableOption "WayVNC bound to the Tailscale interface";

    port = lib.mkOption {
      type = lib.types.port;
      default = 5900;
      description = "TCP port for the WayVNC server.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.wayvnc ];

    systemd.user.services.wayvnc = {
      Unit = {
        Description = "WayVNC server bound to Tailscale";
        After = [
          "graphical-session.target"
          "network-online.target"
        ];
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        Type = "simple";
        ExecStart = startWayvnc;
        Restart = "on-failure";
        RestartSec = 5;
      };

      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
