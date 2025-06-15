{
  pkgs,
  modulesPath,
  ...
}:

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

  environment.systemPackages = with pkgs; [
    neovim
    git
    htop
    curl
    wget
  ];

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
}
