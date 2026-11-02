# Temporary version bumps for security fixes that nixpkgs hasn't shipped yet.
# Drop each override once the pinned nixpkgs reaches (or passes) its version;
# the assertion below fails the build when that happens so stale pins don't linger.
#
# - bun 1.4.4: eMudhra intermediate CA compromise
#   (https://emudhra.we-have-a-problem.com/). bun embeds its own root store.
#   Tracking: nixpkgs #574334.
final: prev:
let
  bumpOnce =
    name: version: followUp: pkg:
    if prev.lib.versionAtLeast prev.${name}.version version then
      throw "packages/security-overrides.nix: nixpkgs now ships ${name} ${prev.${name}.version}; remove the ${version} override${followUp}"
    else
      pkg;
in
{
  # pagebin's own flake.lock pins a nixpkgs with a vulnerable bun, which only
  # matters for `nix run github:Kabilan108/pagebin`; dotfiles builds it via overlay.
  bun = bumpOnce "bun" "1.4.4" ". Also run `nix flake update nixpkgs` in ~/repos/cli/pagebin and open a PR, so standalone `nix run` builds get the fixed bun." (
    prev.bun.overrideAttrs (old: {
      version = "1.4.4";
      # src is derived from passthru.sources, which the version check can't see.
      __intentionallyOverridingVersion = true;
      passthru = old.passthru // {
        sources = old.passthru.sources // {
          "x86_64-linux" = prev.fetchurl {
            url = "https://github.com/oven-sh/bun/releases/download/bun-v1.4.4/bun-linux-x64-baseline.zip";
            hash = "sha256-4ERutVmVdy65iUvrrppr42jZhai5Jx7hJEhvmUbu3XY=";
          };
          "aarch64-linux" = prev.fetchurl {
            url = "https://github.com/oven-sh/bun/releases/download/bun-v1.4.4/bun-linux-aarch64.zip";
            hash = "sha256-uqa7NvUdblhWHgK76oJQOKnfRU9nPW13bou/hvjHhQ4=";
          };
        };
      };
    })
  );
}
