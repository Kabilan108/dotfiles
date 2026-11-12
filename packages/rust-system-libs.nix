# nixos-unstable f4a03c0 makes Rust -sys crates link system libraries, and
# packages that never listed them fail to build. These copy the nixpkgs master
# fixes until nixos-unstable includes them; each throws once it does.
{ inputs }:
final: prev:
let
  addInputs =
    name: fixCommit: extraInputs:
    if prev.lib.elem final.zstd prev.${name}.buildInputs then
      throw "packages/rust-system-libs.nix: nixpkgs now includes ${fixCommit} for ${name}; remove its override"
    else
      prev.${name}.overrideAttrs (old: {
        buildInputs = old.buildInputs ++ extraInputs;
      });
  dictatorWithSqlite =
    package:
    package.overrideAttrs (old: {
      buildInputs = old.buildInputs ++ [ final.sqlite ];
    });
  dictatorPackages = inputs.dictator.packages.${final.stdenv.hostPlatform.system};
in
{
  # NixOS/nixpkgs@16b463698a
  codex = addInputs "codex" "16b463698a" [
    final.aws-lc
    final.oniguruma
    final.sqlite
    final.zstd
  ];
  # NixOS/nixpkgs@7e94c72bfc
  tabiew = addInputs "tabiew" "7e94c72bfc" [
    final.sqlcipher
    final.zstd
  ];
  # rusqlite now links system sqlite. Move this into dictator's flake.
  dictator = dictatorWithSqlite dictatorPackages.default;
  dictator-gui = dictatorWithSqlite dictatorPackages.gui;
}
