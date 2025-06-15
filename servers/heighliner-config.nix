{
  pkgs,
  modulesPath,
  lib,
  ...
}:

let
  dotfilesRepo = "https://github.com/kabilan108/dotfiles.git";
  dotfilesPath = "/etc/dotfiles";
in
{
  imports = [
    (modulesPath + "/virtualisation/digital-ocean-config.nix")
  ];

  system.stateVersion = "25.05";

  networking = {
    hostName = "heighliner";

    firewall = {
      enable = true;
      allowedTCPPorts = [
        22
        80
        443
      ];
    };
  };

  services.nginx = {
    enable = true;

    virtualHosts."default" = {
      default = true;
      root = pkgs.runCommand "testdir" { } ''
        mkdir -p $out
        cat > $out/index.html <<EOF
        <!DOCTYPE html>
        <html>
        <head>
            <title>Deploy-rs Test Server</title>
            <style>
                body {
                    font-family: Arial, sans-serif;
                    max-width: 600px;
                    margin: 50px auto;
                    padding: 20px;
                    background-color: #f0f0f0;
                }
                .container {
                    background-color: white;
                    padding: 30px;
                    border-radius: 10px;
                    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
                }
                h1 { color: #333; }
                .status { 
                    color: #27ae60; 
                    font-weight: bold;
                }
                .info {
                    margin-top: 20px;
                    padding: 15px;
                    background-color: #ecf0f1;
                    border-radius: 5px;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>Deploy-rs Test Server</h1>
                <p class="status">Deployment Successful!</p>
                <div class="info">
                    <p><strong>Server:</strong> heighliner</p>
                    <p><strong>Deployed with:</strong> deploy-rs + NixOS</p>
                    <p><strong>Timestamp:</strong> <script>document.write(new Date().toLocaleString());</script></p>
                </div>
                <p>If you can see this page, your deployment is working correctly!</p>
            </div>
        </body>
        </html>
        EOF
      '';

      locations."/" = {
        index = "index.html";
      };
    };
  };

  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  programs.direnv.enable = true;
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  environment.systemPackages = with pkgs; [
    bash
    clang
    curl
    fd
    git
    gnumake
    htop
    jq
    llm
    ripgrep
    tmux
    wget
    xclip
  ];

  # Activation script to setup dotfiles for root user
  system.activationScripts.setupDotfiles = lib.stringAfter [ "users" ] ''
    echo "Setting up dotfiles for root user..."

    # Clone or update dotfiles
    if [ ! -d "${dotfilesPath}" ]; then
      ${pkgs.git}/bin/git clone ${dotfilesRepo} ${dotfilesPath}
    else
      cd ${dotfilesPath}
      ${pkgs.git}/bin/git pull || true
    fi

    # Create root directories
    mkdir -p /root/.config

    # Symlink bash configs
    for file in .bashrc .bash_profile .gitconfig .tmux.conf .vimrc; do
      if [ -f "${dotfilesPath}/conf/$file" ]; then
        ln -sf "${dotfilesPath}/conf/$file" "/root/$file"
      fi
    done

    # Symlink config directories
    if [ -d "${dotfilesPath}/conf/nvim" ]; then
      rm -rf "/root/.config/nvim"
      ln -sf "${dotfilesPath}/conf/nvim" "/root/.config/nvim"
    fi

    # Setup tmux plugins
    if [ ! -d "/root/.tmux/plugins/tpm" ]; then
      mkdir -p /root/.tmux/plugins
      ${pkgs.git}/bin/git clone https://github.com/tmux-plugins/tpm /root/.tmux/plugins/tpm || true
      ${pkgs.git}/bin/git clone -b v2.1.3 https://github.com/catppuccin/tmux.git /root/.tmux/plugins/catppuccin/tmux || true
    fi

    # Symlink bin directory if it exists
    if [ -d "${dotfilesPath}/bin" ]; then
      ln -sf "${dotfilesPath}/bin" /root/bin
    fi

    echo "Dotfiles setup complete for root user!"
  '';

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };
}
