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
supplies the Nix-packaged Helium (`packages/helium.nix`) and FFmpeg, and preserves the caller's working directory.
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

Both machines run the weekly install-tools job on Monday at 04:00, plus up to
30 minutes of random delay. It installs the recorded version with
`mise install --locked agent-browser`. Other tools retain their pnpm/uv updates.

Jacurutu alone runs `mise-update` on Monday at 03:00, plus up to 30 minutes of
random delay. It selects the newest release at least seven days old, installs
and checks the locked executable's version, then commits only
`config/mise/mise.lock` and pushes to `origin/nixos`. These automatic commits
are unsigned and do not authorize a NixOS deployment.

The updater skips if the checkout is not on `nixos`, any files under
`config/mise` have local changes, or HEAD differs from the fetched remote branch.
Unrelated staged changes are left out of its commit. A failed push leaves the
commit locally; resolve it manually before the next update. It never force-pushes.

Pull the updated checkout on sietch to receive the lock before its next install.
The job does not pull or merge dotfiles automatically. Both timers catch up on
missed runs when started.

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
