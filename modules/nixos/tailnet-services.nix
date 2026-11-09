{
  config,
  lib,
  pkgs,
  ...
}:
let
  services = config.selfhost.tailnetServices;
  tailscale = config.services.tailscale.package;
  systemctl = "${config.systemd.package}/bin/systemctl";

  boundServices = lib.filterAttrs (_: svc: svc.bindsTo != null) services;
  unboundServices = lib.filterAttrs (_: svc: svc.bindsTo == null) services;

  waitForTailscale = ''
    for _ in $(seq 1 30); do
      if tailscale status --json | jq -e '.BackendState == "Running"' >/dev/null 2>&1; then
        break
      fi
      sleep 1
    done
  '';

  serve =
    name: svc:
    "tailscale serve --service=svc:${name} --https=443 http://127.0.0.1:${toString svc.port}";
in
{
  options.selfhost.tailnetServices = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options.port = lib.mkOption {
          type = lib.types.port;
          description = "Localhost port the service backend listens on.";
        };
        options.bindsTo = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "vaultwarden.service";
          description = ''
            Advertise the service only while this unit is active. Null
            advertises it whenever tailscaled runs, backend or not.
          '';
        };
      }
    );
    default = { };
    description = "Tailscale Services advertised by this node. Keys must match service names defined in the tailnet policy.";
  };

  config = lib.mkIf (services != { }) {
    # The services config file format (`serve set-config`) cannot express TLS
    # termination as of tailscale 1.98 -- `tcp:443` endpoints proxy plain HTTP.
    # Drive the CLI per service instead, and clear services no longer declared.
    systemd.services = {
      tailscale-serve-config = {
        description = "Apply Tailscale Services serve configuration";
        after = [ "tailscaled.service" ];
        requires = [ "tailscaled.service" ];
        wantedBy = [ "multi-user.target" ];
        restartTriggers = [ (builtins.toJSON services) ];
        path = [
          tailscale
          pkgs.jq
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          ${waitForTailscale}

          declared=(${lib.concatStringsSep " " (lib.attrNames services)})

          for svc in $(tailscale serve status --json | jq -r '.Services // {} | keys[] | ltrimstr("svc:")'); do
            if [[ ! " ''${declared[*]} " == *" $svc "* ]]; then
              tailscale serve clear "svc:$svc"
            fi
          done

          ${lib.concatStringsSep "\n" (lib.mapAttrsToList serve unboundServices)}

          ${
            # tailscaled restores the last serve config at boot, so a bound
            # service whose backend no longer runs (a power cut, a rollback)
            # would come back advertised. Its own unit re-adds it once the
            # backend is up.
            lib.concatStringsSep "\n" (
              lib.mapAttrsToList (
                name: svc: "${systemctl} is-active --quiet ${svc.bindsTo} || tailscale serve clear svc:${name}"
              ) boundServices
            )
          }
        '';
      };
    }
    // lib.mapAttrs' (
      name: svc:
      lib.nameValuePair "tailscale-serve-${name}" {
        description = "Advertise svc:${name} while ${svc.bindsTo} runs";
        wantedBy = [ svc.bindsTo ];
        bindsTo = [ svc.bindsTo ];
        requires = [ "tailscaled.service" ];
        after = [
          svc.bindsTo
          "tailscaled.service"
          "tailscale-serve-config.service"
        ];
        path = [
          tailscale
          pkgs.jq
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStop = "-${tailscale}/bin/tailscale serve clear svc:${name}";
        };
        script = ''
          ${waitForTailscale}
          ${serve name svc}
        '';
      }
    ) boundServices;
  };
}
