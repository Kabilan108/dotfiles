{
  config,
  lib,
  ...
}:
let
  completionsDir = ".local/share/bash-completion/completions";
  repoCompletions = lib.filterAttrs (name: type: type == "regular" && !(lib.hasSuffix ".md" name)) (
    builtins.readDir ./completions
  );

  mkCompletionLinks =
    completions:
    lib.mapAttrs' (name: _: {
      name = "${completionsDir}/${name}";
      value.source = ./completions + "/${name}";
    }) completions;

  packageCompletionPaths = [
    # Example: "${pkgs.awscli2}/share/bash-completion/completions/aws"
  ];

  mkPackageCompletionLinks =
    paths:
    lib.listToAttrs (
      map (path: {
        name = "${completionsDir}/${baseNameOf path}";
        value.source = path;
      }) paths
    );
in
{
  home.file = mkCompletionLinks repoCompletions // mkPackageCompletionLinks packageCompletionPaths;
}
