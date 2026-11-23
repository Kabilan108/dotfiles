# Workflow notes

- Keep the explicit bash default shell (defaults.run.shell) in `cache.yml`. GitHub Actions runs bash -e by default and adds -o pipefail only when a workflow names bash explicitly; the Build step pipes nix build into tee and needs the failure to propagate.
- Leave the `drvs` artifact in `cache.yml` at compression-level 0 and retention-days 1. The NARs inside are already zstd-compressed, and one day leaves time to re-run failed build jobs; a re-run of the plan job replaces the artifact.
- Put a package on `namespace-profile-dotfiles-nix-16` in `cache.yml` only when a trial shows a real speedup on the same derivation. ghostty stays on GitHub: its zig build gained only 1.9× on 16 vCPU (run 45074007413), and a third Namespace job waits for one of the profile's two runners.
- Keep cache volumes, Docker caching and the other cross-run caching options off in the Namespace profile `dotfiles-nix-16`, and its access level at Restricted. The profile lives in Namespace's dashboard, so no diff shows a change to it; a cache volume would carry a Nix store between runs, and the publish step would push whatever an earlier job left (ADR 0010).
