{
  imports = [
    ./agent-server.nix
    ./backup.nix
    ./install-uv-tools.nix
    ./mic-volume-enforce.nix
    ./moberg.nix
    ./spotify-cache.nix
    ./update-agents.nix
  ];

  dotfiles.services = {
    backup.enable = true;
    install-uv-tools.enable = true;
    spotify-cache.enable = true;
    update-agents.enable = true;
  };
}
