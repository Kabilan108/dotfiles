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
    ./hark.nix
    ./jellyfin.nix
    ./library.nix
    ./llamacpp.nix
    ./siren.nix
  ];

  config = lib.mkIf (config.selfhost.tailnetServices != { }) {
    virtualisation.oci-containers.backend = "docker";
  };
}
