# Sietch rootless Docker migration

The user approved a rootless daemon for Moberg development, keeping system Docker
for Executor. They authorized stopping checkout containers after the rootless
setup works, transferring their resources, rebasing every dev-server checkout to
the CLI change, and deleting old checkout volumes after verified restoration.
Keep notebooks as `jovyan` with scoped ACLs. Do not migrate personal credentials
or change libvirt policy in this work.

## Activation checkpoints

1. Prepare and review the additive NixOS configuration and dev CLI change.
   Keep Docker-group membership during the migration. Notify the user to run
   `sudo nixos-rebuild switch --flake /home/kabilan/dotfiles#sietch`.
   This activation does not require a reboot.
2. Verify the installed daemon configuration, its UID, rootless security options,
   intended socket/data root, and continued Executor health. Start the user unit
   with `systemctl --user start docker.service` if necessary.
3. Validate a disposable native checkout. Exercise build/up, migrations, exec,
   logs, checkpoint save/restore, notebook writes and host access, pause/resume,
   timer routing, down, and cleanup. Use explicit loopback or Tailscale bindings.
4. Migrate each existing checkout and each of its database checkpoint volumes.
   Preserve original Compose project names, active checkpoint selection, and
   paused/active state. Verify restore and relevant application behavior before
   removing that checkout's rootful volumes.
5. Remove Sietch's Docker-group membership only after the migration passes.
   Notify the user to activate the reviewed configuration and reboot.
6. Verify installed and booted state, fresh agent group membership, denial of
   `/run/docker.sock`, rootless dev smoke checks, timer routing, and Executor.

Rebuilds on Sietch are user-operated under the repository's AGENTS.md. An evaluated
configuration or successful build is not an activated security boundary.

## Git and resource preservation

Inventory the shared registry, full clones, linked worktrees, and live Compose
projects before mutation. Record branch/HEAD, staged and unstaged state, checkout
metadata, container state, volume labels, and image IDs. Coordinate live agents
before moving their branches. Preserve independent component repositories.

Implement the CLI in a clean worktree and commit only its owned files. Rebase
each dev-server branch onto the resulting commit, preserving local work and
resolving conflicts deliberately. Verify the actual CLI used in every checkout,
including an independently cloned repository with its own Git object database.

Quiesce checkout applications before dumping their databases. Use verified SQL
dumps, retain checksums and protected recovery copies, and verify restored schema
and data against the source before accepting a transfer. Dump all existing
checkpoint volumes, not only the currently selected checkpoint. Rebuild disposable
dependency volumes rather than copying Docker's internal storage directory.

Delete only a recorded allowlist of old checkout volumes after successful restore
and application checks. Immediately revalidate names, labels, ownership, mount
references, and verification evidence before deletion. Do not run global prune,
delete shared checkpoint dumps or archives, or remove Executor resources.

## Notebook ownership

The Clara bind-mounted `.local/home` is the writable scope. Prepare traversable
directories and access/default ACLs for the mapped `jovyan` UID and host owner.
Derive the mapping from the active rootless namespace. Do not widen permissions
on the entire repository or archive tree. Test read-only sources and archives.

Use `bin/moberg-rootless-notebook-home CHECKOUT` to preview the specific home and
live UID mapping. Stop notebook processes and any containers with writable access
to that home on both daemons. Then use `--apply --writers-stopped`; pass
`--rootlesskit` when its executable is outside PATH. The helper rejects running
rootless containers with overlapping writable mounts. The operator must also
check system Docker and non-container writers before applying.

The helper preserves inode ownership and existing principals' effective access.
It refuses unfamiliar owners and unmapped ACL identities. It skips incidental
symlinks, rejects symlinks in required writable directories, and applies ACLs
through checked open file descriptors so path replacement cannot redirect writes.

Inherited ACLs permit ordinary shared files, but explicit `chmod 600`/`700` can
mask peer entries. Keep intentional private permissions and provide deliberate
rootless repair when needed. Container root maps to the host development user,
not host root. It can still exercise that user's filesystem authority.

## Deferred credential review

After Docker completion, launch a separate planning thread. Inventory credential
names, scopes, consumers, ownership, and inherited environment without printing
values. Agenix currently uses the user-readable Sietch SSH identity; the T3
launcher sources `.bashenv`. Root-only plaintext alone therefore does not prevent
decryption or inherited access. Consider scoped development credentials, dedicated
service identities, a separate agent account, and narrow operation brokers.

Changing recipients does not revoke the existing key's access to encrypted copies
in Git history. Re-encrypting unchanged values leaves those historical values
recoverable; rotate relevant credentials when retiring that access. A broker must
perform the authorized operation rather than return the privileged credential.

## Implementation record, 2026-10-04

The additive configuration is activated on Sietch. The live user daemon runs as
UID 1000 at the intended socket and data root. Executor remains on system Docker,
and its `/api/health` endpoint returns HTTP 200.

Dev CLI commit `0ae5f102438537a9071f25e9e83ade2e13004b10` is integrated into all eight
registered checkouts. The Cleveland linked worktree also includes it, with its
explicit demo-data mount preserved. Local commits, staged documentation, dirty
configuration, and component repository work were preserved. A disposable native
bundle passed source builds, startup, migrations, exec, logs, checkpoint
save/restore, pause/resume, doctor, and teardown checks.

All 24 rootful PostgreSQL checkpoint volumes were transferred through protected
SQL dumps. Verification covers every non-template database, table data, schema,
sequences, large objects, roles, memberships, database metadata, settings, and
host authentication configuration. Separate rootless volume identities and
recovery-file checks bind the transfer proofs to the restored resources.

All eight existing checkout stacks passed source builds, startup and migrations,
doctor checks, database queries, and 24 HTTP checks. They were returned to their
paused state. After final restoration and application verification, cleanup
removed the explicit allowlist of 39 old checkout containers and 50 old volumes:
24 database volumes, eight dependency volumes, and 18 attached anonymous volumes.
Executor and unrelated containers, volumes, images, and archives were retained.
The rootless maintenance timer is running again.

Publishing tests passed for loopback and Sietch's Tailscale address, including
browser access through the tailnet. Those listeners did not bind the LAN address.
A remote LAN IPv6 firewall test passed with a working SSH control. The independent
LAN IPv4 follow-up also passed: Jacurutu routed directly over `wlp1s0` from
`10.0.0.60` to Sietch's `10.0.0.71`, and the SSH control exited successfully.
Tailscale-bound and wildcard fixtures responded over the tailnet, while all
three LAN probes timed out, including the wildcard publication. The exact test
containers and listeners were removed afterward. Evidence is recorded in
`lan-ipv4-verification.json` under the protected migration evidence directory.
Rootless publications use host listeners; system Docker's `DOCKER-USER` guard remains
separate and does not establish rootless protection.

Clara remains `jovyan`. Its existing notebook home received scoped ACLs for host
UID 1000 and mapped UID 100999. Actual notebook writes and host read/write access
passed; case/archive sources remained readable and the archive remained
unwritable. No other checkout had an existing notebook home requiring preparation.

Rootful development left root-owned generated build artifacts. One-time ownership
preparation covered the shared UV cache and 8,874 untracked generated entries or
empty mount directories across component and Python-package repositories. It
preserved source contents, modes, and inode identities, excluded tracked files,
symlinks, regular hard links, and notebook checkpoints, and used checked file
descriptors for mutation. New rootless builds create ordinary container-root files
as the host development user.

Protected operator scripts, SQL recovery points, inventories, and verification
records are retained under `/vault/userdata/moberg-rootless-migration/2026-10-04`.
These SQL copies contain pre-startup state; recovery restores them and reruns the
component migrations captured by application validation. They are not backups of
subsequent development writes.

The final configuration is activated and Sietch has rebooted. Installed and booted
systems match the reviewed build. A fresh agent has no Docker group and receives
`PermissionError` when connecting to the system socket. All eight checkout CLIs
select rootless Docker; actual maintenance and primary Dashboard/IAM/Query startup,
doctor, and HTTP checks passed. The primary stack was paused again. Executor is
healthy. Jacurutu's membership is unchanged.

The same activation closes a persisted-state path replacement risk. Sietch's
`/vault` and `/vault/userdata` become root-owned sticky directories with a named
write ACL for `kabilan`. Their children keep their ownership, so normal user-owned
files remain writable and removable. Root-owned immediate children require root
for rename or deletion. System Docker checks this protected path at startup and
waits for its mount and tmpfiles setup. Its changed unit is not restarted merely
because of this definition change, preserving Executor until the planned reboot.
Post-reboot checks confirm the original directory inodes, exact ACLs, root
ownership, sticky protection, and mount dependency are present.

Use the reviewed Git revision in the final rebuild command. Other workers have
unrelated Nix changes in this checkout; a dirty-tree rebuild would include those
changes without this migration's review or validation.

The reboot also exposed a pre-existing tmux `PATH` override that omitted
`/run/wrappers/bin`. This selected the unprivileged system `sudo` binary in tmux
while SSH selected the working wrapper. The tmux configuration and live server
environment now include the wrappers directory before Nix profile binaries. A
fresh tmux pane selects the wrapper and its startup succeeds. Already-open shells
need `export PATH="/run/wrappers/bin:$PATH"`; this does not require another rebuild.

The separate credential-hardening planning thread is running. It has planning
scope only; credential rotation and access changes require separate authorization.
