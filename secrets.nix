let
  sietch = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDW1t7U7qDPNYEVWqnxivPK21jkOM5OFwQRmlrQh7XoE kabilan@sietch";
  jacurutu = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPN/jpn1y7lmxhrBSmApiVvA+H2YN3AFkczBJbKIGVUe kabilan@jacurutu";
in
{
  "secrets/bashenv.age".publicKeys = [
    sietch
    jacurutu
  ];
  "secrets/discord-notify.age".publicKeys = [
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
  "secrets/foobar.age".publicKeys = [
    sietch
  ];

  "secrets/moberg/credentials.env.age".publicKeys = [
    sietch
    jacurutu
  ];
  "secrets/moberg/secrets.env.age".publicKeys = [
    sietch
    jacurutu
  ];

  "secrets/moberg/vpn/key.age".publicKeys = [
    sietch
    jacurutu
  ];
  "secrets/moberg/vpn/ta.age".publicKeys = [
    sietch
    jacurutu
  ];
  "secrets/moberg/vpn/cert.age".publicKeys = [
    sietch
    jacurutu
  ];
  "secrets/moberg/vpn/ca.age".publicKeys = [
    sietch
    jacurutu
  ];

  "secrets/syncthing/jacurutu-cert.age".publicKeys = [ jacurutu ];
  "secrets/syncthing/jacurutu-key.age".publicKeys = [ jacurutu ];
  "secrets/syncthing/sietch-cert.age".publicKeys = [ sietch ];
  "secrets/syncthing/sietch-key.age".publicKeys = [ sietch ];

  "secrets/ssh/private-config.age".publicKeys = [
    sietch
    jacurutu
  ];

  "secrets/ssh/sietch/github.age".publicKeys = [ sietch ];
  "secrets/ssh/sietch/moberg-bitbucket.age".publicKeys = [ sietch ];
  "secrets/ssh/sietch/moberg-devserver3.age".publicKeys = [ sietch ];
  "secrets/ssh/sietch/moberg-devserver4.age".publicKeys = [ sietch ];
  "secrets/ssh/sietch/agent-sietch.age".publicKeys = [ sietch ];

  "secrets/ssh/jacurutu/github.age".publicKeys = [ jacurutu ];
  "secrets/ssh/jacurutu/moberg-bitbucket.age".publicKeys = [ jacurutu ];
  "secrets/ssh/jacurutu/moberg-devserver3.age".publicKeys = [ jacurutu ];
  "secrets/ssh/jacurutu/moberg-devserver4.age".publicKeys = [ jacurutu ];
  "secrets/ssh/jacurutu/moberg-mobile-dev.age".publicKeys = [ jacurutu ];
  "secrets/ssh/jacurutu/agent-jacurutu.age".publicKeys = [ jacurutu ];
  "secrets/ssh/jacurutu/yk-nfc.age".publicKeys = [ jacurutu ];
  "secrets/ssh/jacurutu/yk-nano.age".publicKeys = [ jacurutu ];

  "secrets/selfhost/executor-env.age".publicKeys = [ sietch ];
  "secrets/selfhost/cliproxyapi-env.age".publicKeys = [ sietch ];
  "secrets/selfhost/siren-env.age".publicKeys = [ sietch ];
  "secrets/selfhost/vaultwarden-env.age".publicKeys = [ sietch ];
}
