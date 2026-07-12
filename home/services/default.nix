{
  imports = [
    ./agent-server.nix
    ./backup.nix
    ./cliproxyapi.nix
    ./codex-desktop.nix
    ./install-tools.nix
    ./mic-volume-enforce.nix
    ./moberg.nix
    ./spotify-cache.nix
    ./tracer-digest.nix
    ./tracer-sync.nix
    ./update-agents.nix
    ./wayvnc.nix
  ];

  dotfiles.services = {
    backup.enable = true;
    cliproxyapi.enable = true;
    install-tools.enable = true;
    spotify-cache.enable = true;
    update-agents.enable = true;
  };
}
