# agent-browser installation

Mise owns agent-browser only. `config/mise/config.toml` pins its version and
`config/mise/mise.lock` records the release archive URL and published checksum.
Home Manager links this directory to `~/.config/mise` and installs mise plus an
`agent-browser` launcher in the Nix user profile. Activation removes the legacy
pnpm agent-browser package after installing the replacement profile, so its old
shim cannot shadow the launcher.

The local Aqua recipe downloads the upstream npm release archive because the
standalone GitHub binary omits `skill-data`. It runs the bundled Linux x64 musl
binary directly, without Node, npm installation, or package lifecycle scripts.
The executable and `skills get core` guides therefore come from one version.

The launcher uses the fleet pin regardless of project-local mise configuration,
supplies Nix Chrome and FFmpeg, and preserves the caller's working directory.
Use `--executable-path` for an explicit alternative browser or `--cdp` to attach
to a shared browser. Helium remains the intentional shared-session path.

## Update

After activating the Home Manager configuration:

```sh
cd ~/dotfiles
mise upgrade agent-browser --bump --minimum-release-age 0s
agent-browser-smoke
git diff -- config/mise
```

The release-age override requests the newest release immediately. Omit it to
keep mise's normal release-age policy. Review the evidence directory printed by
the smoke check before committing the new pin and lock. Sync those files to the
other host and run `mise install --locked agent-browser` and the smoke check
there. Version-only updates need no Nix rebuild.

The weekly install-tools job replays the pin with `mise install --locked`; it
does not select a newer agent-browser release. Other tools retain their existing
pnpm/uv updater.

To roll back, restore the desired config and lock from Git and run
`mise install --locked agent-browser` again.

## Verification

`agent-browser-smoke` uses temporary profiles and a private namespace, checks
form interaction, screenshot capture, storage isolation, cursor-enabled recording
and video decoding, then closes its sessions. Inspect its PNGs/video for visual
acceptance. It does not use authenticated accounts or publish artifacts.

For noninteractive access, check `ssh sietch-agent 'agent-browser --version'`
after deployment. Source validation or testing a store-path launcher does not
prove the host's active PATH has migrated.
