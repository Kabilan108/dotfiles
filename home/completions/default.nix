{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  bashCompletionDir = "share/bash-completion/completions";
  completionsDir = ".local/${bashCompletionDir}";

  repoCompletions = lib.filterAttrs (
    name: type: type == "regular" && name != "default.nix" && !(lib.hasSuffix ".md" name)
  ) (builtins.readDir ./.);

  mkCompletionLinks =
    completions:
    lib.mapAttrs' (name: _: {
      name = "${completionsDir}/${name}";
      value.source = ./. + "/${name}";
    }) completions;

  pkgCompletionLinks = {
    "${completionsDir}/atlas".source = "${
      inputs.atlas.packages.${pkgs.system}.default
    }/${bashCompletionDir}/atlas";
  };
in
{
  home.file = mkCompletionLinks repoCompletions // pkgCompletionLinks;
}
