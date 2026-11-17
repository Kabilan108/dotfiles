# Backups

Restic stores encrypted backups on the NAS. Coverage and exclusions live in each
host's `dotfiles.backup.jobs`: [jacurutu](../machines/jacurutu/default.nix),
[sietch](../machines/sietch/default.nix). Shared behavior is in
[modules/nixos/backup](../modules/nixos/backup/default.nix).
See [NAS policy](nas-network-policy.md) for access and NAS snapshot recovery.

## Run and inspect

Run these on the machine whose backup you want:

```sh
sudo systemctl start restic-backups-files
journalctl -u restic-backups-files
cat /var/lib/backup-status/*.json
sudo restic-files snapshots
```

`restic-files` and `restic-services` select that host's repository and credentials.
Use the scheduled service to run its preparation and status hooks. For a manual
Restic command, first check that `snapshots` opens the existing NAS repository.
Never use `init` to work around an unreachable or missing repository.

## Restore

Restore into a separate directory, then inspect and compare before replacing
anything live. Use a specific snapshot ID when testing a particular backup:

```sh
sudo restic-files restore SNAPSHOT_ID --target /tmp/restore \
  --include /vault/notes/coppermind/some-note.md
```

Files appear beneath the target with their snapshot paths. For service databases,
restore the staged copy under `/var/lib/backup-staging/services/<name>/`, run
`sqlite3 <copy> 'PRAGMA integrity_check;'`, then test the application. Executor
also needs its original `EXECUTOR_SECRET_KEY` to read encrypted data.

Vaultwarden was retired in favour of 1Password in November 2026, and sietch's
`services` job no longer backs it up. Snapshots taken before then still hold
`/var/lib/vaultwarden` and the staged `vaultwarden` database.

Close browsers for the initial browser-profile backup and recovery test. Ordinary
file backups taken while a browser is open may contain inconsistent databases;
a profile alone may not recover cookies or passwords tied to the desktop keyring.

If the machine is lost, mount its NAS share on another Linux machine and run
`restic -r <mount>/restic restore SNAPSHOT_ID --target <dir>`. Get the NAS login
and Restic password from 1Password or the paper recovery sheet. If the live
repository was damaged, recover an earlier NAS snapshot through DSM first.

## One-off archive

```sh
sudo restic-files snapshots
sudo restic-files backup --tag archive /path/to/preserve
```

Manual backups do not inherit the scheduled job's source list or exclusions.
Pass `--exclude` or `--exclude-file` explicitly. Preview with `--dry-run -vv`.
Require exit 0; exit 3 means the snapshot is incomplete. Record the snapshot ID
and restore representative files before relying on it. Future pruning must keep
snapshots tagged `archive`.

## Credentials and first setup

Keep the NAS share, login and Restic password in the machine's 1Password item
and on the paper recovery sheet. Edit agenix secrets on jacurutu with a YubiKey:

```sh
agenix -e secrets/backup/<host>-smb.age -i ~/.config/age/yk-nfc.txt
agenix -e secrets/backup/<host>-restic.age -i ~/.config/age/yk-nfc.txt
```

Use `yk-nano.txt` with the other key. The SMB secret contains `username=` and
`password=` lines; the Restic secret contains the repository password.

For a new host, register its host public key and secret recipients, configure its
NAS account and job, then deploy. Initialize the repository once, deliberately,
with `sudo restic-files init`. Run the service and verify a restore, failure
alerts, and remote status delivery before calling setup complete.
