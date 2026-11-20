# tleilax notes

## System and network

- tleilax builds from a bare `nixosSystem` in `flake.nix`, without the desktop modules or the shared overlays. Build atlas with `callPackage` from the atlas input and the Pi's own package set, as `atlas.nix` does, not from an overlay.
- Use only root's Nix here: do not make kabilan a trusted user or add a binary cache beyond cache.nixos.org. Nothing that sietch signs or serves may be trusted on this host.
- Bind every service to loopback. A tailnet-reachable one also sets `selfhost.tailnetServices.<name>.port`, and the tailnet policy (`docs/tailscale-policy.jsonc`) must let `tag:credentials` advertise it.
- Give atlas no tailnet service and no state. Only Executor on this box calls it, so the Jira and Bitbucket tokens never leave the Pi; each request carries its credentials in X-Atlas headers, and its MCP server mode skips the update check and the disk cache.
- Keep IPv6 off in `network.nix`, so the egress filter has no LAN IPv6 prefix to chase.
- `gateway` in `network.nix` is 10.0.0.1, the Xfinity router's default address, allowed for DNS and DHCP. Update it if the home LAN subnet changes.
- Install sessionizer in the home bin directory as well as the system packages; the laptop's picker attaches there. Its config offers only the home directory with `max_depth = 0`: deploy-gate gives the agent key the inventory alone, which carries the picker's previews, and opening a session uses Tony's login connection.

## Boot (hardware.nix, disko.nix)

- After changing `configTxt`, the firmware or u-boot, copy `system.build.raspberryPiFirmware` to the boot partition by hand. It is copied once at install; rebuilds update only extlinux and the kernels.
- Keep `enable_uart=1` and `avoid_warnings=1` in `configTxt`. u-boot needs the UART whether or not anything uses it, and without the second the firmware draws over the kernel's framebuffer.
- Keep the HDMI console (tty0) last in `boot.kernelParams`, so the disk passphrase prompt shows on screen.
- Keep adiantum, nhpoly1305, nhpoly1305_neon and chacha20 in `boot.initrd.luks.cryptoModules`. Kernel 6.18 has no poly1305 module to list; adiantum and nhpoly1305 pull in libpoly1305 themselves.
- Keep the initrd modules: pcie_brcmstb, reset_raspberrypi, xhci_pci, usb_storage and uas because the SSD sits behind the PCIe USB 3 controller, genet and broadcom for Ethernet and its PHY.
- The `device` in `disko.nix` matters only when formatting. The installed system finds its partitions by GPT label.

## Executor v2 (executor.nix, moberg-vpn.nix)

- To update Executor, bump the image tag, then re-pin the digest. Each beta release is a new tag.
- Keep `--stop-timeout=30` above Executor's shutdown grace. On SIGTERM the Executor host gives workerd 15 seconds before killing it, and Podman's default of 10 would kill the container first. Raise it if that grace period grows.
- Reject IPv6 in the `executor` nftables chain; do not drop it. workerd tries a name's next address only after a connection fails, so a drop hangs until timeout. The mounted gai config prefers IPv4 for the same reason.
- Route only the office subnet (10.1.10.0/24) through the Moberg VPN. Pushed routes and DNS are ignored on purpose; the office names resolve on public DNS. The profile is tleilax's own "tony2" credential, encrypted on jacurutu to this host and the YubiKeys.

## Alerts (alerts.nix)

- Send only the unit name and its result to Hark, never log lines. The webhook belongs to a service integration that only tleilax can decrypt.
- Skip self-alerting units through `dotfiles.alerts.exclude`, not a per-unit drop-in. A systemd drop-in cannot clear `OnFailure=`, because it is a dependency.
