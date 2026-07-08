let
  sietch = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDW1t7U7qDPNYEVWqnxivPK21jkOM5OFwQRmlrQh7XoE kabilan@sietch";
  jacurutu = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPN/jpn1y7lmxhrBSmApiVvA+H2YN3AFkczBJbKIGVUe kabilan@jacurutu";
in
{
  "secrets/env.age".publicKeys = [
    sietch
    jacurutu
  ];
  "secrets/rclone.conf".publicKeys = [
    sietch
    jacurutu
  ];
  "secrets/dictator-env".publicKeys = [
    sietch
    jacurutu
  ];
  "secrets/gog-creds".publicKeys = [
    sietch
    jacurutu
  ];
  "secrets/netrc.age".publicKeys = [
    sietch
    jacurutu
  ];

  "secrets/moberg-vpn/key.age".publicKeys = [
    sietch
    jacurutu
  ];
  "secrets/moberg-vpn/ta.age".publicKeys = [
    sietch
    jacurutu
  ];
  "secrets/moberg-vpn/cert.age".publicKeys = [
    sietch
    jacurutu
  ];
  "secrets/moberg-vpn/ca.age".publicKeys = [
    sietch
    jacurutu
  ];

  "secrets/syncthing/jacurutu-cert.age".publicKeys = [ jacurutu ];
  "secrets/syncthing/jacurutu-key.age".publicKeys = [ jacurutu ];
  "secrets/syncthing/sietch-cert.age".publicKeys = [ sietch ];
  "secrets/syncthing/sietch-key.age".publicKeys = [ sietch ];

  "secrets/selfhost/executor-env.age".publicKeys = [ sietch ];
  "secrets/selfhost/siren-env.age".publicKeys = [ sietch ];
  "secrets/selfhost/vaultwarden-env.age".publicKeys = [ sietch ];
}
