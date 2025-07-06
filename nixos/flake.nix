{
  description = "kabilan's dotfiles";

  outputs =
    {
      self,
      nixpkgs,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        system = system;
        config.allowUnfree = true;
      };
      makeSystem =
        {
          name,
          modules ? [ ],
        }:
        nixpkgs.lib.nixosSystem {
          inherit system pkgs;
          specialArgs = { inherit inputs; };
          modules = [
            (./. + "/machines/${name}")
            ./user.nix
            ./dev.nix
            ./configuration.nix
          ] ++ modules;
        };
    in
    {
      nixosConfigurations = {
        sietch = makeSystem { name = "sietch"; };
        jacurutu = makeSystem { name = "jacurutu"; };
      };
    };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    capscreen.url = "github:kabilan108/capscreen";
    dictator.url = "github:kabilan108/dictator";
    diffgpt.url = "github:kabilan108/diffgpt";
    dump.url = "github:kabilan108/dump";
    rollouts.url = "github:kabilan108/rollouts";
  };
}
