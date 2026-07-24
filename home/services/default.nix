{
  imports = [
    ./agent-server.nix
    ./backup.nix
    ./cliproxyapi.nix
    ./codex-desktop.nix
    ./install-tools.nix
    ./meeting-minutes.nix
    ./mic-volume-enforce.nix
    ./moberg.nix
    ./spotify-cache.nix
    ./storage-maintenance.nix
    ./tracer-digest.nix
    ./tracer-sync.nix
    ./update-agents.nix
    ./wayvnc.nix
  ];

  dotfiles.services = {
    backup.enable = true;
    cliproxyapi.enable = true;
    install-tools.enable = true;
    meeting-minutes.enable = true;
    spotify-cache.enable = true;
    storage-maintenance.enable = true;
    update-agents.enable = true;
  };
}
