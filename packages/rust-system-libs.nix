# nixos-unstable f4a03c0 makes Rust -sys crates link system libraries, and
# packages that never listed them fail to build. These copy the nixpkgs master
# fixes until nixos-unstable includes them; each throws once it does.
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
}
