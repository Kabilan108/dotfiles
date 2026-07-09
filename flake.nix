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
      overlays = [
        (final: prev: {
          ghostty = inputs.ghostty.packages.${final.stdenv.hostPlatform.system}.default;
          code-cursor = final.callPackage ./packages/cursor.nix { };
        })
      ];

      makeSystem =
        {
          name,
          modules ? [ ],
          displayServer ? "x11",
          waylandCompositor ? "hyprland",
        }:
        nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit
              inputs
              displayServer
              waylandCompositor
              ;
          };
          modules = [
            {
              nixpkgs = {
                hostPlatform = system;
                config.allowUnfree = true;
                inherit overlays;
              };
            }
            (./. + "/machines/${name}")
            ./configuration.nix
            ./user.nix
            inputs.stylix.nixosModules.stylix
            ./modules/nixos/theme.nix
            ./modules/nixos/virt-manager.nix
            ./modules/nixos/syncthing.nix
          ]
          ++ (
            if displayServer == "x11" then
              [ ./modules/nixos/deskotp-x11.nix ]
            else
              # Wayland compositor configs live in HM; niri uses niri-flake for packaging/caching while keeping manual config files.
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
          waylandCompositor = "hyprland";
          modules = [
            ./modules/nixos/nvidia.nix
            ./modules/nixos/xbox-controller.nix
            ./modules/nixos/mullvad-vpn.nix
            ./modules/nixos/wayland/hyprland.nix
          ];
        };
        jacurutu = makeSystem {
          name = "jacurutu";
          displayServer = "wayland";
          waylandCompositor = "niri";
          modules = [
            inputs."niri-flake".nixosModules.niri
            ./modules/nixos/wayland/niri.nix
          ];
        };
      };
    };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
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

    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland.url = "github:hyprwm/Hyprland/v0.52.0";
    ghostty.url = "github:ghostty-org/ghostty/v1.3.1";
    "niri-flake".url = "github:sodiboo/niri-flake";
    elephant.url = "github:abenz1267/elephant";
    walker = {
      url = "github:abenz1267/walker";
      inputs.elephant.follows = "elephant";
    };

    hy3 = {
      url = "github:outfoxxed/hy3?ref=hl0.52.0";
      inputs.hyprland.follows = "hyprland";
    };

    atlas.url = "github:kabilan108/atlas";
    claude-bar.url = "github:kabilan108/claude-bar";
    dictator.url = "github:kabilan108/dictator";
    dump.url = "github:kabilan108/dump";
    pagebin = {
      url = "github:Kabilan108/pagebin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    raindrop.url = "github:kabilan108/raindrop";
    siren.url = "github:kabilan108/siren";
    tracer.url = "github:kabilan108/tracer";

    try.url = "github:tobi/try";
  };
}
