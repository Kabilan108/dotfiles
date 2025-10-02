{
  description = "kabilan's dotfiles";

  outputs =
    {
      self,
      nixpkgs,
      unstable,
      nix-colors,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      pkgs-unstable = import unstable {
        system = system;
        config.allowUnfree = true;
      };
      pkgs = import nixpkgs {
        system = system;
        config.allowUnfree = true;
        overlays = [
          (final: prev: {
            ghostty = pkgs-unstable.ghostty;
            spotify = pkgs-unstable.spotify;
            code-cursor = final.callPackage ./packages/cursor { };
          })
        ];
      };

      theme = rec {
        name = "catppuccin-mocha";
        variant = "dark";
        colorScheme = nix-colors.colorSchemes.${name};
        palette = colorScheme.palette;
      };

      makeSystem =
        {
          name,
          modules ? [ ],
        }:
        nixpkgs.lib.nixosSystem {
          inherit system pkgs;
          specialArgs = { inherit inputs theme; };
          modules = [
            (./. + "/machines/${name}")
            ./configuration.nix
            ./common/user.nix
            ./common/virt-manager.nix
          ]
          ++ modules;
        };
    in
    {
      nixosConfigurations = {
        sietch = makeSystem {
          name = "sietch";
          modules = [
            ./common/desktop-x11.nix
            ./common/nvidia.nix
            ./common/xbox-controller.nix
            ./common/mullvad-vpn.nix
          ];
        };
        jacurutu = makeSystem {
          name = "jacurutu";
          modules = [
            ./common/desktop-x11.nix
          ];
        };
      };
    };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-colors.url = "github:misterio77/nix-colors";

    atlas.url = "github:kabilan108/atlas/go/claude-1";
    capscreen.url = "github:kabilan108/capscreen";
    dictator.url = "github:kabilan108/dictator";
    diffgpt.url = "github:kabilan108/diffgpt";
    dump.url = "github:kabilan108/dump";
    rollouts.url = "github:kabilan108/rollouts";
  };
}
