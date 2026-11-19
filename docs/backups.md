# Backups

Restic stores encrypted backups on the NAS. Coverage and exclusions live in each
host's `dotfiles.backup.jobs`: [jacurutu](../machines/jacurutu/default.nix),
[sietch](../machines/sietch/default.nix), [tleilax](../machines/tleilax/backup.nix).
Shared behavior is in [modules/nixos/backup](../modules/nixos/backup/default.nix).
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
`sqlite3 <copy> 'PRAGMA integrity_check;'`, then test the application.

Executor v1 was retired from sietch in November 2026, and sietch's `services`
job no longer backs it up. Snapshots taken before then still hold
`/var/lib/executor` and the staged `executor` database. Reading its encrypted
data needs v1's `EXECUTOR_SECRET_KEY`, from `secrets/selfhost/executor-env.age`
in git history.

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
and on the paper recovery sheet. Edit agenix secrets on jacurutu with a YubiKey
(`<host>` is sietch, jacurutu or tleilax):

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

## tleilax: Executor v2

tleilax backs up `/var/lib/executor-v2` (the container's `/app/data`, owned by
940:940): the PGlite database and each app's source as a git repository. It
skips the telemetry cache, the podman image store and `/run/agenix`. Atlas is
stateless.

- **The key.** A restore is useless without `EXECUTOR_ENCRYPTION_KEY` from
  `secrets/executor/tleilax-v2-keys.env.age`, which only tleilax's host key and
  the YubiKeys decrypt. Never regenerate that file.
- **Nightly.** PGlite has no live backup, so `restic-backups-executor` stops
  `podman-executor-v2`, takes the snapshot and starts it again, also when the
  snapshot fails. Executor is down while the snapshot runs.
- **Before an image update.** `/var/lib/backup/versions/executor` records the
  image Executor last started with. When the configured image differs, the
  unit's start condition takes a snapshot tagged `executor` and `pre-update`
  first, while the old container is stopped. If that snapshot fails, Executor
  stays stopped and Hark gets "Update held on tleilax"; after fixing the cause,
  `sudo systemctl start podman-executor-v2` tries again. The image is recorded
  only after a snapshot succeeds. A first start with no recorded image records
  it without a snapshot.
- **Alerts.** tleilax sends through its own Hark credential, project "Fleet":
  a job that failed after its retries, a held update, and the daily staleness
  check of its own job (no success in 72 hours). Its backup units skip the
  generic failed-unit alert, which would fire on every retry.
- **Network.** The share is reached over the tailnet at `dar-es-balat`'s tailnet
  address, on TCP 445 only. The Executor nftables table filters only Executor's
  UID, so the kernel's SMB socket passes it.

Commands on tleilax:

```sh
sudo systemctl start restic-backups-executor
journalctl -u restic-backups-executor -u podman-executor-v2
cat /var/lib/backup-status/tleilax-executor.json
sudo restic-executor snapshots
sudo backup-restore-check-executor            # latest snapshot
sudo backup-restore-check-executor SNAPSHOT_ID
```

`backup-restore-check-executor` restores the snapshot into a scratch directory
under `/var/lib`, gives it to 940:940, and starts the live container's pinned
image on it as `executor-v2-restore-check`: same user, environment and key file,
`--network=none`, no ports, and an empty telemetry directory. With no network
the copy can't refresh OAuth tokens and break the live instance's. It passes
when the container stays up, `executor-host health` succeeds, and the logs show
no migration or key error. Then it runs `git fsck` on every git repository it
finds in the restored data. It removes the container and the restored copy
whatever happens.

### Rolling back an Executor update

The old image needs the data from before the update, since the new one may have
migrated it. That data is the newest snapshot tagged `pre-update`. In order:

1. On tleilax, stop the nightly job and Executor:
   `sudo systemctl stop restic-backups-executor.timer podman-executor-v2.service`.
2. Move the data aside:
   `sudo mv /var/lib/executor-v2 /var/lib/executor-v2.rollback-$(date +%Y%m%d-%H%M)`.
3. Restore the snapshot and give it to Executor's user:

   ```sh
   sudo restic-executor restore latest --tag pre-update --target /var/lib/executor-v2-restore
   sudo mv /var/lib/executor-v2-restore/var/lib/executor-v2 /var/lib/executor-v2
   sudo rm -r /var/lib/executor-v2-restore
   sudo chown -R 940:940 /var/lib/executor-v2
   ```

4. On jacurutu, revert the image pin in `machines/tleilax/executor.nix` (or the
   commit that bumped it), push to `nixos` and `deploy`. The deploy takes one
   more pre-update snapshot, of the restored data, before the old image starts.
5. On tleilax, check that it's healthy and running the old image:
   `sudo podman exec executor-v2 executor-host health` and
   `sudo podman inspect --format '{{.ImageName}}' executor-v2`.
6. Start the nightly job again: `sudo systemctl start restic-backups-executor.timer`.
   Delete `/var/lib/executor-v2.rollback-*` once you're sure.

### tleilax NAS setup

Set in DSM on 2026-11-17, copied from `backup-jacurutu` and
`svc-backup-jacurutu` after reading their settings:

- Shared folder `backup-tleilax` on Volume 1, description "Backups from
  tleilax". Not hidden in My Network Places, sub-folders not hidden, recycle
  bin off, no share encryption or WriteOnce, data checksum on, compression
  off, no quota. Read/Write for `svc-backup-tleilax` and, by DSM's default,
  the `administrators` group.
- Snapshots in Snapshot Replication: every day from 01:05, every 6 hours,
  last at 19:05, immutable for 7 days. Smart Retention keeps 14 daily,
  8 weekly and 12 monthly snapshots plus the 5 latest. GMT naming and "Make
  snapshot visible" are off.
- `svc-backup-tleilax`: Read/Write on `backup-tleilax` and No access on
  `archive`, `backup-jacurutu`, `backup-sietch`, `cloud-drive`, `homes`,
  `library` and `photo`. SMB is allowed; AFP, Cloud Sync, DSM, FTP, File
  Station, SFTP, Synology Photos, Universal Search and rsync are denied. It
  belongs to `users` only. Its description and "Disallow the user to change
  account password" were already set and stayed as they were.
- Left alone: the other service accounts have an explicit No access entry
  on `backup-jacurutu` but none on `backup-tleilax`. They still can't reach
  it, since none of their groups has a permission on it.
- Firewall, profile `default`: allow TCP 445 from `100.73.84.103/255.255.255.255`,
  a copy of jacurutu's `100.108.28.4` rule placed below it, above deny-all.
