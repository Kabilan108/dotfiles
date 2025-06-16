{
  description = "heighliner server configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    deploy-rs.url = "github:serokell/deploy-rs";
    rollout.url = "github:kabilan108/rollout";
    agenix.url = "github:ryantm/agenix";
  };

  outputs =
    {
      self,
      nixpkgs,
      deploy-rs,
      rollout,
      agenix,
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      deployPkgs = import nixpkgs {
        inherit system;
        overlays = [
          deploy-rs.overlays.default
          (self: super: {
            deploy-rs = {
              inherit (pkgs) deploy-rs;
              lib = super.deploy-rs.lib;
            };
          })
        ];
      };
    in
    {
      nixosConfigurations.heighliner = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./heighliner-config.nix
          {
            _module.args.rolloutPkg = rollout.packages.${system}.default;
          }
          agenix.nixosModules.default
        ];
      };

      deploy.nodes.heighliner = {
        hostname = "heighliner";
        sshUser = "root";
        profiles.system = {
          user = "root";
          path = deployPkgs.deploy-rs.lib.activate.nixos self.nixosConfigurations.heighliner;
        };
      };

      # deployment checks - this validates the deploy configuration
      checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;

      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [
          agenix.packages.${system}.default
          deploy-rs.packages.${system}.default
          pkgs.nodejs_20
        ];
        shellHook = ''
          export NPM_CONFIG_PREFIX="$HOME/.npm-global"
          export PATH="$HOME/.npm-global/bin:$PATH"
          if [ ! -f "$HOME/.npm-global/bin/claude" ]; then
            npm install -g @anthropic-ai/claude-code
          fi
          if [ ! -f "$HOME/.npm-global/bin/ccusage" ]; then
            npm install -g ccusage
          fi
        '';
      };
    };
}
