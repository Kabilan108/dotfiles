# System libvirt asks for an admin password per connection, and /dev/kvm is limited to the kvm group

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

- System libvirt is root-equivalent. The libvirtd module's polkit rule passes members of the `libvirtd` group without a password.
- systemd ships `/dev/kvm` as 0666, so every service account can use it. systemd's own `static_node` rule resets it to 0666 when udevd restarts.
- libvirt runs QEMU unprivileged (`qemu.runAsRoot = false`), so `qemu-libvirtd` needs `/dev/kvm`.
- Nix's build sandbox drops supplementary groups, so `kvm` group membership doesn't reach NixOS tests. Their primary group, `nixbld`, survives.

## Decision

- A polkit rule, added with `mkBefore` so it runs ahead of the libvirtd module's rule, returns `AUTH_ADMIN` for `org.libvirt.unix.manage` and `org.libvirt.unix.monitor` to wheel members and `NO` to everyone else. `AUTH_ADMIN` has no grant caching, so every connection asks.
- A udev rule sets `/dev/kvm` to group `kvm`, mode 0660, with `OPTIONS+="static_node=kvm"` so udevd reapplies it each time it starts, and gives `nixbld` an ACL entry. `kabilan` and `qemu-libvirtd` are in `kvm`.

## Consequences

- Each virt-manager connection to system libvirt asks for an admin password.
- Service accounts outside `kvm` and `nixbld` can't use KVM.

## Where

- `modules/nixos/virt-manager.nix` (`security.polkit.extraConfig`, `services.udev.extraRules`, `users.groups.kvm.members`)
