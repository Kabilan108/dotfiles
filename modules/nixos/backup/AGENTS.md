# Backup notes

Operating instructions are in `docs/backups.md`; `tests/backup.nix` pins the guards, the retry count and the alerts.

- Keep the `backupHostKey` activation script and the `age.identityPaths` entry tied to `nas`, not to `enable`. jacurutu runs no sshd, so nothing else creates `/etc/ssh/ssh_host_ed25519_key`, and the key has to exist, and be registered as a recipient, before backups are switched on. agenix skips an identity it can't read, so the first activation does no harm.
- Keep the `options ? age` guard around `age.identityPaths`. `tests/backup.nix` imports this module without agenix and would fail to evaluate otherwise.
- Keep the NAS mount beneath `/var/lib/backup`, which is 0700 root, so ordinary users can't trigger or browse the automount.
- Keep `mountReset` at the start of every run. A burst of failed mounts during a NAS outage trips the mount unit's start limit; the automount then stays failed and the share's path is an empty local directory until something resets it. The `config` check that follows is what stops a run from writing there.
- Do not replace `backup-retry` with systemd's `Restart=`. Its start limit is a time window, and slow attempts (a lock wait of up to 1 h, a long upload) outlast the window, so the job would retry forever without alerting.
- `progressFps = 1.0 / 60` gives one progress line a minute in the journal. Without a terminal restic prints nothing until it ends.
- Write every `OnCalendar` here and in host overrides with a `UTC` suffix. A NixOS switch briefly drops `/etc/zoneinfo`, and a local-time timer recalculated in that gap can fire early.
- A host that pushes its status elsewhere is checked for staleness by the receiving host, because a laptop that is offline can't alert that its own backups stopped. Set `staleness.ownJobs` only on a host that sends its status nowhere.
