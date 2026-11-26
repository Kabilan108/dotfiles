{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.gh;
  tokenFile = lib.escapeShellArg cfg.tokenFile;
  launcher = pkgs.writeShellScript "gh" ''
    if [[ -z ''${GH_TOKEN-} && -z ''${GITHUB_TOKEN-} && -r ${tokenFile} ]]; then
      token=$(<${tokenFile})
      if [[ -n $token ]]; then
        export GH_TOKEN=$token
      fi
      unset token
    fi
    exec ${lib.getExe pkgs.gh} "$@"
  '';
in
{
  options.dotfiles.gh = {
    enable = lib.mkEnableOption "gh with its token read from an agenix file instead of the OS keyring";

    tokenFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/agenix/secrets/gh-token";
      description = "File holding the GitHub token that gh exports as GH_TOKEN when it is readable.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = pkgs.symlinkJoin {
        name = "gh-agenix-token-${pkgs.gh.version}";
        paths = [ pkgs.gh ];
        postBuild = ''
          rm "$out/bin/gh"
          ln -s ${launcher} "$out/bin/gh"
        '';
        meta.mainProgram = "gh";
      };
      description = "gh wrapped to read its token from tokenFile.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];
  };
}
