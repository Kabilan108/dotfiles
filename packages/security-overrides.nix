# Temporary version bumps for security fixes that nixpkgs hasn't shipped yet.
# Drop each override once the pinned nixpkgs reaches (or passes) its version;
# the assertion below fails the build when that happens so stale pins don't linger.
#
# - bun 1.4.4, uv 0.13.5, mise 2026.10.17: eMudhra intermediate CA compromise
#   (https://emudhra.we-have-a-problem.com/). bun and mise embed their own root
#   store; uv 0.13.5 explicitly rejects the compromised intermediate keys.
#   Tracking: nixpkgs #574334 (bun), #579045 (uv), 2ac163ef (mise, on master).
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

  uv = bumpOnce "uv" "0.13.5" "" (
    prev.uv.overrideAttrs (finalAttrs: _: {
      version = "0.13.5";
      src = prev.fetchFromGitHub {
        owner = "astral-sh";
        repo = "uv";
        tag = finalAttrs.version;
        hash = "sha256-SXTusm2EJ49tk03c3vSHcZp3AtAuj9SGOzsMwpnjXDw=";
      };
      cargoHash = "sha256-spQmSFAjNs6pWnw2nd/d3ZysIMK9j+BjDjrwcnUCmWw=";
    })
  );

  mise = bumpOnce "mise" "2026.10.17" "" (
    prev.mise.overrideAttrs (finalAttrs: old: {
      version = "2026.10.17";
      src = prev.fetchFromGitHub {
        owner = "jdx";
        repo = "mise";
        tag = "v${finalAttrs.version}";
        hash = "sha256-3JBs2i+07hY27EpIrmbMu7D5p6rGV6wuerilx0BECjw=";
      };
      cargoHash = "sha256-94BNmTVcJoY9ujO7boBzxMxaMy2tjLzpD+s+RLJxBEs=";
      # Sandbox-incompatible tests added in 2026.10.17; mirrors nixpkgs master.
      checkFlags = old.checkFlags ++ [
        "--skip"
        "file::tests::links::un_dmg_detaches_image_left_attached_by_interrupted_run"
        "--skip"
        "toolset::running::tests::finds_a_process_by_its_executable"
        "--skip"
        "toolset::running::tests::finds_a_process_through_a_symlinked_install_path"
        "--skip"
        "toolset::running::tests::matches_whole_path_components"
      ];
    })
  );
}
