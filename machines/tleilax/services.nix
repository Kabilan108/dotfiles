# Credential services. Each one listens on loopback; a service reachable from
# the tailnet also sets selfhost.tailnetServices.<name>.port, and
# tag:credentials is the only tag the tailnet policy lets advertise it. Their
# secrets are encrypted to this host and the YubiKey age recipients only
# (secrets.nix). Executor v1 stays on sietch until v2 here replaces it.
{
  imports = [
    ../../modules/nixos/tailnet-services.nix
    ./atlas.nix
    ./executor.nix
  ];
}
