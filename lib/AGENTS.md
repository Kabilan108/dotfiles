# Fleet registry notes

- Keep `hosts.jacurutu.keys.human` in `fleet.nix` to the YubiKey sk keys. yk-nfc travels with Tony and yk-nano is the backup in storage. The id_ed25519 key on each host is the agenix identity (`age.identityPaths` in `user.nix`), never a login key.
- When you add a host to `deploy.gatedAgentLogins`, put sessionizer in that host's system packages. The gated agent key can only run deploy-gate, which serves the sessionizer inventory from there.
