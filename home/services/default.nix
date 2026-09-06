{
  imports = [
    ./backup.nix
    ./battery-watcher.nix
    ./cliproxyapi.nix
    ./codex-desktop.nix
    ./codex-remote-control.nix
    ./install-tools.nix
    ./meeting-minutes.nix
    ./mic-volume-enforce.nix
    ./moberg.nix
    ./storage-maintenance.nix
    ./t3-code.nix
    ./tracer-digest.nix
    ./tracer-sync.nix
    ./update-agents.nix
    ./wayvnc.nix
  ];

  dotfiles.services = {
    backup.enable = true;
    battery-watcher.enable = true;
    cliproxyapi.enable = true;
    install-tools.enable = true;
    meeting-minutes.enable = true;
    storage-maintenance.enable = true;
    update-agents.enable = true;
  };
}
