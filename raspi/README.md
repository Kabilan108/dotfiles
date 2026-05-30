# tleilax — Raspberry Pi 4B (NixOS)

Separate flake for the Pi: different architecture (`aarch64-linux`) and a lean input set
(no desktop inputs from the root dotfiles flake). Lives in the dotfiles repo for convenience;
small configs (e.g. tmux, agent configs) can be copied or pulled in as a flake input later.

## Phase 1 — bare headless NixOS

### 0. One-time: enable aarch64 emulation on the build host (jacurutu)
Add to jacurutu's config, then `nixos-rebuild switch`:

```nix
boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
```

This lets jacurutu build aarch64 artifacts. Most packages come prebuilt from the binary
cache; emulation only kicks in for the final image assembly and any uncached derivations.

### 1. Build the SD image (on jacurutu)

```sh
nix build ./raspi#nixosConfigurations.tleilax.config.system.build.sdImage
# result/sd-image/*.img.zst
```

### 2. Flash to the 128 GB SD card

```sh
zstd -d result/sd-image/*.img.zst -o /tmp/tleilax.img
lsblk                                  # identify the SD device, e.g. /dev/sdX
sudo dd if=/tmp/tleilax.img of=/dev/sdX bs=4M conv=fsync status=progress
```

### 3. Boot over Ethernet, then reach it

- Insert SD, connect Ethernet, power on. Green ACT LED blinks = it's reading the card/booting.
- It advertises mDNS, so from jacurutu:

```sh
ping tleilax.local
ssh kabilan@tleilax.local
```

Fallback if `.local` doesn't resolve: `nmap -sn 192.168.1.0/24` (adjust subnet) or the Xfinity app's device list.

### 4. Join Tailscale

```sh
sudo tailscale up
```

From here on, admin over Tailscale. Future changes never require reflashing:

```sh
nixos-rebuild switch --flake ./raspi#tleilax \
  --target-host kabilan@tleilax --use-remote-sudo
```

## Phase 1.5 — move root + Nix store to the SSD (after USB3 cable arrives)

Not a reflash. Partition/format the SSD, declare it as `/` by UUID, rebuild, reboot.
Firmware/boot stays on the SD; the SSD just becomes root. (Don't bother with the USB2 cable.)

## Phase 2 — hardening (see chat)

- Pi-only agenix identity + Pi-only secret files (`raspi/secrets.nix`).
- Dedicated unprivileged agent user + systemd sandboxing.
- Egress isolation: block LAN lateral movement, restrict the tailnet via Tailscale ACLs.
