# Credential services go here: Vaultwarden and Executor move in stage 5 of
# the fleet security plan, after backups. Each one listens on loopback and
# sets selfhost.tailnetServices.<name>.port; tag:credentials is the only tag
# the tailnet policy lets advertise svc:vault and svc:executor. Their new
# secrets are encrypted to this host and the YubiKey age recipients only
# (secrets.nix).
{
  imports = [ ../../modules/nixos/tailnet-services.nix ];
}
