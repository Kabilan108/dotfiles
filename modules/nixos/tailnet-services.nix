{
  config,
  lib,
  pkgs,
  ...
}:
let
  services = config.selfhost.tailnetServices;
in
{
  options.selfhost.tailnetServices = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options.port = lib.mkOption {
          type = lib.types.port;
          description = "Localhost port the service backend listens on.";
        };
      }
    );
    default = { };
    description = "Tailscale Services advertised by this node. Keys must match service names defined in the tailnet policy.";
  };

  config = lib.mkIf (services != { }) {
    systemd.services.tailscale-serve-config = {
      description = "Apply Tailscale Services serve configuration";
      after = [ "tailscaled.service" ];
      requires = [ "tailscaled.service" ];
      wantedBy = [ "multi-user.target" ];
      restartTriggers = [ (builtins.toJSON services) ];
      path = [
        pkgs.tailscale
        pkgs.jq
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        for _ in $(seq 1 30); do
          if tailscale status --json | jq -e '.BackendState == "Running"' >/dev/null 2>&1; then
            break
          fi
          sleep 1
        done

        declared=(${lib.concatStringsSep " " (lib.attrNames services)})

        for svc in $(tailscale serve status --json | jq -r '.Services // {} | keys[] | ltrimstr("svc:")'); do
          if [[ ! " ''${declared[*]} " == *" $svc "* ]]; then
            tailscale serve clear "svc:$svc"
          fi
        done

        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (
            name: svc: "tailscale serve --service=svc:${name} --https=443 http://127.0.0.1:${toString svc.port}"
          ) services
        )}
      '';
    };
  };
}
