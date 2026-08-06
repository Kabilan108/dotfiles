# NAS network access policy

Last reviewed: 2026-08-05

This document is the durable network and access policy for `dar-es-balat`, the
Synology NAS. Tailscale policy remains authoritative in the admin console, with
[`tailscale-policy.jsonc`](./tailscale-policy.jsonc) as its repository reference
copy. DSM firewall and shared-folder permissions are configured on the NAS.

## Design

- Use **Tailscale as the control plane**: DSM administration, Synology Photos,
  and access while away from home.
- Use the **wired LAN as the high-throughput data plane**: read-only media over
  NFSv4 and per-machine backups over SMB3.
- Treat Tailscale and the LAN as separate authorization surfaces. Tailscale
  grants do not restrict traffic sent directly to `10.0.0.240`.
- Default-deny at the NAS firewall. Do not equate membership in the home `/24`
  with authorization to use NAS services.
- Never port-forward NAS services or place the NAS in the router DMZ.

## Intended access matrix

| Source | Path | Destination/service | Authorization |
| --- | --- | --- | --- |
| `jacurutu` | Tailscale | NAS HTTPS, TCP 443 | DSM administration and Photos |
| `jacurutu` dock Ethernet | LAN | SMB3, TCP 445 | `backup-jacurutu` only |
| `jacurutu` dock Ethernet | LAN | DSM HTTPS, TCP 5001 | Optional break-glass administration only |
| `sietch` wired Ethernet | LAN | NFSv4, TCP 2049 | Read-only `library` export |
| `sietch` wired Ethernet | LAN | SMB3, TCP 445 | `backup-sietch` only |
| Pixel 9 | Tailscale | NAS HTTPS, TCP 443 | Synology Photos |
| `tleilax` | Either | None by default | Add a narrow rule only for a concrete service |
| Other LAN and IoT devices | LAN | None | Default deny |
| NAS | Tailnet or LAN | Fleet machines | No initiated connections by default |

`jacurutu` remains the broad tailnet control-plane device for now. Revisit and
narrow its `dst: ["*"]` grant after the fleet setup has matured; do not expand
that exception to other devices.

## NAS firewall target

Before replacing the broad LAN rule, reserve stable DHCP addresses for
`sietch`'s wired NIC and `jacurutu`'s future dock NIC. Apply DSM firewall rules
top-to-bottom:

1. Allow `sietch` wired IP to TCP 2049.
2. Allow `sietch` wired IP to TCP 445.
3. Allow `jacurutu` dock IP to TCP 445.
4. Optionally allow `jacurutu` dock IP to TCP 5001 for break-glass DSM access.
5. Preserve Tailscale HTTPS and the UDP traffic required for direct Tailscale
   connectivity.
6. Deny all other inbound traffic.

Do not expose LAN HTTP 80, DSM HTTP 5000, NetBIOS/SMB 139, SSH 22, FTP,
WebDAV, rsync, or NFS to the full subnet. Disable IPv6 on the NAS unless a
specific use requires it; otherwise mirror the IPv4 policy with IPv6 rules.

Normal DSM access is `https://dar-es-balat.sole-pierce.ts.net`. TCP 5001 is a
local recovery path, not the daily URL. Tailscale Serve may use DSM HTTP on
loopback as its backend; blocking LAN TCP 5000 must not block loopback.

## Service policy

### NFS

- Enable NFS only when the Jellyfin mount is ready to be configured.
- Use NFSv4 and export only `library`.
- Restrict the export to `sietch`'s reserved wired IP.
- Make the export read-only.
- Do not allow non-privileged source ports.
- Do not map users or root to the NAS administrator.
- Once LAN NFS is verified, remove the redundant `tag:server` to `tag:nas`
  TCP 2049 tailnet grant.

NFS is acceptable for this purpose because the exported media is not secret,
the mount is read-only, and the client is fixed. Use authenticated SMB rather
than NFS for backups and private multi-user data.

### SMB backups

- Keep SMB minimum at SMB2 with Large MTU and maximum at SMB3.
- Use SMB3 transport encryption; prefer `Force` after both NixOS clients pass a
  compatibility and throughput test.
- Create one non-administrative account per machine. Each account receives
  read/write access only to its matching backup share and no DSM application
  privileges.
- Store credentials in root-owned agenix material and run backups from
  root-owned systemd units. Do not expose credentials or backup mounts to
  ordinary agent sessions.
- Retain immutable Btrfs snapshots. A compromised source with write access can
  damage its live backup share but must not be able to delete protected
  snapshots.
- Add an encrypted off-NAS backup for irreplaceable data. Mirroring and SHR are
  not backups.

### Accounts

- `nas-admin`: dedicated DSM administrator; hardware-key 2FA enrolled.
- `shigawire`: non-administrative daily Synology Photos account. Synology
  Photos Shared Space grants it Full Access to all folders and allows mobile
  backup; User Home and Photos Personal Space remain disabled. It currently has
  no shared-folder ACL, so File Station correctly shows no folders. Grant a
  narrow SMB/shared-folder permission only for a concrete interactive need.
- Backup service accounts: no interactive DSM or application privileges; one
  share per account.
- No general agent account on the NAS. Add a narrowly scoped principal only for
  a concrete automation requirement.

## Router and physical network

- Keep the NAS DHCP reservation at `10.0.0.240`.
- Keep `sietch`'s wired DHCP reservation at `10.0.0.71`. Xfinity may list
  Ethernet clients behind the unmanaged switch as offline even while their
  reservations, routes, and links are active; verify live state from the host
  rather than treating the device-list label as authoritative.
- Keep the switch Loop Prevention toggle on and use one uplink to the router.
- Do not create NAS port forwards. Keep router DMZ disabled.
- Keep Xfinity gateway Remote Management disabled; this controls Internet-side
  access to the router administration interface and is separate from NAS port
  forwarding.
- Disable UPnP unless a known household application requires it; UPnP can create
  dynamic mappings that bypass the intent of an empty static port-forward list.
- Keep Xfinity Advanced Security enabled when supported.
- Leave the Xfinity gateway IPv4 firewall at its default Low setting and its
  IPv6 firewall at Typical Security (Default) for now.
  Higher presets chiefly restrict outbound/application traffic and may impair
  Tailscale direct connections, conferencing, streaming, gaming, or other
  peer-to-peer applications. The NAS security boundary is its DSM firewall,
  service configuration, and the absence of router exposure. Revisit this only
  as a separately tested household-network change.
- A label such as “Guest” in the Xfinity app groups devices but does not create
  network isolation. The public `xfinitywifi` hotspot is separate from the home
  LAN but is not a private IoT network. Real IoT isolation requires an isolated
  guest SSID or VLAN-capable router/AP; a VLAN-aware switch alone is not enough.
- Until segmentation exists, rely on NAS host-firewall rules and device-local
  containment. `tleilax` already blocks new connections to private LAN ranges.
- Disable Wi-Fi on `sietch` after its wired configuration is made persistent.
  Keep the NAS allowlist limited to its wired address.
- Revisit genuine IoT isolation after the NAS rollout is complete. The likely
  long-term design is a VLAN-capable router/access point with a dedicated IoT
  SSID and explicit inter-VLAN firewall rules; the current unmanaged switch
  cannot create that boundary.

## Verification

After every relevant change:

1. From `sietch`, confirm the wired route and link:
   `ip route get 10.0.0.240` and read `/sys/class/net/enp4s0/{carrier,speed,duplex}`.
2. Confirm only intended LAN ports are reachable from each authorized host.
3. Confirm `tleilax` and an ordinary Wi-Fi/IoT client cannot reach NAS LAN
   management, SMB, or NFS ports.
4. Confirm DSM and Photos work through the Tailscale HTTPS name.
5. Confirm the Tailscale policy tests still pass and the NAS cannot initiate SSH
   to fleet machines.
6. In the Xfinity app, verify the NAS has no port-forward entry, DMZ is off,
   Advanced Security is on, and UPnP is off or has no unexplained mappings.
7. From a phone on cellular data with Tailscale disabled, confirm the public WAN
   address does not expose NAS ports. Do not rely only on a scan from inside the
   home network because NAT loopback behavior can mislead.

## Observed baseline

On 2026-08-04, with final rollout validation on 2026-08-05:

- `sietch`'s wired `enp4s0` negotiated 2.5 Gbps full duplex and reached the NAS
  directly at sub-millisecond latency.
- The NAS answered LAN TCP 80, 139, 443, 445, 5000, and 5001.
- LAN TCP 21, 22, 23, 111, 548, 873, 990, 2049, 5005, 5006, 6281, and 6690
  were closed or filtered. This confirms FTP, SSH/Telnet, rsync, NFS, WebDAV,
  Hyper Backup Vault, and Synology Drive were not network-reachable on their
  standard ports. The authenticated DSM inspection below separately established
  their administrative state.
- `tleilax` could not reach tested NAS LAN ports due to its egress-containment
  firewall.
- `sietch` held its reserved wired address `10.0.0.71`, used `enp4s0` for its
  default route and direct NAS route, and negotiated 2.5 Gbps full duplex while
  Wi-Fi was down. The Xfinity UI nevertheless listed both wired `sietch` and the
  NAS under offline devices; this was a router-inventory display issue, not a
  failed reservation or link.
- Xfinity port forwarding and port triggering had no entries, DMZ and UPnP were
  disabled, and Advanced Security was enabled according to the app.
- Xfinity gateway HTTP and HTTPS Remote Management were disabled. Its IPv4
  firewall was Low and its IPv6 firewall was Typical Security (Default); these
  presets were intentionally left unchanged.
- Authenticated DSM inspection confirmed SMB enabled and NFS, AFP, FTP, FTPS,
  SFTP, rsync, SSH, Telnet, and SNMP disabled. WebDAV Server, Hyper Backup
  Vault, and Synology Drive Server were not installed.
- `shigawire` was removed from the `administrators` group. Permission Viewer
  confirmed application privileges for ordinary DSM, File Station, SMB, and
  Synology Photos, but shared-folder ACL inspection confirmed it has no raw
  File Station/SMB-visible shares. Synology Photos independently grants Shared
  Space Full Access to all folders with mobile backup enabled; its permission
  layer is separate and does not confer DSM administration.
- The DSM firewall was tightened to allow UDP 41641 for Tailscale transport,
  TCP 443 from `100.64.0.0/10`, TCP 445 only from `sietch` at `10.0.0.71`, and
  DHCP replies on UDP 68 only from the router at `10.0.0.1`, followed by a
  deny-all rule. The former broad LAN and tailnet allow rules remain disabled
  and inert; delete them as housekeeping so they cannot be re-enabled
  accidentally.
- After the firewall change, `sietch` could reach only LAN TCP 445; LAN TCP 80,
  139, 443, 5000, and 5001 were blocked. A fresh DSM session from `jacurutu`
  and Synology Photos mobile backup from the Pixel 9 both succeeded through
  the Tailscale HTTPS name.
- `sietch` Wi-Fi was disabled declaratively after its wired route was made
  persistent. Its Ethernet link remained at 2.5 Gbps full duplex. Intermittent
  Tailscale session disruption observed during the transition stopped after a
  separate Docker stack with a rapidly restarting worker was shut down; the
  wired link itself showed no loss or carrier errors.
- A phone on cellular data with Tailscale disabled could not reach the NAS at
  the public WAN address. With Tailscale enabled, the NAS HTTPS name worked.
- Email notifications use a dedicated sender and the user's primary mailbox as
  recipient. A Discord webhook provides a second notification path. Test
  messages succeeded through both paths; both currently receive the `All` rule
  while the initial alert volume is evaluated.
- Both Google Drive Cloud Sync tasks completed their initial downloads and
  reached the green `Up to date` state. They are configured as download-only
  live mirrors with advanced consistency checking, Google online-document
  conversion, and destination deletion enabled when a source item is deleted.
  A controlled test downloaded `tony-mini-robot.png` and then deleted the local
  NAS copy after the source item was removed from Google Drive.
- `cloud-drive` snapshot protection was re-verified before enabling mirror
  deletion semantics: snapshots run every six hours, immutable protection lasts
  seven days, retention is 14 daily/8 weekly/12 monthly, and the five latest
  snapshots are always retained.

## Remaining implementation

- **Completed:** verify a fresh `nas-admin` login and recovery path; demote
  `shigawire`; preserve its Photos/SMB access; and audit disabled DSM services.
- **Completed by user:** reserve `sietch` wired at `10.0.0.71`; confirm empty
  port forwarding and port triggering, DMZ off, UPnP off, and Advanced Security
  on.
- **User, later:** reserve the future `jacurutu` dock IP.
- **Completed by user:** verify Xfinity HTTP and HTTPS Remote Management are
  disabled and record the IPv4 and IPv6 firewall presets.
- **Completed:** replace broad NAS LAN and tailnet access with service-specific
  DSM firewall rules; verify LAN SMB isolation, fresh Tailscale DSM access, and
  mobile Photos backup.
- **Completed:** disable `sietch` Wi-Fi declaratively in NixOS, apply the
  rebuild, and verify the wired route and link.
- **Completed:** create scoped `svc-backup-sietch` and
  `svc-backup-jacurutu` accounts and grant each account SMB access only to its
  matching backup share.
- **Agent:** configure the read-only NFS export and `sietch` mount when Jellyfin
  migration begins.
- **Agent + user, later:** store the scoped backup credentials as root-owned
  secrets and configure and test the per-machine backup clients.
- **Completed by user:** perform the external cellular-data exposure check.
- **User housekeeping:** delete the two disabled broad DSM firewall rules after
  preserving the narrow active rules and final deny rule. The disabled rules do
  not currently authorize traffic and their removal is not a rollout blocker.
- **Later:** design real IoT segmentation with a VLAN-capable router/access
  point after the NAS rollout; do not treat Xfinity device groups as isolation.

The initial NAS rollout is complete. Deferred work is tracked in GitHub issues
#12 and #13 and in the Google Photos Takeout handoff under `docs/handoffs/`.
That work includes per-machine backup clients, the Takeout import, Jellyfin/NFS,
an encrypted off-NAS backup, a second SHR drive, a future `jacurutu` wired
reservation, and eventual IoT segmentation.
