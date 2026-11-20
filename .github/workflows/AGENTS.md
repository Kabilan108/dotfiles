# Workflow notes

- Keep the explicit bash default shell (defaults.run.shell) in `cache.yml`. GitHub Actions runs bash -e by default and adds -o pipefail only when a workflow names bash explicitly; the Build step pipes nix build into tee and needs the failure to propagate.
- Leave the `drvs` artifact in `cache.yml` at compression-level 0 and retention-days 1. The NARs inside are already zstd-compressed, and one day leaves time to re-run failed build jobs; a re-run of the plan job replaces the artifact.
