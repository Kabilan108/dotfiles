# Agent VM policy for sietch

Status: proposal, updated 2026-10-29. This branch applies no host change.
The 2026-10-04 evidence comes from read-only inspection of sietch, the locked
nixpkgs of that date, agent session transcripts and an isolated NixOS probe
(`docs/plans/agent-vm/probe.nix`, results at the end).

## Ownership

The fleet-security workstream now owns two of the three stages. This document
stays the spec for them; this branch implements neither.

| Stage | What | Owner | State |
|---|---|---|---|
| A | drop kabilan from `libvirtd`, `runAsRoot = false`, polkit password rule | fleet-security, "cheap fixes" PR on `security/cheap-fixes` (commit `76b965c3`) | in progress; Tony undefined the `downloads` pool on 2026-10-29 |
| B | `agent-vm` launcher | this branch | later work, not started |
| C | group-only `/dev/kvm` and GPU nodes, separate agent account | fleet-security, sietch agent-account step | depends on the agent user that step creates |

Agent VMs exist for unfamiliar repos and sketchy work. They are not a home for
credential services. Vaultwarden and Executor are moving to the Pi, and no
credential service will run in a VM on sietch.

Related: `docs/security-hardening.md` (threat model; R9 docker), dotfiles#21
(Moberg dev VM packaging, separate). Rootless Docker (`docs/docker-rootless-migration.md`)
is a separate track.

## Recommendation

Stage A (fleet-security) removes ambient root through system libvirt: kabilan
leaves `libvirtd`, QEMU stops running as root, and polkit asks for a wheel
password on every connection. No agent workflow used that path.

Stage A does not by itself leave same-user agents without host-root
authority. On 2026-10-04 `nix.settings.trusted-users` also listed kabilan,
which is another route to root through the Nix daemon. The same cheap-fixes
PR drops it (commit `dec24dac`). Credential and account isolation belong to the
fleet-security workstream.

Agents keep running VMs the way they already do, as raw QEMU from a
Nix-built runner. Stage B moves those runs into root-defined systemd units
that run as dedicated per-slot `agentvm<N>` users, with a root-enforced egress filter,
memory, CPU, disk and concurrency caps, a TTL and cleanup. Agents launch
through root-owned slot sockets that only the `agent-vm` group can open
(`Accept=yes` socket activation). No polkit grant is involved. A polkit rule
keyed on unit names would also authorize root transient units under any
matching name, and the probe reproduced that (R10g).

The skill routes agents to that path. The enforcement is the uid, the unit
sandbox, iptables and the socket's group. The skill text adds none.

## Evidence (sietch, 2026-10-04 snapshot)

Rows marked "since" record a later change. Everything else is as observed on
2026-10-04 and has not been rechecked on the host.

| Fact | Source |
|---|---|
| `kabilan` is in `wheel networkmanager libvirtd docker input`. Since: `docker` removed by the rootless migration; `libvirtd` removed by Stage A once deployed | `id` |
| `/etc/polkit-1/rules.d/10-nixos.rules` returns `YES` for `org.libvirt.unix.manage` to any `libvirtd` member, unconditionally | file |
| That rule is `security.polkit.extraConfig` in nixpkgs `nixos/modules/virtualisation/libvirtd.nix`; no option turns it off | locked nixpkgs |
| Upstream default for `org.libvirt.unix.manage` is `auth_admin_keep`; `org.libvirt.unix.monitor` (read-only) is `yes` for everyone | polkit action files |
| System `libvirtd.conf` sets only `auth_unix_ro/rw = "polkit"`; no `access_drivers` | `/nix/store/...-libvirtd.conf` |
| `/var/lib/libvirt/qemu.conf` is `namespaces = []` with no `user`/`group`: QEMU runs as root, and libvirt >= 6.0 keeps all capabilities for root QEMU | file, libvirt drvqemu docs |
| `virtualisation.libvirtd.qemu.runAsRoot` evaluates to `true` | `nix eval` |
| No AppArmor/SELinux confinement | earlier check |
| `virsh -c qemu:///system` works without a prompt; no domains; `default` network inactive | `virsh` |
| System storage pools: `default` (`/var/lib/libvirt/images`) and `downloads`, a `dir` pool on `/home/kabilan/downloads`, autostarted. Since: Tony undefined `downloads` on 2026-10-29 | `virsh pool-list`, `pool-dumpxml` |
| `nix.settings.trusted-users` includes kabilan, a separate root path. Since: dropped in `security/cheap-fixes` (`dec24dac`) | `configuration.nix`, coordination note |
| `/dev/kvm`, `/dev/vhost-net`, `/dev/vhost-vsock`, `/dev/net/tun`, `/dev/dri/renderD128`, `/dev/nvidia*` are all `0666` | `ls -l` |
| No polkit agent runs in the desktop session and the repo configures none | `ps`, `grep` |
| `org.spice-space.lowlevelusbaccess` is `yes` for active sessions (`spiceUSBRedirection.enable = true`) | polkit action file |
| `qemu-bridge-helper` is a setuid-root wrapper; `/etc/qemu/bridge.conf` allows `virbr0` | locked nixpkgs |
| Firewall uses iptables, opens only TCP 22, `trustedInterfaces = ["lo"]`; tailnet traffic reaches tailscale-IP binds (wayvnc relies on this) | `nix eval`, `home/services/wayvnc.nix` |
| 32 threads, 62 GiB RAM; `/`, `/home`, `/vault`, `/var` share one ext4 LV with 88 GiB free (82% used) | `nproc`, `free`, `df` |
| systemd 261.3, libvirt 12.7.0, passt 2026_07_16 (2026-10-04 lock); AMD nested KVM on | `nix eval`, `/sys/module/kvm_amd/parameters/nested` |

How agents actually run VMs here (transcript survey):

- The first desktop-QA VM on sietch was the niri agent-seat test
  (2026-09-25, `~/experiments/niri-agent-vm`). It was a flake
  `nixosConfigurations` entry importing `qemu-vm.nix`, built as
  `system.build.vm` and run as kabilan from tmux. Resources: 8 vCPU, 8 GiB
  RAM and a 16 GiB qcow2 in the VM dir.
  - Display: `virtio-vga-gl` plus `egl-headless` on `renderD128`, so virgl
    ran on the 3090.
  - Network and control: slirp with `hostfwd tcp:127.0.0.1:2222-:22`, VNC
    on `127.0.0.1:5901`, and QMP on a unix socket in the VM dir.
  - Two shares exposed project dirs (`niri/target` and a `share` dir), 9p
    with the nixpkgs of that time.
  - The agent drove the guest over SSH (`niri msg`). It used QMP for
    synthetic input and screendump, and gstreamer `rfbsrc` for video.
- That QEMU process was still running a week later.
- The Stillsuit VM harness (2026-10-05, PR #23, `/tmp/stillsuit-launcher-vm/`)
  follows the same pattern: a NixOS guest with niri, a virtiofs share of the
  worktree, real QEMU input, screenshots and recordings. One probe ran a
  throwaway Vaultwarden on host `127.0.0.1` and reached it from the guest
  through a forwarder. Stage B's egress filter blocks that pattern by design
  (choice C12).
- The Android emulator for hark is also raw QEMU on `/dev/kvm`.
- Agents use libvirt `qemu:///system` only on a remote Moberg host over SSH.
  On sietch, only Tony uses it, through virt-manager.

The root-equivalent path is unused by agents, and the proven agent path
already needs nothing privileged.

## Risk assessment

### R10a. Ambient root through `qemu:///system` (high; enforced fix available)

Any process running as kabilan can open a read-write connection to the root
daemon with no prompt. That covers a supply-chain payload, a prompt-injected
agent or a compromised dev server. The libvirt docs say the system daemon
runs as root and its guests "may have much higher privileges than the client
application managing them". On sietch, QEMU also runs as root with every
capability, no mount namespace and no MAC. Each of these is an ordinary
libvirt feature that yields root file or device access without an exploit:

- domain XML naming any host file or block device as a disk, or a
  `<filesystem>` share of any host path;
- storage pools over any directory, with volume upload, download, wipe and
  delete performed as root (a `downloads` pool over `~/downloads` existed
  until 2026-10-29);
- `<qemu:commandline>` passthrough, which the libvirt kbase describes as
  "completely opaque to libvirt";
- `save`, `core-dump` and external snapshots that write to caller-chosen
  paths;
- network definitions;
- node-device detach for PCI/USB passthrough.

I did not demonstrate any of these against host files. They are documented
behavior, and with `runAsRoot = true` the conclusion does not hinge on a
probe. This is the same class of problem as R9 (docker group).

### R10b. Setting `runAsRoot = false` alone leaves R10a open

`runAsRoot = false` makes QEMU run as `qemu-libvirtd`, which limits a guest
escape. It does nothing about the client. libvirtd still runs as root. It
still relabels and chowns whatever disk path the XML names, and still serves
the storage pool APIs. A client can still request root QEMU per domain
(`<seclabel type='none'/>`, DAC `+0:+0`) and pass `<qemu:commandline>`. The
client boundary has to be the connection: polkit and group membership.

### R10c. Password caching once the group is gone (medium)

Upstream's default for `org.libvirt.unix.manage` is `auth_admin_keep`. Once
Tony authenticates virt-manager, polkit keeps the grant for a few minutes,
and other processes may reuse it during that window. A password prompt in a
session where malware already runs as kabilan can be captured, by a rogue
polkit agent or a fake `sudo`. The threat model already accepts that for
`sudo` ("sudo-via-YubiKey ... not the boundary"), so the same applies here.
For system-libvirt admin, prefer `sudo virsh` from a fresh terminal over
virt-manager prompts (review finding 7). The fix is to return
`AUTH_ADMIN` (no keep) for wheel and `NO` for everyone else. That rule goes
ahead of the module's group rule, so re-adding someone to `libvirtd` later
cannot silently restore passwordless root. The probe confirms the ordering.

### R10d. Guest-originated reach (medium; scales with guest content)

Desktop-test guests run agent-built configs and sometimes internet code
(installer ISOs, `curl | bash` setups). Today the guest's QEMU runs as
kabilan, so:

- slirp maps `10.0.2.2` to host loopback, and a guest can reach the selfhost
  services and dev servers bound to `127.0.0.1` on sietch;
- outbound guest traffic leaves from sietch, so it reaches the LAN and the
  tailnet with sietch's `tag:server` identity;
- read-write shares of project dirs let guest-written files land in a repo,
  where `.envrc`, git hooks, flake inputs or build scripts later run as
  kabilan;
- a QEMU escape (virgl and the NVIDIA stack add attack area) lands as kabilan
  with the whole home dir.

A guest gains nothing beyond kabilan's authority. It does gain kabilan's
network position and files. Limiting that requires a different uid. Flags or
wrappers that still run as kabilan cannot do it.

### R10e. Runaway and leaked VMs (medium; operational)

The niri VM ran for a week unnoticed. Nothing caps agent VMs. The 32 threads
and 62 GiB RAM are shared with the desktop, Moberg dev servers and selfhost
services. qcow2 images grow on the root LV, which has 88 GiB free and also
holds `/home`, `/vault` and docker data. A full disk there is a host-wide
outage.

### R10f. Smaller items

- `org.libvirt.unix.monitor = yes` lets any local user, including a future
  agent uid, list domains and pools and read non-secure XML. Low risk. The
  cheap-fixes rule gates `monitor` the same way as `manage`.
- SPICE USB redirection lets active-session processes pass raw USB devices
  into a VM through the setuid ACL helper. The backup YubiKey lives in
  sietch. The cheap-fixes branch leaves it on (C4, fleet-security).
- `qemu-bridge-helper` (setuid root) allows `virbr0` for session VMs. It is
  harmless while the system `default` network is inactive. The cheap-fixes
  branch leaves `allowedBridges` at its default (C3, fleet-security).

### R10g. A polkit grant keyed on unit names authorizes root transient units (design hazard, reproduced)

The obvious launcher design gives the `agent-vm` group
`org.freedesktop.systemd1.manage-units` when `unit` matches `agent-vm@*` and
`verb` is `start/stop/restart`. That design is unsafe. systemd 261 and 262 pass
`unit` and `verb=start` for `StartTransientUnit` too. In the probe, a rule
matching `^probe-transient-[a-z]+\.service$` let an unprivileged user run
`systemd-run --unit=probe-transient-x -p User=root id -u` successfully. For
`agent-vm@*` names, only systemd's "already loaded or has a fragment file"
check stood in the way, because a template exists. A single systemd check
between a rule and root is too thin. The launcher therefore uses a
group-restricted socket and no polkit grant. Any future polkit rule for
systemd units must reject transient units explicitly, or avoid name-only
matching.

## Options considered

| Option | R10a | Guest containment (R10d) | Caps (R10e) | Keeps agent QA | Verdict |
|---|---|---|---|---|---|
| A. `runAsRoot = false` only | no | partial (QEMU uid) | no | yes | not a client boundary (R10b) |
| B. Drop group, password-gate system libvirt | fixed | no | no | yes; agents never used it | Stage A (fleet-security) |
| C. `qemu:///session` for agents | n/a | none; runs as kabilan | no | yes, adds libvirt for no gain | skip as the agent path |
| D. Raw QEMU as kabilan plus a user-level wrapper (`systemd-run --user`) | n/a | none; a compromised QEMU can leave its cgroup and read `~` | advisory only | yes | interim only |
| E. Root-defined `agent-vm@` template as `agentvm`, started through a polkit `manage-units` grant | n/a | root-enforced | root-enforced | yes | rejected: name-matched grant reaches root transient units (R10g) |
| F. Group-restricted slot sockets, `Accept=yes`, one unit instance per VM as a per-slot `agentvm<N>`; uid egress filter; slice, disk and slot caps | n/a | root-enforced | root-enforced, including concurrency | yes, with the path changes below | Stage B |
| G. Per-UUID libvirt ACLs (`access_drivers = ["polkit"]`) | fixed for listed VMs | depends on reviewed XML | libvirt only | only for rootful features | exception path; not needed today |
| H. Restrict `/dev/kvm` and GPU nodes to groups | n/a | makes F the only fast path for the agent account | n/a | breaks VMs run by an account outside the groups; nixbld KVM tests need care | Stage C (fleet-security) |

F beats D because only a separate uid holds up when a guest escapes QEMU.
Root-owned slice limits and the iptables owner match can't be undone from
inside the VM process. F does not constrain a malicious agent running as
kabilan, which can still start QEMU directly. Nothing at the VM layer can.
That belongs to the fleet-security agent account and option H (Stage C).

F beats E for two reasons. The socket's file mode is the whole grant, with
no polkit rule that could be widened by accident (R10g). And
`MaxConnections` gives a hard cap on concurrent VMs.

F also beats a strict QEMU argument schema. Inside the unit sandbox, a QEMU
argument can only reach what its slot user can reach. So F can run the agent's
own `system.build.vm` runner unchanged instead of re-implementing
`qemu-vm.nix`. Arbitrary QEMU arguments then never reach a root path, because
Stage A closes system libvirt.

## Recommended policy

Principle: a VM never holds more authority than the uid that runs it, and
agent VMs run as a uid with less authority than kabilan.

### Stage A: remove ambient system libvirt authority (owned by fleet-security)

Spec only. The fleet-security workstream implements it in the cheap-fixes
PR (`security/cheap-fixes`, commit `76b965c3`). As of 2026-10-29 that branch
differs from the spec below in three ways:

- its polkit rule also gates `org.libvirt.unix.monitor` (read-only
  connections), which closes R10f's first item;
- it leaves `allowedBridges` at the default (C3);
- it leaves `spiceUSBRedirection` on (C4).

The original spec for `modules/nixos/virt-manager.nix`:

```nix
{ lib, pkgs, ... }:
{
  programs.virt-manager.enable = true;
  virtualisation.libvirtd = {
    enable = true;
    qemu.runAsRoot = false;
    qemu.vhostUserPackages = [ pkgs.virtiofsd ];
    allowedBridges = [ ]; # choice C3
  };
  # Ordered before the libvirtd module's "libvirtd group => YES" rule.
  security.polkit.extraConfig = lib.mkBefore ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.libvirt.unix.manage") {
        return subject.isInGroup("wheel") ? polkit.Result.AUTH_ADMIN : polkit.Result.NO;
      }
    });
  '';
  virtualisation.spiceUSBRedirection.enable = false; # choice C4
}
```

Notes:

- The `users.groups.libvirtd.members = [ "kabilan" ];` line goes away. A
  rebuild removes the membership, but running processes keep their
  supplementary groups. A tmux server started before the rebuild keeps
  passwordless libvirt until it restarts. Polkit checks the subject process's
  groups, though the `mkBefore` rule makes that moot. The probe shows a
  `libvirtd` member is still denied.
- The `downloads` pool is gone: Tony undefined it on 2026-10-29.
- `runAsRoot = false` needs `qemu-libvirtd` ownership of libvirt state for
  existing guests. `nvram`, `save` and `varstore` are empty and the
  `default` pool has no volumes, so nothing migrates.
- virt-manager's password prompt needs a polkit agent (choice C2). `virsh`
  in a terminal spawns `pkttyagent` itself.

### Stage B: `agent-vm` launcher (this branch; later work)

New `modules/nixos/agent-vm.nix`, imported from `machines/sietch/default.nix`.
It is for VMs that run unfamiliar repos or sketchy code. Nothing that holds
credentials runs in it. Stage B assumes Stage A has shipped. Until Stage C
lands, launcher membership goes to kabilan. Afterwards it goes to the
fleet-security agent account.

- **Identities.** One static system user per VM slot, `agentvm0` to
  `agentvm2`, with contiguous uids (for example 9800 to 9802), group
  `agentvm` and supplementary `kvm`. A slot user owns nothing outside its
  slot's directories. `users.groups.agent-vm` is the launcher group. Members
  are `kabilan` now and the future agent user later. Per-slot uids keep an
  escaped guest from driving another VM's QMP socket, rewriting its disk or
  `share/`, or killing it. A shared uid would allow all three (review round
  1, finding 4).
- **Launch sockets.** One socket per slot: `systemd.sockets.agent-vm-slot<N>`
  on `/run/agent-vm/slot<N>.sock`, with `SocketUser=root`,
  `SocketGroup=agent-vm`, `SocketMode=0660`, `Accept=yes` and
  `MaxConnections=1`. The slot count is the concurrency cap (choice C6). The
  CLI tries slots in order. The socket's mode is the whole grant, and no
  polkit rule exists to drift (R10g). systemd resets a connection to a busy
  slot. The probe showed a failed instance does not hold its slot. The unit
  also sets `CollectMode=inactive-or-failed`, which `systemd.socket(5)`
  recommends for `Accept=yes` units.
- **Per-VM unit** `systemd.services."agent-vm-slot<N>@"`, one instance per
  accepted connection:
  - identity: `User=agentvm<N>`, `Group=agentvm`, `SupplementaryGroups=kvm`,
    `UMask=0007`, `Slice=agentvm.slice`. Slot users stay out of `agent-vm`.
    Files they create in the setgid slot dir still get group `agent-vm`, so
    the launcher group can reach sockets that other slots cannot. Keep the dash out of the slice name.
    `agent-vm.slice` nests under an implicit `agent.slice`, as the probe
    showed;
  - `StandardInput=socket`, `StandardOutput=socket`. The runner reads one
    request line, answers, drops the connection, and the VM keeps running;
  - `RuntimeMaxSec=12h` (choice C6). The sockets are the only entry, so
    nothing autostarts at boot;
  - filesystem allowlist rather than denylist:
    `TemporaryFileSystem=/run /var/lib`, `BindPaths=/run/agent-vm/slot<N> /var/lib/agent-vm/slot<N>`,
    and `BindReadOnlyPaths=/run/opengl-driver /run/current-system /run/systemd/resolve/stub-resolv.conf`.
    Add `/run/dbus` only if the GPU path needs it. Also `ProtectSystem=strict`,
    `ProtectHome=yes`, `PrivateTmp`, `ProtectProc=invisible`,
    `InaccessiblePaths=-/vault -/library -/srv`. A denylist missed
    world-writable sockets such as Mullvad's management socket and
    world-readable state in `/var/lib` (finding 5);
  - `NoNewPrivileges`, `CapabilityBoundingSet=`,
    `RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6` (no `AF_VSOCK`, which
    needs no device node and would reach other VMs' vsock ports),
    `RestrictNamespaces=yes`, `SystemCallArchitectures=native` and
    `SystemCallFilter=@system-service`. QEMU's own needs must be verified
    against these;
  - `RestrictNetworkInterfaces=~tailscale0`, so an escaped guest cannot
    bind a port on sietch's tailnet address and serve tailnet peers.
    tailscaled's `ts-input` accepts all of `tailscale0`, and unprivileged
    users can bind ports from 80 up (finding 2);
  - `DevicePolicy=closed`, `DeviceAllow=/dev/kvm rw`. The GPU profile adds
    `char-drm rw` and `char-nvidia* rw` (device classes from `/proc/devices`,
    since path globs are unsupported), including `nvidia-uvm` and
    `nvidia-caps`. NVIDIA's userspace execs `nvidia-modprobe` when a node
    open fails, which `-sandbox spawn=deny` turns into a SIGSYS kill;
  - `WorkingDirectory=/var/lib/agent-vm/slot<N>`, because `qemu-vm.nix`
    resolves EFI vars and TPM paths relative to the cwd;
  - per-instance `MemoryMax`, `CPUQuota`, `TasksMax`.
- **Slice** `systemd.slices.agentvm` sets the aggregate caps, for example
  `MemoryMax=24G`, `CPUQuota=1600%`, `TasksMax=4096` and a low `IOWeight`
  (choice C6).
- **Egress.** An `agent-vm-egress` chain via `networking.firewall.extraCommands`,
  hooked into `OUTPUT` with `-m owner --uid-owner 9800-9802`:
  - return `ESTABLISHED,RELATED` (replies to inbound VNC/SSH);
  - allow the resolver stub `127.0.0.53:53`;
  - reject new connections to any address the host owns
    (`-m addrtype --dst-type LOCAL`);
  - reject new connections to `127/8, 10/8, 172.16/12, 192.168/16, 100.64/10, 169.254/16, 224/4`;
  - IPv6: reject every new connection. sietch has a global prefix on the
    LAN, so a prefix list cannot cover LAN peers or sietch itself (finding 1).
    Guests run with `QEMU_NET_OPTS=ipv6=off`;
  - `extraStopCommands` removes both chains.

  Public IPv4 internet stays reachable (choice C7). The rule matches the
  uid, so slirp's `10.0.2.2` loopback mapping goes nowhere, and so does any
  network option a guest config picks.

  Residual: the resolver stub lets a slot user trigger resolved's LLMNR
  queries on the LAN, a low-bandwidth side channel. A root-built network
  namespace with veth and FORWARD filtering would remove that, along with
  abstract unix sockets. It is the structural upgrade if this ever matters.
- **Disk cap.** `/var/lib/agent-vm` gets its own filesystem of fixed size
  (choice C8), mounted `nodev,nosuid,noexec`. A full agent disk then fails
  the guest, not the host.
- **Directories.** tmpfiles creates `/run/agent-vm/slot<N>` and
  `/var/lib/agent-vm/slot<N>` as `3770 agentvm<N> agent-vm`. The sticky bit
  stops a launcher-group member from renaming the slot user's entries. The
  runner creates `<id>/` inside its slot dir with `mkdir`, which is atomic
  and rejects duplicates. `slot<N>/<id>/share` is where the agent drops
  files for the guest. `/run/agent-vm/slot<N>/<id>/` holds sockets and
  `status.json`, readable by the launcher group.
- **Request.** The `agent-vm` CLI runs as the caller and sends one JSON line
  over a slot socket: `{"id", "runner", "keep", "gpu"}`. `runner` is a
  `/nix/store` executable, normally the `system.build.vm` runner. The reply
  is `ok <id> <slot>` or `error <reason>`.
- **Runner.** `agent-vm run` is defined in Nix and runs as the slot user.
  - It accepts ids matching `^[a-z0-9][a-z0-9-]{0,31}$`, resolves `runner`
    with `realpath`, and requires an executable under `/nix/store`.
  - It exports `NIX_DISK_IMAGE`, `USE_TMPDIR=1` with `TMPDIR` (the runner
    ignores `TMPDIR` without it), `SHARED_DIR`, `AGENT_VM_STATE`,
    `AGENT_VM_RUNTIME` and `AGENT_VM_SHARE`.
  - It sets `QEMU_OPTS` to add a control QMP socket
    (`$AGENT_VM_RUNTIME/control.sock`) and
    `-sandbox on,obsolete=deny,elevateprivileges=deny,spawn=deny,resourcecontrol=deny`,
    and sets `QEMU_NET_OPTS=ipv6=off`.
  - It records the instance's unit name in `status.json`, closes the
    connection and execs the runner.
  - Current `qemu-vm.nix` (nixpkgs lock as of 2026-10-29) shares directories
    over virtiofs, not 9p. The runner script starts one `virtiofsd` per share
    in the background with `--sandbox=none --seccomp=none`, sockets under a
    `mktemp -d` directory, and shared memory for QEMU. Those daemons run as
    the slot user inside the same unit sandbox. QEMU's `spawn=deny` does not
    affect them, because the shell starts them before it execs QEMU. The unit
    filters (`RestrictNamespaces`, `SystemCallFilter`, the filesystem
    allowlist) must still let virtiofsd run. Step 2 covers this.
  - `ExecStopPost` (a runner subcommand, never `+`/`!`-prefixed) removes the
    runtime dir and, unless `keep` is set, the disk. The template never sets
    `StateDirectory=`, which would make systemd chown recursively as root on
    every start.
- **Stop.** `agent-vm stop <id>` sends QMP `quit` over `control.sock`. The
  launch socket is never the stop path. A hung QEMU still hits
  `RuntimeMaxSec`. Tony can always run `sudo systemctl stop agentvm.slice`.
  Agents cannot `systemctl stop` or signal slot processes, which the probe
  confirmed.
- **Cleanup.** A tmpfiles age rule (`e /var/lib/agent-vm/slot* - - - 7d`)
  runs from the existing `systemd-tmpfiles-clean.timer`, so no new timer.

Choice C9 picks the language for the CLI and runner. The repo writes CLIs in
Go, and one Go binary with `agent-vm` and `agent-vm run` keeps request
parsing out of shell. Neither binary is a security boundary. An agent that
skips the CLI and speaks to the socket directly gets the same unit, uid and
caps.

What changes for agents: the VM flake points `virtualisation` options at the
launcher's env vars instead of home paths.

```nix
virtualisation = {
  memorySize = 8192;
  cores = 8;
  diskSize = 16384;
  forwardPorts = [ { from = "host"; host.address = "127.0.0.1"; host.port = 2222; guest.port = 22; } ];
  sharedDirectories.share = { source = ''"$AGENT_VM_SHARE"''; target = "/mnt/share"; };
  qemu.options = [
    "-vga none" "-device virtio-vga-gl,xres=1600,yres=1000"
    "-display egl-headless,rendernode=/dev/dri/renderD128"
    "-vnc 127.0.0.1:1"
    "-qmp unix:$AGENT_VM_RUNTIME/qmp.sock,server=on,wait=off"
  ];
};
```

Anything the guest needs from a build gets copied into the instance's share
dir (`/var/lib/agent-vm/slot<N>/<id>/share`, reported by `agent-vm status`),
for example `cp target/debug/niri`.
The share is never a mount of the repo itself. Guest-written files land in a
dir that no host tool executes from automatically.

`qemu-vm.nix` also shares the whole host `/nix/store` read-only by default
(`mountHostNixStore`). That is world-readable on the host anyway. For guests
running internet code, set `virtualisation.useNixStoreImage = true` so the
guest only sees its own closure. It builds an erofs image of the closure on
every launch into `TMPDIR`, which costs time and space on the capped
filesystem.

### Stage C: agent account and exclusive accelerator access (owned by fleet-security)

The fleet-security workstream's sietch agent-account step owns this, because
it depends on the separate agent user that step creates. Stage C uses that
account and creates no other general agent identity. The `agentvm<N>` slot
users remain VM-layer identities owned by Stage B.

Spec: `/dev/kvm` and the GPU nodes become `0660` to groups the agent account
lacks. Only the slot users, `nixbld` (KVM NixOS tests) and Tony's interactive
uid keep access. The agent account joins `agent-vm`, which makes the launcher
its only fast path to a VM. Until that lands, the launcher is the recommended
path, and the skill says so without claiming it is the only one.

## Privileged exceptions: reviewed system VMs

Not needed today, because sietch has no system domains. This design is ready
if a workflow ever needs rootful features (PCI/GPU passthrough, bridged LAN,
macvtap).

- An admin defines each domain from reviewed XML kept in the repo, as root
  (`sudo virsh define`, or a declarative tool such as NixVirt).
- Turn on `access_drivers = [ "polkit" ]` through
  `virtualisation.libvirtd.extraConfig`. A `libvirt-operators` group gets
  `org.libvirt.unix.manage = YES`. Every `org.libvirt.api.*` action from
  that group returns `NO` unless it is on the allowlist:
  - `connect.getattr` when `connect_driver == "QEMU"`, and `connect.search-domains`;
  - `domain.getattr`, `read`, `start`, `stop`, `reset`, `screenshot`,
    `open-graphics` and `send-input`, each only for a listed `domain_uuid`.
- Everything else stays `NO`:
  - domain: `write`, `save`, `core-dump`, `snapshot`, `migrate`,
    `block-read`, `block-write`, `mem-read`, `read-secure`, `open-device`,
    `open-namespace`, `delete`;
  - `connect.write`;
  - every storage-pool, storage-vol, network, nodedev, secret and nwfilter
    permission.

  Snapshot, save and core-dump write root-owned files to caller-chosen
  paths.
- Caveat: libvirt identifies the client by uid. While agents and Tony are
  both kabilan, an operator grant covers both, and Tony administers through
  root (`sudo virsh`). It works cleanly only after the Stage C agent account
  exists, or if Tony accepts root-only admin for system VMs.

## Validation plan

1. **Isolated probe (done; results below).** `probe.nix` builds two NixOS
   test VMs in the Nix sandbox and leaves the host alone. It checks:
   - the Stage A polkit rule;
   - a polkit verb-scoped `manage-units` grant (rejected after R10g);
   - the socket launcher's group gate, uid, slice and `MaxConnections`;
   - the uid egress filter, including IPv6 and host-owned addresses;
   - `ProtectHome`, `InaccessiblePaths` and the `TemporaryFileSystem` allowlist;
   - `RestrictAddressFamilies` (vsock) and `RestrictNamespaces`;
   - replies to inbound loopback connections.
2. **Stage B NixOS test, before any sietch rebuild.** Turn the probe into a
   real test of `modules/nixos/agent-vm.nix`. It boots a small
   `system.build.vm` guest through the launch socket with nested KVM or TCG, then
   asserts:
   - guest connections to `10.0.2.2` (host loopback) are rejected;
   - `agent-vm stop` over `control.sock` ends the instance and its cleanup runs;
   - the launcher group can reach QMP and VNC;
   - `MemoryMax` kills an oversized guest and `RuntimeMaxSec` stops it;
   - `keep=false` removes the disk;
   - a full disk cap fails the guest, not the host;
   - the `-sandbox` flags and unit filters work alongside the runner's
     virtiofsd daemons;
   - QEMU runs under `SystemCallFilter=@system-service`,
     `RestrictAddressFamilies` and the filesystem allowlist. Record every
     relaxation it needs here;
   - slot 0's user cannot open slot 1's QMP socket or disk.

   virgl on NVIDIA cannot be checked in the sandbox, so step 3 covers it,
   including `char-nvidia*` and `char-drm` device access with `spawn=deny`.
3. **Desktop QA on sietch after Tony rebuilds.** Re-run the niri agent-seat
   flow through the launcher with the GPU profile. It passes when:
   - virgl renders and `nvidia-smi` lists the QEMU process;
   - SSH to `127.0.0.1:2222` works;
   - QMP screendump and gstreamer `rfbsrc` capture work;
   - a rebuilt binary reaches the guest through `share/`.

   Compare the results against the Sep 25 run.
4. **Read-only checks on sietch after the Stage A rebuild** (fleet-security
   runs these with its PR):
   - `virsh -c qemu:///system list` from a fresh agent shell fails with no prompt;
   - from Tony's desktop it prompts for a password every time;
   - `id` no longer lists `libvirtd` after relogin and a tmux restart;
   - `virsh -c qemu:///session list` still works.

Rollout keeps desktop QA working throughout. Stage A goes first through the
cheap-fixes PR, because no agent uses system libvirt. Agents keep running raw
QEMU as kabilan until Stage B passes step 3. Then the skill ships and agents
switch. Stage C follows the agent account.

Recovery: `sudo systemctl stop agentvm.slice` stops every agent VM.
Instances never autostart. Root `virsh` works throughout.

## Patch inventory

This branch (Stage B, later work):

| File | Change |
|---|---|
| `modules/nixos/agent-vm.nix` (new) | slot users, launcher group, slice, slot sockets, per-VM template units, egress chains, disk mount, tmpfiles |
| `packages/agent-vm/` (new) | `agent-vm` CLI and runner |
| `machines/sietch/default.nix` | import `agent-vm.nix` |
| `agents/skills/sietch-vm/SKILL.md` (new, `fleet-hosts: sietch`) | promoted from `docs/plans/agent-vm/skill-draft/SKILL.md` after step 3 passes |
| `docs/security-hardening.md` | short launcher entry under "Isolation / sandboxing" |

Fleet-security workstream (for reference):

| File | Change | Stage |
|---|---|---|
| `modules/nixos/virt-manager.nix` | group line dropped, `runAsRoot = false`, `mkBefore` polkit rule | A (`security/cheap-fixes`) |
| `configuration.nix` | kabilan dropped from `trusted-users` | cheap fixes, related |
| agent account, device groups for `/dev/kvm` and GPU nodes | new account; `0660` nodes | C |

## Choices for Tony

Settled or owned elsewhere:

- **C1. System libvirt for yourself.** Password-gated (Stage A, fleet-security).
- **C2. Polkit agent** for virt-manager prompts. Fleet-security. Sietch runs
  niri only now, and `sudo virsh` from a fresh terminal avoids the prompt
  (R10c).
- **C3. `allowedBridges`** and **C4. SPICE USB redirection.** Open in the
  fleet-security workstream. The cheap-fixes branch leaves both as they are.
- **C10. `downloads` pool.** Done: Tony undefined it on 2026-10-29.

Open for Stage B:

- **C5. GPU for agent VMs.** Allow the render and NVIDIA nodes in a GPU
  profile (the proven niri flow needs virgl), or default to llvmpipe with GPU
  as a per-request opt-in.
- **C6. Caps and TTL.** Proposed: 3 slots; per VM 12 GiB / 8 CPUs; slice
  24 GiB / 16 CPUs; TTL 12h; kept disks expire after 7 days.
- **C7. Guest internet.** Public IPv4 internet open, with host, private,
  tailnet, loopback and all IPv6 blocked (recommended), or offline by default with internet as a
  per-request opt-in.
- **C8. Disk cap.** A dedicated LV (needs free extents in `lvmroot`; check
  `sudo vgs`) or a loop-mounted sparse ext4 image. Proposed 64 GiB against
  88 GiB free on `/`.
- **C9. Language** for the CLI and runner: Go (repo convention) or Python.
- **C11. Remote viewing.** Agent VMs bind VNC/SSH to `127.0.0.1` and you view
  them via `ssh -L`. A tailscale-IP bind like wayvnc conflicts with
  `RestrictNetworkInterfaces=~tailscale0`. That restriction stops an escaped
  guest from serving on the tailnet, so keep it unless direct viewing is
  worth that exposure.
- **C12. Host-side test fixtures.** The Stillsuit harness reached a
  throwaway Vaultwarden on host `127.0.0.1` from the guest. Stage B blocks
  guest connections to host loopback. Options: run fixtures inside the guest
  (recommended), or add a per-request allowlist of host loopback ports. An
  allowlist reopens the path R10d closes, so each entry needs care.


## Probe results

`docs/plans/agent-vm/probe.nix`, run four times on sietch in the Nix sandbox
(nixpkgs from the flake lock, worktree at `8305a176`). Final run passed
(exit 0). Rerun 2026-10-29 on rebased `nixos` (`61d5196a`; systemd 262,
libvirt 12.8.0): passed, with the same results, including the R10g root
transient unit. The probe uses a single `agentvm` uid and one launch socket. The
per-slot users and sockets came out of the review and rely on the same
mechanisms. The probe used stand-in units with the proposed sandbox settings,
not a real QEMU guest. Guest behavior is validation step 2.

Stage A (libvirt):

| Invariant | Observed |
|---|---|
| wheel user outside `libvirtd`, no polkit agent: `virsh -c qemu:///system` | denied, "no polkit agent available to authenticate action 'org.libvirt.unix.manage'" |
| non-wheel user inside `libvirtd` | denied, "access denied by policy": the `mkBefore` rule beats the module's group rule |
| root | allowed |
| read-only connection (`virsh -r`) | allowed (R10f) |

Stage B sandbox and egress (same results for both launcher variants):

| Invariant | Observed |
|---|---|
| process identity | `agentvm`, groups `agent-vm,kvm,agentvm`, cgroup inside the agent slice |
| to host loopback service `127.0.0.1:8222` | blocked |
| to resolver stub `127.0.0.53:53` | reachable |
| to LAN peer `192.168.1.2:8000` (control: kabilan reaches it) | blocked |
| to public address `203.0.113.10:8000` (control: kabilan reaches it) | reachable |
| read `/home/kabilan/secret` and `/vault/data` (both 0644) | blocked |
| read `/nix/store` | allowed |
| kabilan connects to a listener inside the unit on `127.0.0.1`; reads its runtime dir | allowed |

Polkit-scoped `manage-units` grant (rejected design):

| Invariant | Observed |
|---|---|
| member `start/restart/stop agent-vm@t1` | allowed |
| `set-property`, `enable`, `daemon-reload`, `kill`, `reset-failed`, `stop sshd`, `start agent-vm@A_B` | denied |
| `systemd-run --uid=0`, `systemd-run --scope --unit=agent-vm@t3` | denied |
| `systemd-run --unit=agent-vm@t2 -p User=root id` | refused by systemd only ("already loaded or has a fragment file") |
| experiment: rule matching `probe-transient-*`; `systemd-run --wait --unit=probe-transient-x -p User=root id -u` | **ran as root, exit 0** (R10g) |

Socket launcher (recommended):

| Invariant | Observed |
|---|---|
| non-member connects | `PermissionError` on connect |
| bad id `A;rm` | runner replies `error bad-id`; nothing created |
| member launches `s1`, `s2`; client disconnects | both reply `ok`; instances keep running as `agentvm-launch@N-…-1000.service` (requester uid in the instance name) |
| third launch with `MaxConnections=2` | connection reset by systemd |
| member `systemctl stop 'agent-vm-launch@*'` | denied by polkit default |
| member `pkill -u agentvm -f sleep` | "Operation not permitted"; both still running |

Hardening added after review round 1 (socket-launched unit, run 4):

| Invariant | Observed |
|---|---|
| to a v6 LAN peer `2001:db8:1::2` (control: kabilan reaches it) | blocked by the all-new-v6 reject |
| to a non-private address on the host itself, `198.51.100.7:8333` (control: kabilan reaches it) | blocked by `addrtype LOCAL` |
| `socket(AF_VSOCK)` | refused (`RestrictAddressFamilies`) |
| `/run/dbus/system_bus_socket` exists | no (`TemporaryFileSystem=/run`) |
| read 0644 file in another `/var/lib` dir | blocked (`TemporaryFileSystem=/var/lib`) |
| `unshare --user` | refused (`RestrictNamespaces`) |

The v6 gap itself was not run as a separate before-and-after probe. The
earlier design had no IPv6 owner rule beyond the listed prefixes, and
neither LAN global prefixes nor `2001:db8::/32` fall in them.

## Review round 1

An independent reviewer (Claude subagent, read-only access to the repo, the
nixpkgs source and host metadata) checked the design. Adjudication:

| # | Finding | Status | Change |
|---|---|---|---|
| 1 | IPv6 egress gap: sietch has a global LAN prefix | confirmed (`ip -6 route`) | reject all new v6; `ipv6=off` for slirp; probe run 4 |
| 2 | escaped guest can bind on sietch's tailnet IP (`ts-input` accepts `tailscale0`, unprivileged ports from 80) | plausible, accepted | `RestrictNetworkInterfaces=~tailscale0`; C11 revised |
| 3 | failed `Accept=yes` instances keep counting against `MaxConnections` | contradicted by probe run 3: a failed instance existed when `s2` was accepted under `MaxConnections=2` | `CollectMode=inactive-or-failed` added for hygiene |
| 4 | one uid for all VMs: cross-instance QMP, disk and kill | plausible, accepted | per-slot uids and sockets |
| 5 | denylist misses world-writable sockets (Mullvad management, system bus, polkit agent helper) and world-readable `/var/lib` state | confirmed modes | allowlist via `TemporaryFileSystem` + `BindPaths`; probe run 4 |
| 6 | `AF_VSOCK` needs no device node; user namespaces open | plausible, accepted | `RestrictAddressFamilies`, `RestrictNamespaces`, `SystemCallFilter`; probe run 4 |
| 7 | `AUTH_ADMIN` prompt can be captured by a rogue polkit agent | plausible; same class as `sudo` | documented under R10c |
| 8 | `2770` slot dirs let members rename slot entries; `StateDirectory=` would chown as root | plausible, low | `3770`, `noexec`; no `StateDirectory=` |
| facts | `DeviceAllow` path globs unsupported; `TMPDIR` needs `USE_TMPDIR=1`; cwd-relative EFI/TPM paths; `useNixStoreImage` builds an erofs image per launch; NVIDIA `nvidia-modprobe` vs `spawn=deny` | confirmed in source/man | Stage B text corrected; GPU path is a step-2/3 test item |

Outside this proposal: on 2026-10-04 the reviewer found
`/var/lib/executor/data.db*` at `0644 root` and `/var/lib/siren` at `0755`.
Executor's state dir has been `0700`, owned by uid 65532, since commit
`28ae04ef`, so that finding is resolved.
