{ lib, ... }:
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
in
{
  home.file = mkCompletionLinks repoCompletions;
}
