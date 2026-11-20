# sietch notes

- Keep the `disable-wifi` unit rather than removing the Wi-Fi driver. sietch's wired 2.5 GbE link is its LAN data plane, and the radio hardware stays available for manual recovery.
- Take Blender from `pkgsCuda.blender`, not `blender.override`. Only that attribute matches the build cache.nixos-cuda.org serves; an override compiles CUDA Blender locally.
- Keep `services.tailscale.extraSetFlags` forced to an empty operator. Agents run as kabilan here, and the shared default in `configuration.nix` makes kabilan the operator; clearing it means changing Tailscale (Serve backends included) needs sudo.
- The Moberg Tailscale client (`dotfiles.mobergTailscale`) still has kabilan as operator, so agents can change that client without sudo. Revisit this if the office moves to Headscale.
