{
  config,
  lib,
  ...
}:
{
  imports = [
    ../tailnet-services.nix
    ./blocky.nix
    ./sera.nix
    ./cliproxyapi.nix
    ./executor.nix
    ./hark.nix
    ./jellyfin.nix
    ./library.nix
    ./siren.nix
    ./vaultwarden.nix
  ];

  config = lib.mkIf (config.selfhost.tailnetServices != { }) {
    virtualisation.oci-containers.backend = "docker";
  };
}
