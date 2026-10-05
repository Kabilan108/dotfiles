# Jacurutu rootless Docker migration

## Current checkpoint

Prepared on 2026-10-05 from `/tmp/jacurutu-rootless-docker-handoff.md`, copied
from Sietch and checksum verified. The repaired additive system was activated
successfully. Home Manager and rootless Docker are healthy, and a fresh shell
selects the rootless endpoint. The existing root-owned `~/.config/moberg` parent
was repaired before Home Manager linked Docker's configuration. Its inode and
secret-file contents were preserved.
Rebuilds and reboot are human-operated under `AGENTS.md`.

The root flake covers Sietch and Jacurutu. The separate `raspi` flake is outside
this migration. Shared development defaults enable rootless Docker and deny
Docker-group membership. Jacurutu's additive generation temporarily granted
privileged Docker access for export and validation. That override was removed,
and human activation and reboot are complete. Fresh ordinary-user access to
`/run/docker.sock` is denied; plain Docker selects the rootless daemon. Disabling
rootless does not automatically grant privileged Docker access; reviewed host
exceptions use the same explicit access option.

Sietch's existing rootless daemon, rootful Executor, protected storage, and
Docker-group exclusion remain configured. See
[the completed Sietch procedure](docker-rootless-migration.md) for transfer,
notebook ACL, application verification, and independent networking evidence.

## Inventory and preservation

Protected evidence is in
`/vault/userdata/jacurutu-rootless-migration/2026-10-05`, with directory mode
0700 and files mode 0600. Inspect dumps privately; container environment values
and database dumps must stay out of reports. Inventory includes full container,
image, volume, network, context, and daemon metadata, writable-layer diffs,
checkout configuration, and component Git state.

One full-clone checkout is registered at `/vault/work/moberg/dev-server`, named
`dev-server-0`, Compose project `dev-server`, checkpoint `default`, initially
paused with no Compose containers. Dev CLI commit
`0ae5f102438537a9071f25e9e83ade2e13004b10` was fast-forwarded into its actual
`dev/flake` branch. Independent component branches, stashes, and local work
remain in place. Preserve the original lifecycle state and `last_used` value
`2026-09-30T14:25:01+00:00` after verification.

| Resource | Current disposition |
| --- | --- |
| `dev-server_db-iam_default` | Verified PostgreSQL 12 rootless restore; exact rootful source removed; private recovery dumps retained |
| `dev-server_db-patient_default` | Verified PostgreSQL 12 rootless restore; exact rootful source removed; private recovery dumps retained |
| `dev-server_dashboard-node-modules` | Recreated rootless and application verified; exact rootful dependency volume removed |
| Anonymous volume `adc3aeb7c171e96ddc4ced8fcb3be607dfd04eff38e7969af4f0062161233aad` | Read-only inventory found no files, 4 KiB; retain until scoped cleanup decision |
| Anonymous volume `cc62d305ca07226c81913a28f84c499cb5a4b5bdeb6891fb5b9b979337a8c643` | Read-only inventory found no files, 4 KiB; retain until scoped cleanup decision |
| `moberg-clara-local` | Deleted at explicit user request; notebook home, archives, and image retained |
| `hungry_brown` | Deleted at explicit user request; image retained |
| `hardcore_dirac` | Deleted at explicit user request; image retained |
| Four dev-server images | Dashboard, IAM, Query, and export-worker rebuilt rootless from preserved revisions; rootful images retained |
| `moberg-clara-local:dev` | Retained unchanged; Clara container deleted at explicit user request |
| `jupyterhub-singleuser-dev:latest` | Local image used by stopped experiment; retain unchanged |
| Three untagged images | Unique local builds of unknown purpose; retain unchanged |
| Registry Jupyter 2.1.1, connect-client, PostgreSQL 12, BusyBox | Retain rootful copies; pull or transfer required rootless images with identity checks |
| `bridge`, `host`, `none` networks | Built-in rootful networks; retain, let rootless create separate networks |
| System Docker and Docker firewall unit | Retain during migration; no discovered active system container dependency on Jacurutu |
| `docker-prune.service` | Installed manual system-daemon operation; no timer, no invocation during migration |
| LazyDocker and interactive Docker/Compose | New sessions inherit the UID-derived rootless endpoint |
| Moberg maintenance CLI | Configured rootless endpoint; maintenance timers are disabled on Jacurutu |

All three standalone containers were stopped, unprivileged, and had no devices
or Docker socket mounts. The user explicitly requested deletion of all three.
Their exact IDs were revalidated immediately before removal without force or
volume deletion. Image IDs and the five-volume inventory remained unchanged.
No global prune was run; no standalone container migration is required.

The disposable full-clone pilot passed source builds, startup migrations, doctor,
exec/logs, checkpoint save/switch/reset, pause/resume, and three HTTP checks. A
test table written after a saved checkpoint disappeared after reset. Its exact
containers, checkpoint, and three named volumes were removed afterward.

Both PostgreSQL volumes were logically restored and fingerprint verified: IAM
has 28 tables and Patient has 60. Protected SQL, globals, authentication files,
and checksums are retained. Separate target identities and a second live data
check were recorded before application startup. The real checkout then passed
source builds, migrations, doctor, SQL queries, and three HTTP checks. The
export-worker image was separately rebuilt. The real
checkpoint reset removed a post-save test table, and final recovery certification
passed. Exactly the two old rootful database volumes and the old dependency
volume were then removed. No original image or anonymous volume was deleted.
The checkout was returned to its original paused/default lifecycle and exact
original `last_used`; all 31 recorded Git HEADs, branches, and statuses match.

The final isolated build at `ffd646a7` passed, as did flake checking and both
hosts' daemon/group policy evaluations. The reviewed human operator is
`/vault/userdata/jacurutu-rootless-migration/2026-10-05/activate-final.sh`.
Post-reboot cutover verification passed. The running and booted generations
match at `/nix/store/qsclyxvnflglasnhlnrafrwfm21mi187-nixos-system-jacurutu-26.11.20261001.c59305b`.
This newer human-built generation has the same Docker units, firewall unit, and
kernel as the reviewed snapshot. The Docker group has no members; a fresh socket
connection is denied, and a fresh shell selects rootless Docker. Home Manager,
both daemons, and the Docker firewall unit are active. System Docker's unchanged
storage guard exited successfully during this boot. Original storage inodes and
ancestor ACLs remain preserved.

After reboot, the real checkout passed all three HTTP checks, doctor, SQL exec,
logs, and a separate 14-step checkpoint workflow. Reset removed a table written
after saving the test checkpoint. The test checkpoint was deleted; the checkout
returned to paused/default with its metadata and current lockfile bytes preserved.
Evidence is retained under `post-reboot/` in the protected migration directory.
The data and privilege cutover is complete. The independent physical-LAN
follow-up also passed as described below.

Scoped preparation repaired 30,792 root-owned shared UV cache entries and 13,084
untracked generated entries across 17 component repositories. The component
operator pinned directory/file identities, rejected symlinks and hard links,
preserved modes, and excluded tracked source and notebook checkpoints. Two
tracked/source-like exceptions were retained unchanged. Original component
branches, local work, and lockfile bytes remain preserved.

Independent physical-LAN checks passed after both machines joined the same LAN.
Sietch routed from `10.0.0.71` through `enp4s0` to Jacurutu's `10.0.0.60`, while
Jacurutu used `wlp1s0`. The IPv4 fixtures bound loopback, Tailscale, wildcard, and
the explicit LAN address. IPv6 fixtures bound loopback, wildcard, and the LAN
address in the shared global IPv6 prefix. All seven remote TCP probes timed out,
including both wildcard and explicit LAN publications. Sietch's direct-LAN ping
controls succeeded before and after each set of probes. Each fixture served its
known HTTP marker locally before and after the probes, including the wildcard
fixture through Jacurutu's LAN address. All seven exact test containers were
removed, with labels rechecked before deletion. No firewall or tailnet policy
was changed. These results cover the tested IPv4/IPv6 TCP bindings; system
Docker's `DOCKER-USER` guard remains separate from rootless host listeners.
Evidence is in `physical-lan-verification.json` and
`physical-lan-ipv6-verification.json` under the protected migration directory.

A remote tailnet-positive control remains separate: the live compiled Tailscale
policy still permits the Pixel but excludes Sietch as an inbound source. Earlier
Sietch tailnet TCP timeouts therefore do not establish a rootless forwarding or
firewall result. Local Tailscale-address HTTP checks passed; an independent
remote positive needs an authorized peer such as the Pixel.


## Additive activation

Build the reviewed committed snapshot in an isolated checkout. Keep unrelated
desktop changes out of the build. The imported Sietch lock contained an orphaned
T3 Bridge input absent from committed `flake.nix`; normalize that stale entry
without updating any actual dependency pin.

Jacurutu's tmpfiles declarations protect the existing `/vault` and
`/vault/userdata` directory inodes with root ownership, sticky mode, and a named
write ACL for `kabilan`. The userdata group/other entries keep execute-only
access. Child ownership is unchanged. Rootful Docker retains
`/vault/userdata/docker`; rootless gets a separate initially mode-0700
`/vault/userdata/docker-rootless`. Never recursively chown the vault.

Before activation, record host-side directory inodes, modes, ownership, and ACLs.
Reject symlinks or an absent vault mount. Verify the existing system Docker data
directory is genuinely root-owned with no non-root write access. The agent's
restricted user namespace maps only UID 1000 and GID 100, so host-root ownership
appears as UID/GID 65534 there; use a human host shell for authoritative checks.
That shell must also confirm live `/etc/subuid`, `/etc/subgid`, and the setuid
mapping helpers. NixOS evaluates automatic subordinate range allocation and
linger enabled; derive the assigned ranges after activation.

Use the exact reviewed build's `switch-to-configuration` for activation after
the human registers its system profile. Notify through `notify-send` and Hark
once the build and security review pass. Rootful Docker's storage guard waits
for tmpfiles and the mounted vault on next start; its changed unit deliberately
does not restart an existing system daemon during activation.

## Verification and recovery checklist

1. Verify installed configuration, rootless daemon UID/security/socket/data root,
   actual subordinate mappings, fresh-shell endpoint, retained rootful health,
   protected parent inodes/ACLs, and maintenance routing. Start the user daemon
   if needed. Do not infer activation from the build.
2. Validate a disposable checkout against rootless with source builds, startup,
   migrations, exec/logs, checkpoint save/restore, pause/resume, doctor, and
   teardown. Use loopback or Tailscale bindings and preserve unrelated data.
3. Export both source PostgreSQL volumes with all databases, schema/data,
   roles/memberships, sequences, large objects, and settings preserved. Quiesce
   writers and retain checksummed SQL recovery copies. Verify rootless restores
   and application behavior before deleting any source resource.
4. Clara was deleted at the user's request. Preserve its notebook home, archives,
   and image; no notebook permission changes are required for this cutover.
5. Remove the temporary privileged-access override, build and review the final
   configuration, request human activation and reboot, then verify fresh socket
   denial, plain Docker rootless selection, booted/running configuration, real
   checkout smoke/checkpoint checks, and retained services.
6. Keep networking verification separate from `DOCKER-USER`, using an independent peer,
   a successful positive control, explicit bind fixtures, and tailnet-positive /
   physical-LAN-negative checks. Remove exact fixtures.
7. Prepare an exact source cleanup allowlist only after restore and application
   proofs pass. Revalidate IDs, labels, references, and recovery evidence before
   deletion. Retain unknown state and protected recovery copies with an explicit
   retention decision; finish with every resource's actual disposition.
