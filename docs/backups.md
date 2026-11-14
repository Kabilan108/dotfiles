# Backups

Restic backups from each machine to its own share on the NAS (`dar-es-balat`,
a DS225+). Module: `modules/nixos/backup`. NAS access rules:
[`nas-network-policy.md`](./nas-network-policy.md).

## Design

- One Restic repository per machine, in `restic/` on that machine's share:
  `\\10.0.0.240\backup-sietch\restic` and `\\dar-es-balat\backup-jacurutu\restic`.
- sietch reaches the NAS over the wired LAN, jacurutu over the tailnet.
- Each machine mounts its share at `/var/lib/backup/nas` on first use (root-only
  parent, SMB 3.1.1 with encryption). If the NAS can't be reached, the run fails
  rather than writing anywhere local.
- Every backup is encrypted with that repository's Restic password. The NAS
  holds ciphertext only.
- **Older restore points are protected by the NAS, not by Restic.** Both backup
  shares take a snapshot every 6 hours (01:05, 07:05, 13:05, 19:05 Eastern),
  immutable for 7 days, kept 14 daily / 8 weekly / 12 monthly. The backup
  accounts have SMB access to their own share only, no DSM, and sietch has no
  network path to DSM, so a compromised machine can damage at most its live
  repository and the backups since the last NAS snapshot. Recovery is rolling
  the share back to a snapshot in DSM.
- **Nothing prunes.** Restic keeps every snapshot until pruning is switched on,
  which waits until a size alert says it's needed. The repositories are never
  initialised automatically, so a deleted repository fails the next run instead
  of being replaced by an empty one.
- Backup secrets are encrypted to the machine's root-only SSH host key
  (`/etc/ssh/ssh_host_ed25519_key`) and Tony's two YubiKey age identities
  (`ageRecipients` in `lib/fleet.nix`), never to a user key. Agents running
  as `kabilan` can't read them; Tony edits them on jacurutu with a YubiKey.

## What each machine backs up

| Machine | Job | Contents |
|---|---|---|
| sietch | `files` | `/vault/notes/coppermind` (the whole vault, including `.git` and ignored files), `/vault/userdata/media` |
| sietch | `services` | Hark (`hark.sqlite` copy and `backups/`) |
| jacurutu | `files` | `/vault/notes/coppermind`, `/vault/userdata/media` |
| tleilax | later | Vaultwarden and Executor, which moved there in stage 5 |

sietch's `services` job also held Vaultwarden and Executor until they moved
to tleilax. Their last sietch state is the snapshot tagged `stage5-final`
and `archive`, taken with both stopped
([`tleilax-credentials-move.md`](./tleilax-credentials-move.md), step 5).

Live SQLite databases are never read directly. Before each `services` run,
SQLite's online `.backup` copies each one into a fresh staging directory, run
as the database's owner (`hark`), and
`PRAGMA quick_check` checks the copy. A failed copy fails the run; a stale copy
is never reused. The live files are excluded.

Not backed up: `/vault/userdata/hark/` (reproducible builds, a test database,
dev files) and `/vault/userdata/hark-downloads/` (APKs rebuilt from the Hark
repo plus the keystore in agenix and Vaultwarden). The media library lives on
the NAS's `library` share, not on sietch; it can all be downloaded again, so
it has NAS snapshots only ([`nas-network-policy.md`](./nas-network-policy.md),
"Media library").

## Schedule, retries and alerts

- Jobs run nightly around 00:00 (up to 30 minutes of random delay), finishing
  before the NAS's 01:05 snapshot. Timers are persistent, so a laptop that was
  asleep runs its backup when it wakes; jacurutu holds off sleep while one runs.
- A failed run retries 3 times, 15 minutes apart. After the last retry,
  `backup-alert@` sends one Hark alert. An incomplete backup (Restic exit 3,
  such as an unreadable file) counts as a failure.
- A run whose repository isn't reachable (the NAS mount failed) fails in
  seconds, before Restic starts, instead of Restic retrying it for many
  minutes per attempt.
- Alerts run as `kabilan`, through the Fleet maintenance webhook. Root never
  reads that user-writable curl config.
- Monthly, on the 8th, `restic-backups-check` reads back 5% of the stored data.
- After each successful run the machine records its status in
  `/var/lib/backup-status/<host>-<job>.json` (readable by everyone): last
  attempt and result, last success, repository size and NAS free space. It
  alerts once when the repository passes 100 GiB or NAS free space drops below
  15%.
- jacurutu also sends its status to sietch, where it lands in
  `~kabilan/.local/state/backup-status/jacurutu-<job>.json`. It connects with
  its host key, which sietch accepts only for that forced command, only from
  jacurutu's tailnet address.
- jacurutu's own alerts reach Hark only over the tailnet, so an offline laptop
  can't send them. Instead, sietch's daily `backup-stale-check` (as `kabilan`,
  around noon) alerts once when a received job hasn't succeeded in 72 hours,
  or when jacurutu has sent no status at all. It alerts again only after a
  fresh success; a failed alert is retried the next day.

## Commands

Every job gets a root wrapper with the repository and password set:
`restic-files`, `restic-services`, `restic-check`. They all point at the same
repository.

```sh
sudo systemctl start restic-backups-files      # run a job now
journalctl -u restic-backups-files             # its log
sudo restic-files snapshots                    # list restore points
sudo restic-files restore latest --tag files --target /tmp/restore --include /vault/notes/coppermind/some-note.md
cat /var/lib/backup-status/*.json              # last results
sudo systemctl start backup-stale-check        # sietch: check jacurutu's status now
```

Restored files land under the target with their full path. Restore into a
temporary directory, never over live data.

### Restoring a database

Restore the `services` snapshot, then use the copy under
`/var/lib/backup-staging/services/<name>/` in the restored tree. Run
`sqlite3 <copy> 'PRAGMA integrity_check;'` before using it. sietch's old
Executor data in `stage5-final` also needs `EXECUTOR_SECRET_KEY` from
`secrets/selfhost/executor-env.age`. tleilax's Executor uses a different key.

### Restoring without the machine

From any Linux machine with Restic: mount the share with that machine's NAS
account, then `restic -r <mount>/restic restore latest --target <dir>`, giving
the Restic password from Vaultwarden or the paper copy.

### One-off archive

```sh
sudo restic-files backup --tag archive /vault/notes/drexel-senior
```

Snapshots tagged `archive` must be kept by any future pruning
(`--keep-tag archive`).

## Setting up a machine

### Vaultwarden

Each machine's NAS login (`svc-backup-sietch`, `svc-backup-jacurutu`) already
has an item. Add to it:

- A hidden custom field **Restic password**: a new passphrase from the
  generator (6–7 words, hyphen-separated).
- In notes: the repository location from the Design section, and "Restore:
  ~/dotfiles/docs/backups.md".

Copy the share, NAS account and Restic password onto the paper recovery sheet.

### Secrets

On jacurutu, in `~/dotfiles`, with a YubiKey plugged in (PIN once, then a
touch per decryption):

```sh
agenix -e secrets/backup/<host>-smb.age -i ~/.config/age/yk-nfc.txt
agenix -e secrets/backup/<host>-restic.age -i ~/.config/age/yk-nfc.txt
```

Use `yk-nano.txt` with the other key.

The `smb` file holds `username=svc-backup-<host>` and `password=REPLACE_ME`;
replace only `REPLACE_ME` with the NAS password. The `restic` file holds only
`REPLACE_ME`; replace it with the Restic password. A job refuses to run while
its Restic password is still the placeholder.

Then set `dotfiles.backup.enable = true` in `machines/<host>/default.nix`,
commit, push, and deploy that host. Afterwards, on it:

```sh
sudo restic-files init                  # once, after the real password is in
sudo systemctl start restic-backups-files
```

### jacurutu rollout

For an agent on jacurutu, with Tony. Don't do any of this from sietch.

1. After the backup PR is merged, rebuild jacurutu. Activation creates
   `/etc/ssh/ssh_host_ed25519_key`, because jacurutu runs no sshd.
2. Put the public key (`cut -d' ' -f1,2 /etc/ssh/ssh_host_ed25519_key.pub`) in
   `lib/fleet.nix` as `hosts.jacurutu.hostPubkey`.
3. In `secrets.nix`, add
   `backupJacurutu = [ fleet.hosts.jacurutu.hostPubkey ] ++ fleet.ageRecipients;`
   beside `backupSietch`, and entries for `secrets/backup/jacurutu-smb.age`
   and `secrets/backup/jacurutu-restic.age` with `backupJacurutu`. Create the
   placeholders without a terminal (agenix reads stdin):
   `printf 'username=svc-backup-jacurutu\npassword=REPLACE_ME\n' | agenix -e secrets/backup/jacurutu-smb.age`
   and `printf 'REPLACE_ME\n' | agenix -e secrets/backup/jacurutu-restic.age`.
4. Check that `/vault/notes/coppermind` and `/vault/userdata/media` exist, and
   report their sizes.
5. Tony fills in the secrets (Secrets section above), enables the module and
   rebuilds jacurutu, and deploys sietch so sietch accepts jacurutu's status.
6. `sudo restic-files init`, then run the first backup. It goes over the
   tailnet and may take a while; Restic resumes an interrupted first run.
7. Checks: a restore into `/tmp`, the status file on sietch, and a failed
   run that retries, then alerts. Block only the NAS so the alert can reach
   Hark: `sudo ip rule add to <NAS tailnet IP> prohibit priority 100`, and
   `ip rule del` the same rule afterwards. With Tailscale down the alert
   can't be sent; sietch's stale check covers that case.

## Later

- tleilax gets its own share, NAS account and job for Vaultwarden and
  Executor; its secrets are encrypted to its own host key and the YubiKeys,
  never sietch's. Once it passes a restore check, sietch's leftover copies go
  ([`tleilax-credentials-move.md`](./tleilax-credentials-move.md), "What stays
  on sietch").
- Pruning (14 daily / 8 weekly / 12 monthly, plus `--keep-tag archive`), when
  the size alert asks for it. With pruning on, use `--keep-within-*` rules so
  a compromised machine can't push real snapshots out with fake ones.
- An off-NAS copy and a second NAS disk. Until then the NAS is a single disk.
