---
paths:
  - .github/workflows/cache.yml
  - docs/security-hardening.md
---

# The slowest cache builds run on Namespace runners, which then hold the Cachix push token

niri, dictator-gui and disktree took 7–12 min on free 4 vCPU GitHub runners and held up every deploy that waited for them; a 16 vCPU Namespace runner builds them 3.6–4.6× faster (trial run 45074007413), cutting a deploy's wait for the cache from about 14 min to about 5 for roughly $1–2 a month. A self-hosted runner on sietch lost because it would put the push token on the machine agents run on. The price is a second party holding the push token while a build runs, through a GitHub app installed on this repository only.

## Consequences

- Namespace, or anyone who compromises it, can push to `kabilan108.cachix.org` during a build job, the same as GitHub could already. The token's expiry still bounds a stolen one.
- The runner profile `dotfiles-nix-16` is configured in Namespace's dashboard, not in this repository, so a diff cannot show a change to it. It must keep cache volumes and every cross-run caching option off: a volume carries a Nix store between runs, including runs from branches, and the publish step would push whatever a previous job left there.
- The Developer plan allows 32 vCPU at once and the profile allows two runners, so a deploy that rebuilds all three packages builds them in two waves.
- Pull requests never start a Namespace job, since the build job runs only on deploy tags. Any pushed branch can still name the runner label in a workflow and spend Namespace minutes, but it never reaches the token, which only the `cache-publish` environment holds.
