{
  imports = [
    ./agent-server.nix
    ./backup.nix
    ./codex-desktop.nix
    ./install-tools.nix
    ./kittylitter.nix
    ./mic-volume-enforce.nix
    ./moberg.nix
    ./spotify-cache.nix
    ./update-agents.nix
    ./wayvnc.nix
  ];

  dotfiles.services = {
    backup.enable = true;
    install-tools.enable = true;
    kittylitter.enable = true;
    spotify-cache.enable = true;
    update-agents.enable = true;
  };
}
