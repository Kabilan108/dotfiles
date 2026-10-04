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
