{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.services.t3-code;
  defaultT3Version = lib.escapeShellArg cfg.t3Version;
  versionFile = "${config.xdg.configHome}/t3-code/version";

  t3CodeStart = pkgs.writeShellScript "t3-code-start" ''
    set -eu
    source "$HOME/.bashenv"

    export PATH="${
      pkgs.lib.makeBinPath [
        pkgs.gcc
        pkgs.gnumake
        pkgs.python3
      ]
    }:$PATH"

    version_file=${lib.escapeShellArg versionFile}
    if [[ -e "$version_file" ]]; then
      t3_version=$(< "$version_file")
    else
      t3_version=${defaultT3Version}
    fi

    exec npx --yes "t3@$t3_version" serve \
      --host 0.0.0.0 \
      --port 3773 \
      --tailscale-serve \
      --tailscale-serve-port 443
  '';

  t3CodeVersion = pkgs.writeShellApplication {
    name = "t3-code-version";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.nodejs_24
      pkgs.systemd
    ];
    text = ''
      version_file=${lib.escapeShellArg versionFile}

      if (( $# == 0 )); then
        if [[ -e "$version_file" ]]; then
          cat "$version_file"
        else
          echo ${defaultT3Version}
        fi
        exit 0
      fi

      if (( $# != 1 )); then
        echo "Usage: t3-code-version [VERSION|TAG]" >&2
        exit 2
      fi

      requested_version=$1
      resolved_version="$(npm view --silent "t3@$requested_version" version)"
      if [[ -z "$resolved_version" ]]; then
        echo "Unable to resolve t3@$requested_version from npm." >&2
        exit 1
      fi

      mkdir -p "$(dirname "$version_file")"
      printf '%s\n' "$requested_version" > "$version_file"

      systemctl --user restart t3-code.service
      echo "T3 Code server restarted with t3@$requested_version (resolves to $resolved_version)"
    '';
  };
in
{
  options.dotfiles.services.t3-code = {
    enable = lib.mkEnableOption "T3 Code server exposed through Tailscale Serve";
    t3Version = lib.mkOption {
      type = lib.types.str;
      default = "0.0.27";
      description = "Default T3 Code version used when ~/.config/t3-code/version does not exist.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ t3CodeVersion ];

    systemd.user.services.t3-code = {
      Unit = {
        Description = "T3 Code server exposed through Tailscale Serve";
        After = [ "network-online.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = t3CodeStart;
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
