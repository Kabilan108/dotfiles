let
  fleet = import ./lib/fleet.nix;
  sietch = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDW1t7U7qDPNYEVWqnxivPK21jkOM5OFwQRmlrQh7XoE kabilan@sietch";
  jacurutu = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPN/jpn1y7lmxhrBSmApiVvA+H2YN3AFkczBJbKIGVUe kabilan@jacurutu";
  # tleilax's files: its SSH host key plus both YubiKey age identities, and no
  # user keys. The rules appear only once both identities are recorded, so
  # nothing gets encrypted without them (docs/tleilax-install.md).
  tleilax = [ fleet.hosts.tleilax.hostPubkey ] ++ fleet.ageRecipients;
  tleilaxReady = builtins.length fleet.ageRecipients >= 2;
  backupSietch = [ fleet.hosts.sietch.hostPubkey ] ++ fleet.ageRecipients;
  backupJacurutu = [ fleet.hosts.jacurutu.hostPubkey ] ++ fleet.ageRecipients;
in
(
  if tleilaxReady then
    {
      "secrets/hark/tleilax-alerts.curl.age".publicKeys = tleilax;
    }
  else
    { }
)
// {
  # Root-only host key plus both YubiKey age identities, never a user key
  # (docs/backups.md).
  "secrets/backup/sietch-smb.age".publicKeys = backupSietch;
  "secrets/backup/sietch-restic.age".publicKeys = backupSietch;
  "secrets/backup/jacurutu-smb.age".publicKeys = backupJacurutu;
  "secrets/backup/jacurutu-restic.age".publicKeys = backupJacurutu;
  "secrets/agent-browser-encryption-key.age".publicKeys = [
    sietch
    jacurutu
  ];
  "secrets/pagebin/env.age".publicKeys = [
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
  "secrets/gogcli/credentials-json.age".publicKeys = [
    sietch
    jacurutu
  ];
  "secrets/gogcli/keyring-env.age".publicKeys = [
    sietch
    jacurutu
  ];
  "secrets/nix-access-tokens.age".publicKeys = [
    sietch
    jacurutu
  ];
  "secrets/hark/sietch-config.json.age".publicKeys = [ sietch ];
  "secrets/hark/jacurutu-config.json.age".publicKeys = [ jacurutu ];
  "secrets/hark/e-boost-automations.curl.age".publicKeys = [
    sietch
    jacurutu
  ];
  "secrets/hark/fleet-maintenance.curl.age".publicKeys = [
    sietch
    jacurutu
  ];
  # Decrypted only on sietch; jacurutu's key is a second way to recover them.
  "secrets/hark/android-release-keystore.age".publicKeys = [
    sietch
    jacurutu
  ];
  "secrets/hark/android-signing-properties.age".publicKeys = [
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

  "secrets/moberg/vpn/key.age".publicKeys = [ jacurutu ];
  "secrets/moberg/vpn/sietch-key.age".publicKeys = [ sietch ];
  "secrets/moberg/vpn/ta.age".publicKeys = [
    sietch
    jacurutu
  ];
  "secrets/moberg/vpn/cert.age".publicKeys = [ jacurutu ];
  "secrets/moberg/vpn/sietch-cert.age".publicKeys = [ sietch ];
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
  "secrets/ssh/jacurutu/moberg-status-jacurutu.age".publicKeys = [ jacurutu ];
  "secrets/ssh/jacurutu/yk-nfc.age".publicKeys = [ jacurutu ];
  "secrets/ssh/jacurutu/yk-nano.age".publicKeys = [ jacurutu ];
  "secrets/ssh/jacurutu/yk-nfc-deploy.age".publicKeys = [ jacurutu ];
  "secrets/ssh/jacurutu/yk-nano-deploy.age".publicKeys = [ jacurutu ];

  "secrets/selfhost/executor-env.age".publicKeys = [ sietch ];
  "secrets/selfhost/blocky-denylist.age".publicKeys = [ sietch ];
  "secrets/selfhost/cliproxyapi-env.age".publicKeys = [ sietch ];
  "secrets/selfhost/t3-tunnel-env.age".publicKeys = [ sietch ];
  "secrets/selfhost/siren-env.age".publicKeys = [ sietch ];
  "secrets/selfhost/vaultwarden-env.age".publicKeys = [ sietch ];
  "secrets/selfhost/hark-env.age".publicKeys = [ sietch ];
  "secrets/selfhost/hark-fcm-service-account.age".publicKeys = [ sietch ];

  "secrets/executor/russ-playlist-sync.age".publicKeys = [ sietch jacurutu ];
  "secrets/executor/meeting-minutes.age".publicKeys = [ sietch jacurutu ];
}
