# VMs on sietch

Run QEMU directly, normally a NixOS VM runner (`nix build .#nixosConfigurations.<name>.config.system.build.vm`, then `result/bin/run-<name>-vm`). Don't use system libvirt (`qemu:///system`): it asks for Tony's password.

## Budget

All agent VMs share the `vms.slice` user slice: 16 CPUs and 28 GiB, no swap. A VM that pushes the slice over its memory cap gets killed.

- Default to 4 vCPUs and 8 GiB per VM; go up to 8 and 12 GiB when the guest needs it.
- Before starting, list what is running and its sizes: `systemctl --user list-units 'vm-*'`. Keep the total guest RAM of running VMs at or under 24 GiB, which leaves room for QEMU itself.
- Disks go in `/vault/userdata/vms/<name>/`. Use sparse qcow2 and check `df -h /vault` first; leave at least 100 GiB free.

## Start

```bash
mkdir -p /vault/userdata/vms/<name> && cd /vault/userdata/vms/<name>
NIX_DISK_IMAGE=$PWD/disk.qcow2 systemd-run --user --slice=vms.slice --unit=vm-<name> \
  -p RuntimeMaxSec=12h --same-dir -E NIX_DISK_IMAGE -E TMPDIR=$PWD \
  -- <runner>
```

`RuntimeMaxSec` stops a forgotten VM; raise it only when Tony asks for a long-running VM. `TMPDIR` keeps the runner's scratch folders (`nix-vm.*`) inside the VM folder, so deleting the folder removes them. Logs: `journalctl --user -u vm-<name>`.

For a NixOS runner, set these in the guest config:
- `virtualisation.forwardPorts` with `host.address = "127.0.0.1"`;
- `virtualisation.restrictNetwork = true` unless the guest needs the internet;
- `virtualisation.sharedDirectories.<tag>` with `writable = false` unless the guest must write.

For raw QEMU, use `-nic user,restrict=on,hostfwd=tcp:127.0.0.1:<port>-:22` and `-vnc 127.0.0.1:<n>`.

## Drive

- SSH through the forwarded `127.0.0.1` port.
- QMP for screenshots and real input: `-qmp unix:/vault/userdata/vms/<name>/qmp.sock,server=on,wait=off`. Unix socket paths must stay under 108 characters.
- GPU (virgl on the 3090) for compositor work: `-device virtio-vga-gl -display egl-headless,rendernode=/dev/dri/renderD128`.
- A test fixture on the host's `127.0.0.1`, such as a throwaway server, is `10.0.2.2` from the guest. `restrictNetwork` / `restrict=on` blocks that too.

## Stop

`systemctl --user stop vm-<name>`, then `rm -rf /vault/userdata/vms/<name>` unless Tony asked to keep the disk.

## When it fails

- `/dev/kvm` permission denied: run `id`. Without `kvm`, the session started before Tony's account joined the group; it needs a reboot or a fresh login, so tell Tony.
- `/dev/kvm` missing: the Codex sandbox hides it. The thread needs Full access.
- Guest killed with no error: the slice hit its memory cap. Check `systemctl --user status vms.slice`.
