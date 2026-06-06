{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  cfg = config.tleilax.remote;
  homeDir = "/home/${cfg.user}";
  stateDir = "/var/lib/${cfg.stateDirectory}";
  startRemote = pkgs.writeShellScript "tleilax-remote-start" ''
    set -eu

    export XDG_RUNTIME_DIR="/run/user/$(${pkgs.coreutils}/bin/id -u ${lib.escapeShellArg cfg.user})"
    exec ${lib.getExe cfg.package}
  '';
in
{
  options.tleilax.remote = {
    enable = lib.mkEnableOption "phone remote for Jellyfin playback and Pi controls";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.tleilax-remote;
      defaultText = lib.literalExpression "self.packages.\${pkgs.stdenv.hostPlatform.system}.tleilax-remote";
      description = "Package that provides the tleilax-remote executable.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "kabilan";
      description = "User that owns the remote process and Jellyfin Desktop profile.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8787;
      description = "TCP port for the remote web server.";
    };

    workspace = lib.mkOption {
      type = lib.types.str;
      default = homeDir;
      description = "Working directory used for Codex jobs launched from the remote.";
    };

    stateDirectory = lib.mkOption {
      type = lib.types.str;
      default = "tleilax-remote";
      description = "systemd StateDirectory name for tokens and job logs.";
    };

    bindAddress = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Address to bind. Null waits for and binds to the Tailscale IPv4 address.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open the remote port on the tailscale0 firewall interface.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional EnvironmentFile for JELLYFIN_TOKEN, JELLYFIN_USER_ID, or API keys.";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    systemd.services.tleilax-remote = {
      description = "Tleilax Jellyfin remote";
      after = [
        "network-online.target"
        "tailscaled.service"
      ];
      wants = [
        "network-online.target"
        "tailscaled.service"
      ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        HOME = homeDir;
        REMOTE_CODEX_WORKSPACE = cfg.workspace;
        REMOTE_PORT = toString cfg.port;
        REMOTE_PRINT_TOKEN = "0";
        REMOTE_STATE_DIR = stateDir;
        REMOTE_TAILSCALE_WAIT_SECONDS = "60";
      }
      // lib.optionalAttrs (cfg.bindAddress != null) {
        REMOTE_BIND = cfg.bindAddress;
      };

      path = with pkgs; [
        bash
        codex
        coreutils
        curl
        findutils
        gawk
        tailscale
        wireplumber
      ];

      serviceConfig = {
        ExecStart = startRemote;
        Group = "users";
        Restart = "on-failure";
        RestartSec = 5;
        StateDirectory = cfg.stateDirectory;
        StateDirectoryMode = "0700";
        Type = "simple";
        UMask = "0077";
        User = cfg.user;
        WorkingDirectory = cfg.workspace;
      }
      // lib.optionalAttrs (cfg.environmentFile != null) {
        EnvironmentFile = cfg.environmentFile;
      };
    };
  };
}
