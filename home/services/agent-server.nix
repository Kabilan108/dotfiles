{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.services.agent-server;

  agentServerStart = pkgs.writeShellScript "agent-server-start" ''
    set -eu
    source "$HOME/.bashenv"

    export PATH="${
      pkgs.lib.makeBinPath [
        pkgs.gcc
        pkgs.gnumake
        pkgs.python3
      ]
    }:$PATH"

    TAILNET_IP="$(${pkgs.tailscale}/bin/tailscale ip -4)"

    ${pkgs.tmux}/bin/tmux new-session -d -s agents \
      "npx t3 serve --host $TAILNET_IP --port 3773 --no-browser"

    ${pkgs.tmux}/bin/tmux split-window -t agents \
      "codex app-server --listen ws://$TAILNET_IP:8390"
  '';
in
{
  options.dotfiles.services.agent-server.enable = lib.mkEnableOption "persistent agent servers";

  config = lib.mkIf cfg.enable {
    systemd.user.services.agent-server = {
      Unit = {
        Description = "Persistent agent servers (Tailscale)";
        After = [ "network-online.target" ];
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStartPre = "-${pkgs.tmux}/bin/tmux kill-session -t agents";
        ExecStart = agentServerStart;
        ExecStop = "${pkgs.tmux}/bin/tmux kill-session -t agents";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
