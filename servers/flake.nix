{
  description = "heighliner server configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    deploy-rs.url = "github:serokell/deploy-rs";
  };

  outputs =
    {
      self,
      nixpkgs,
      deploy-rs,
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
        modules = [ ./heighliner-config.nix ];
      };

      deploy.nodes.heighliner = {
        hostname = "heighliner";
        profiles.system = {
          user = "root";
          path = deployPkgs.deploy-rs.lib.activate.nixos self.nixosConfigurations.heighliner;
        };
      };

      # deployment checks - this validates the deploy configuration
      checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;

      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [ deploy-rs.packages.${system}.default ];
      };
    };
}
