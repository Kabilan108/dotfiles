# Vaultwarden, moved here from sietch in stage 5
# (docs/tleilax-credentials-move.md). It starts only once the copied database
# is in place: on an empty data directory it would make a new, empty vault,
# and tailnet clients would sync against it.
{
  config,
  lib,
  options,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.vaultwarden;
  # The module's data directory since stateVersion 24.11.
  database = "/var/lib/vaultwarden/db.sqlite3";

  # A plain-text token would work too, so the placeholder would open the
  # admin page to anyone who guessed it.
  checkAdminToken = pkgs.writeShellScript "vaultwarden-check-admin-token" ''
    case "''${ADMIN_TOKEN-}" in
      '$argon2id$'*) ;;
      *)
        echo "vaultwarden: ADMIN_TOKEN must be an Argon2id PHC string from 'vaultwarden hash'" >&2
        exit 1
        ;;
    esac
  '';
in
{
  options.dotfiles.vaultwarden.environmentFile = lib.mkOption {
    type = lib.types.str;
    description = "Environment file that sets ADMIN_TOKEN to an Argon2id PHC string.";
  };

  config = lib.mkMerge [
    # The VM test has no agenix and passes its own file.
    (lib.optionalAttrs (options ? age) {
      age.secrets.vaultwarden-env.file = ../../secrets/tleilax/vaultwarden-env.age;
      dotfiles.vaultwarden.environmentFile = lib.mkDefault config.age.secrets.vaultwarden-env.path;
    })
    {
      selfhost.tailnetServices.vault = {
        port = 8222;
        bindsTo = "vaultwarden.service";
      };

      services.vaultwarden = {
        enable = true;
        environmentFile = cfg.environmentFile;
        config = {
          DOMAIN = "https://vault.sole-pierce.ts.net";
          SIGNUPS_ALLOWED = false;
          ROCKET_ADDRESS = "127.0.0.1";
          ROCKET_PORT = 8222;
        };
      };

      systemd.services.vaultwarden = {
        unitConfig.ConditionPathExists = database;
        serviceConfig.ExecStartPre = [ checkAdminToken ];
      };
    }
  ];
}
