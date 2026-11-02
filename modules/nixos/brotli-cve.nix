# CVE-2026-111497 (brotli decoder out-of-bounds write, CISA KEV).
# The locked nixpkgs (3ec636362e18) still ships brotli 1.2.0. The 1.2.1 bump
# is NixOS/nixpkgs#577208, merged only to staging. Tracking: NixOS/nixpkgs#577796.
#
# TODO: remove once nixos-unstable ships brotli >= 1.2.1.
#
# Graft, not an overlay: overlaying pkgs.brotli would rebuild every dependent.
# system.replaceDependencies.replacements (formerly system.replaceRuntimeDependencies)
# rewrites store-path references in the system closure. Verified against
# nixos/modules/system/activation/top-level.nix at the pinned nixpkgs rev:
# each entry is { oldDependency, newDependency }.
#
# replaceDirectDependencies requires equal store-path name lengths, and the
# replacement must be the same output. brotli-1.2.0 and brotli-1.2.1 are the
# same length, and so are the -lib and -dev suffixes.
#
# The decoder is only in the lib output (libbrotlidec.so.1,
# SONAME unchanged in 1.2.1). out is the CLI, which NEEDs that .so; dev is
# headers. pkgs.nix does not reference out or dev, and listing them makes
# replaceDependencies warn on every eval, so only lib is grafted. If something
# does pull the CLI into the closure, that path references lib and the graft
# rewrites it.
#
# The Nix daemon is covered. nix-util NEEDs libbrotlidec.so.1 / libbrotlienc.so.1
# from this lib output, and config.nix.package (nix 2.34.9) is in both
# environment.systemPackages and systemd.packages, so it is inside the toplevel
# closure this graft rewrites. The initrd stays on cutoffPackages by default
# and does not run the daemon.
{
  pkgs,
  lib,
  ...
}:
let
  brotli121 = pkgs.brotli.overrideAttrs (
    finalAttrs: _old: {
      version = "1.2.1";
      src = pkgs.fetchFromGitHub {
        owner = "google";
        repo = "brotli";
        tag = "v${finalAttrs.version}";
        hash = "sha256-llY72cYffDv0ugsH0p89xIPEbElV4L8u7U/Fe8hT3gI=";
      };
    }
  );

  sameLength =
    output: lib.stringLength pkgs.brotli.${output}.name == lib.stringLength brotli121.${output}.name;
in
{
  assertions = [
    {
      assertion = lib.versionOlder pkgs.brotli.version "1.2.1";
      message = "modules/nixos/brotli-cve.nix: nixpkgs now ships brotli ${pkgs.brotli.version}; remove the CVE-2026-111497 graft";
    }
    {
      assertion = pkgs.brotli.outputs == brotli121.outputs && lib.all sameLength pkgs.brotli.outputs;
      message = "modules/nixos/brotli-cve.nix: brotli 1.2.1 must keep the same outputs and store-path name lengths as ${pkgs.brotli.version} (replaceDependencies requirement)";
    }
  ];

  system.replaceDependencies.replacements = [
    {
      oldDependency = pkgs.brotli.lib;
      newDependency = brotli121.lib;
    }
  ];
}
