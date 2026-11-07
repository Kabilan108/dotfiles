# Temporary version bumps for security fixes that nixpkgs hasn't shipped yet.
# Drop each override once the pinned nixpkgs reaches (or passes) its version;
# the assertion below fails the build when that happens so stale pins don't linger.
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
}
