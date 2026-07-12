{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.selfhost;
in
{
  imports = [
    ./discord-notify.nix
    ./executor.nix
    ./jellyfin.nix
    ./siren.nix
    ./vaultwarden.nix
  ];

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

  config = lib.mkIf (cfg.tailnetServices != { }) {
    services.tailscale.extraSetFlags = [ "--operator=kabilan" ];

    virtualisation.oci-containers.backend = "docker";

    # The services config file format (`serve set-config`) cannot express TLS
    # termination as of tailscale 1.98 -- `tcp:443` endpoints proxy plain HTTP.
    # Drive the CLI per service instead, and clear services no longer declared.
    systemd.services.tailscale-serve-config = {
      description = "Apply Tailscale Services serve configuration";
      after = [ "tailscaled.service" ];
      requires = [ "tailscaled.service" ];
      wantedBy = [ "multi-user.target" ];
      restartTriggers = [ (builtins.toJSON cfg.tailnetServices) ];
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

        declared=(${lib.concatStringsSep " " (lib.attrNames cfg.tailnetServices)})

        for svc in $(tailscale serve status --json | jq -r '.Services // {} | keys[] | ltrimstr("svc:")'); do
          if [[ ! " ''${declared[*]} " == *" $svc "* ]]; then
            tailscale serve clear "svc:$svc"
          fi
        done

        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (
            name: svc:
            "tailscale serve --service=svc:${name} --https=443 http://127.0.0.1:${toString svc.port}"
          ) cfg.tailnetServices
        )}
      '';
    };
  };
}
