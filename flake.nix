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
            bun = pkgs-unstable.bun;
            ghostty = pkgs-unstable.ghostty;
            spotify = pkgs-unstable.spotify;
            openrgb = pkgs-unstable.openrgb;
            widsurf = pkgs-unstable.windsurf;
            code-cursor = final.callPackage ./packages/cursor.nix { };
            nomacs = final.callPackage ./packages/nomacs-viewer.nix { nomacs = prev.nomacs; };
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
          displayServer ? "x11",
        }:
        nixpkgs.lib.nixosSystem {
          inherit system pkgs;
          specialArgs = { inherit inputs theme displayServer; };
          modules = [
            (./. + "/machines/${name}")
            ./configuration.nix
            ./user.nix
            ./modules/nixos/virt-manager.nix
          ]
          ++ (
            if displayServer == "x11" then
              [ ./modules/nixos/deskotp-x11.nix ]
            else
              [ ./modules/nixos/desktop-wayland.nix ]
          )
          ++ modules;
        };
    in
    {
      nixosConfigurations = {
        sietch = makeSystem {
          name = "sietch";
          displayServer = "wayland";
          modules = [
            ./modules/nixos/nvidia.nix
            ./modules/nixos/xbox-controller.nix
            ./modules/nixos/mullvad-vpn.nix
          ];
        };
        jacurutu = makeSystem {
          name = "jacurutu";
          displayServer = "wayland";
          modules = [ ];
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

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-colors.url = "github:misterio77/nix-colors";

    hyprland.url = "github:hyprwm/Hyprland/v0.52.0";
    elephant.url = "github:abenz1267/elephant";
    walker = {
      url = "github:abenz1267/walker";
      inputs.elephant.follows = "elephant";
    };

    hy3 = {
      url = "github:outfoxxed/hy3?ref=hl0.52.0";
      inputs.hyprland.follows = "hyprland";
    };

    atlas.url = "github:kabilan108/atlas/go/claude-1";
    capscreen.url = "github:kabilan108/capscreen";
    dictator.url = "github:kabilan108/dictator";
    diffgpt.url = "github:kabilan108/diffgpt";
    dump.url = "github:kabilan108/dump";
    rollouts.url = "github:kabilan108/rollouts";
  };
}
