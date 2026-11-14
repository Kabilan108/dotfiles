# Credential services, moved from sietch in stage 5 of the fleet security plan
# (docs/tleilax-credentials-move.md). Each listens on loopback and is
# advertised only while its backend runs (selfhost.tailnetServices.<name>.bindsTo);
# tag:credentials is the only tag the tailnet policy lets advertise svc:vault
# and svc:executor. Their secrets are encrypted to this host and the YubiKey
# age recipients only (secrets.nix).
{
  imports = [
    ../../modules/nixos/tailnet-services.nix
    ./executor.nix
    ./vaultwarden.nix
  ];
}
