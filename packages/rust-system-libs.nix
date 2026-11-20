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
  tabiew = addInputs "tabiew" "7e94c72bfc" [
    final.sqlcipher
    final.zstd
  ];
}
