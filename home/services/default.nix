{
  imports = [
    ./agent-server.nix
    ./backup.nix
    ./install-agent-clis.nix
    ./install-uv-tools.nix
    ./mic-volume-enforce.nix
    ./moberg.nix
    ./spotify-cache.nix
  ];

  dotfiles.services = {
    backup.enable = true;
    install-agent-clis.enable = true;
    install-uv-tools.enable = true;
    spotify-cache.enable = true;
  };
}
