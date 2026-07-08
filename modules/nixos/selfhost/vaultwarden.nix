{ config, ... }:
{
  age.secrets.selfhost-vaultwarden-env.file = ../../../secrets/selfhost/vaultwarden-env.age;

  selfhost.tailnetServices.vault.port = 8222;

  services.vaultwarden = {
    enable = true;
    # ADMIN_TOKEN lives here
    environmentFile = config.age.secrets.selfhost-vaultwarden-env.path;
    config = {
      DOMAIN = "https://vault.sole-pierce.ts.net";
      SIGNUPS_ALLOWED = false;
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
    };
  };
}
