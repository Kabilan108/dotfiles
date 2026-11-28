# sietch notes

- Keep the `disable-wifi` unit rather than removing the Wi-Fi driver. sietch's wired 2.5 GbE link is its LAN data plane, and the radio hardware stays available for manual recovery.
- Take Blender from `pkgsCuda.blender`, not `blender.override`. Only that attribute matches the build cache.nixos-cuda.org serves; an override compiles CUDA Blender locally.
- Keep `services.tailscale.extraSetFlags` forced to an empty operator. Agents run as kabilan here, and the shared default in `configuration.nix` makes kabilan the operator; clearing it means changing Tailscale (Serve backends included) needs sudo.
- The Moberg Tailscale client (`dotfiles.mobergTailscale`) still has kabilan as operator, so agents can change that client without sudo. Revisit this if the office moves to Headscale.
- Keep NVIDIA early KMS (`nvidia`, `nvidia_modeset`, `nvidia_uvm`, `nvidia_drm` in `boot.initrd.kernelModules`) and `boot.loader.systemd-boot.configurationLimit = 8`. Without early KMS, UEFI GOP drives only `DP-1` during initrd so the LUKS prompt never appears on the JetKVM (`HDMI-A-1`); packing the NVIDIA driver and GSP firmware inflates initrd, so the lower generation limit keeps the 1 GiB `/boot` partition from filling up.
- Keep `services.resolved.enable = true` in `default.nix`. sietch's NetworkManager and Tailscale split DNS rely on `systemd-resolved`; dropping it alongside the old Mullvad daemon module left NetworkManager logging `resolvconf failed with status 256` and `tailscaled` fighting over `/etc/resolv.conf`.
