let
  # using the local id_ed25519 keys
  sietch = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDW1t7U7qDPNYEVWqnxivPK21jkOM5OFwQRmlrQh7XoE kabilan@sietch";
  # using /etc/ssh/ssh_host_ed25519_key.pub from the server
  remote = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINw1nu9dpsmy5B7fFHtctGOjhbtusjYvo6DJZvno02tx root@nixos";
in
{
  "env.age".publicKeys = [
    sietch
    remote
  ];
}
