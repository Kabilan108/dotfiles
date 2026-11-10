{
  imports = [
    ./battery-watcher.nix
    ./codex-desktop.nix
    ./dictator.nix
    ./flake-update.nix
    ./grok-bot.nix
    ./mise-update.nix
    ./install-tools.nix
    ./meeting-minutes.nix
    ./mic-volume-enforce.nix
    ./moberg.nix
    ./russ-playlist-sync.nix
    ./solaar.nix
    ./storage-maintenance.nix
    ./t3-code.nix
    ./tracer-digest.nix
    ./tracer-sync.nix
    ./update-agents.nix
    ./update-app-pins.nix
    ./wayvnc.nix
  ];

  dotfiles.services = {
    battery-watcher.enable = true;
    install-tools.enable = true;
    meeting-minutes.enable = true;
    storage-maintenance.enable = true;
    update-agents.enable = true;
  };
}
