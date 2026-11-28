{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.opencodeBrowse;
  browse = pkgs.symlinkJoin {
    name = "opencode-browse-wrapped-${pkgs.opencode-browse.version}";
    paths = [ pkgs.opencode-browse ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/browse" \
        --set OPENCODE_BROWSER_AUTO_UPDATE off \
        --set-default OPENCODE_BROWSER_AGENT_WINDOW separate \
        --set OPENCODE_BROWSER_PORT ${toString cfg.port} \
        ${lib.optionalString (cfg.relay == "forwarded") "--set OPENCODE_BROWSER_AUTOSTART 0"}
    '';
    inherit (pkgs.opencode-browse) meta;
  };
in
{
  options.dotfiles.opencodeBrowse = {
    relay = lib.mkOption {
      type = lib.types.enum [
        "local"
        "forwarded"
      ];
      default = "local";
      description = "Whether agents here start their own browse relay, or only use one forwarded to this host's loopback by `browse-relay-tunnel` from the machine with the browser.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 19988;
      description = "Loopback port of the relay, on both the browser's machine and machines it is forwarded to. The extension only finds 19988 and 19990-19997 by itself.";
    };
  };

  config = {
    home.packages = [ browse ];

    systemd.user.services.browse-relay = lib.mkIf (cfg.relay == "local") {
      Unit.Description = "browse relay for the browse browser extension";
      Service = {
        ExecStart = "${lib.getExe browse} serve";
        Restart = "on-failure";
        RestartSec = "5s";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
