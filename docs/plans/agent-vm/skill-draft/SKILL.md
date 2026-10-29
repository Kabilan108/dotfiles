---
name: sietch-vm
description: Disposable VMs on sietch through the agent-vm launcher. Use when testing a compositor, desktop shell, session or installer inside a VM, or when inspecting, stopping or cleaning up an agent VM.
metadata:
  fleet-hosts: sietch
---

# Sietch VMs

Agent VMs on sietch run as per-slot `agentvm<N>` users, launched through the `agent-vm` slot sockets. Root-owned config sets those users' limits. The launcher is the supported way to get a VM with a display, SSH and QMP.

Use these VMs for unfamiliar repos and sketchy code. Keep credentials out of them: no tokens, keys or password-manager data go into a guest or its share directory.

Running `qemu-system-*` as your own user still works, because `/dev/kvm` is open to everyone. It skips the guest containment, caps and cleanup below, so reach for it only when Tony asks.

## What the host enforces

| Boundary | Enforced by | What you see |
|---|---|---|
| System libvirt (`qemu:///system`) needs Tony's password | polkit | "no polkit agent available" or "access denied". Ask Tony, who runs it himself |
| The VM process sees `/nix/store`, system config and its own slot dirs. `/home`, `/vault`, `/library`, other slots and most of `/run` and `/var/lib` are hidden | slot uid and unit sandbox | QEMU errors on any other path |
| Guest network: public IPv4 internet and DNS. Host addresses, loopback, LAN, tailnet, link-local and all IPv6 are rejected. Nothing can listen on the tailnet | iptables owner match, `RestrictNetworkInterfaces` | connection refused from the guest. That is policy, not a bug to fix |
| At most 3 VMs at once (one per slot), 12 GiB / 8 CPUs each, 24 GiB / 16 CPUs total | slot sockets, cgroup limits | `agent-vm start` reports no free slot; guest OOM-killed |
| Agent disks share a 64 GiB filesystem | dedicated mount | "No space left on device" in the guest |
| A VM lives at most 12 hours. Its disk is deleted on stop unless `--keep`, and kept disks expire after 7 days | `RuntimeMaxSec`, tmpfiles | VM gone after 12h |

## Run a VM

1. **Build the runner.** Make a NixOS configuration that imports `qemu-vm.nix` and points host paths at the launcher's variables:

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

   Pick SSH and VNC ports that no running VM uses (`agent-vm list` shows them). For guests that run internet code (installer ISOs, `curl | bash`), add `virtualisation.useNixStoreImage = true;` so the guest sees only its own closure. Build with `nix build .#nixosConfigurations.<name>.config.system.build.vm -o result-vm`. Done when `readlink -f result-vm` is a `/nix/store` path containing `bin/run-<name>-vm`.

2. **Launch.** `agent-vm start <id> --runner "$(readlink -f result-vm)/bin/run-<name>-vm"`. Add `--gpu` for virgl, `--keep` to retain the disk. Ids are lowercase letters, digits and dashes. Done when it prints `ok <id> <slot>` and `agent-vm status <id>` reports running. Take the share, QMP and runtime paths from `agent-vm status <id>`.

3. **Hand files to the guest.** Copy them into the share path from `status`. The guest sees it as `/mnt/share`. Copy build outputs in, and never share a repository: the guest can write to that directory, and nothing on the host should run what it writes.

4. **Drive and observe.**
   - Shell in the guest: `ssh -p 2222 <user>@127.0.0.1` with the key baked into the image.
   - Screenshots and synthetic input: QMP on the `qmp.sock` path from `status` (`screendump`, `input-send-event`).
   - Video or a live view: VNC on `127.0.0.1:5901`. Tony views it from jacurutu with `ssh -L 5901:127.0.0.1:5901 sietch`.

5. **Stop.** `agent-vm stop <id>`. Done when `agent-vm list` no longer shows it. Stop every VM you started before you finish the task, unless Tony asked to keep it running.

## When something is refused

Run test fixtures, such as a throwaway server, inside the guest. The guest cannot reach host loopback.

Treat a refusal from the table above as the answer. If the task truly needs more, such as bridged networking, IPv6, USB or PCI passthrough, rootful libvirt, larger caps or a tailnet-visible display, stop and ask Tony. Say which boundary the task hits and why.
