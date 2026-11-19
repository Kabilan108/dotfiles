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

    # Use the shared lock even inside a project with its own mise config.
    export MISE_GLOBAL_CONFIG_FILE=${lib.escapeShellArg "${config.home.homeDirectory}/dotfiles/config/mise/config.toml"}
    export MISE_CEILING_PATHS="$PWD"
    exec ${lib.getExe pkgs.mise} exec --locked -- gog "$@"
  '';
in
{
  options.programs.gogcli = {
    enable = lib.mkEnableOption "gog Google Workspace CLI with headless authentication";

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
    home.packages = [
      pkgs.mise
      gog
    ];

    home.activation.initializeGogcli = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [[ -r ${lib.escapeShellArg cfg.oauthClientFile} && -r ${lib.escapeShellArg cfg.keyringEnvironmentFile} ]]; then
        $DRY_RUN_CMD ${lib.getExe gog} auth credentials set \
          ${lib.escapeShellArg cfg.oauthClientFile} \
          --no-input
      fi
    '';
  };
}
