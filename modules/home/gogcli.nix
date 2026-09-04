{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.gogcli;
  gogHome = "${config.xdg.dataHome}/gogcli";
  gog = pkgs.writeShellScriptBin "gog" ''
    set -a
    source ${lib.escapeShellArg cfg.keyringEnvironmentFile}
    set +a

    export GOG_HOME=${lib.escapeShellArg gogHome}
    export GOG_KEYRING_BACKEND=file

    exec ${lib.getExe cfg.package} "$@"
  '';
in
{
  options.programs.gogcli = {
    enable = lib.mkEnableOption "gog Google Workspace CLI with headless authentication";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../../packages/gogcli.nix { };
      defaultText = lib.literalExpression "pkgs.callPackage ../../packages/gogcli.nix { }";
      description = "The gogcli package to wrap.";
    };

    oauthClientFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/agenix/secrets/gog-oauth-client";
      description = "Google OAuth client JSON used to initialize gogcli.";
    };

    keyringEnvironmentFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/agenix/secrets/gog-keyring-env";
      description = "Shell environment file containing GOG_KEYRING_PASSWORD.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ gog ];

    home.activation.initializeGogcli = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [[ -r ${lib.escapeShellArg cfg.oauthClientFile} && -r ${lib.escapeShellArg cfg.keyringEnvironmentFile} ]]; then
        $DRY_RUN_CMD ${lib.getExe gog} auth credentials set \
          ${lib.escapeShellArg cfg.oauthClientFile} \
          --no-input
      fi
    '';
  };
}
