{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.services.install-tools;
  homeDir = config.home.homeDirectory;
  pnpmHome = "${homeDir}/.local/share/pnpm";

  installTools = pkgs.writeShellScript "install-tools" ''
    set -euo pipefail
    failures=()

    update_tool() {
      local name="$1"
      shift
      echo "Updating $name"
      if "$@"; then
        echo "Updated $name"
      else
        local status=$?
        echo "Failed to update $name (exit $status)" >&2
        failures+=("$name")
      fi
    }

    update_tool llm ${pkgs.uv}/bin/uv tool install -U --with llm-cmd --with llm-openrouter --with llm-tmux-fragments llm
    # Trusted owner-maintained package: follow Git HEAD without a release-age hold.
    update_tool viewh5 ${pkgs.uv}/bin/uv tool install -U --from git+https://github.com/kabilan108/viewh5 viewh5

    for package in @steipete/summarize ccusage @earendil-works/pi-coding-agent; do
      update_tool "$package" ${pkgs.pnpm}/bin/pnpm add -g -y "$package"
    done

    # Replay the reviewed pin; new releases are selected with an explicit mise bump.
    update_tool agent-browser ${pkgs.coreutils}/bin/env \
      MISE_GLOBAL_CONFIG_FILE=${lib.escapeShellArg "${homeDir}/dotfiles/config/mise/config.toml"} \
      MISE_CEILING_PATHS="$PWD" \
      ${lib.getExe pkgs.mise} install --locked agent-browser

    if (( ''${#failures[@]} )); then
      printf 'Tool updates failed: %s\n' "''${failures[*]}" >&2
      exit 1
    fi
  '';
in
{
  options.dotfiles.services.install-tools.enable = lib.mkEnableOption "third-party tool refresh";

  config = lib.mkIf cfg.enable {
    systemd.user.services.install-tools = {
      Unit = {
        Description = "Install/Update third-party tools";
        After = "network-online.target";
      };
      Service = {
        Type = "oneshot";
        Environment = [
          "PNPM_HOME=${pnpmHome}"
          "PATH=${
            lib.makeBinPath [
              pkgs.git
              pkgs.nodejs_24
              pkgs.pnpm
              pkgs.uv
            ]
          }:${pnpmHome}:${pnpmHome}/bin:${homeDir}/.local/bin"
        ];
        ExecStart = "${installTools}";
      };
    };

    systemd.user.timers.install-tools = {
      Unit.Description = "Weekly third-party tool refresh";
      Timer = {
        OnCalendar = "Mon *-*-* 04:00:00";
        RandomizedDelaySec = "30m";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
