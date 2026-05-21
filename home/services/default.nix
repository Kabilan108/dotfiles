{
  imports = [
    ./agent-server.nix
    ./backup.nix
    ./install-tools.nix
    ./mic-volume-enforce.nix
    ./moberg.nix
    ./spotify-cache.nix
    ./update-agents.nix
  ];

  dotfiles.services = {
    backup.enable = true;
    install-tools.enable = true;
    spotify-cache.enable = true;
    update-agents.enable = true;
  };
}
