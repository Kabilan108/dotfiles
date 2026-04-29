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
            cloudflared = pkgs-unstable.cloudflared;
            ghostty = inputs.ghostty.packages.${system}.default;
            obsidian = pkgs-unstable.obsidian;
            openrgb = pkgs-unstable.openrgb;
            openrgb-with-all-plugins = pkgs-unstable.openrgb-with-all-plugins;
            prek = pkgs-unstable.prek;
            spotify = pkgs-unstable.spotify;
            widsurf = pkgs-unstable.windsurf;
            yazi = pkgs-unstable.yazi;
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
          waylandCompositor ? "hyprland",
        }:
        nixpkgs.lib.nixosSystem {
          inherit system pkgs;
          specialArgs = { inherit inputs theme displayServer waylandCompositor; };
          modules = [
            (./. + "/machines/${name}")
            ./configuration.nix
            ./user.nix
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
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
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
    raindrop.url = "github:kabilan108/raindrop";
    tracer.url = "github:kabilan108/tracer";

    try.url = "github:tobi/try/55baadc3f90ee7b7cbfa3d6c7b2c29db22151d5d";
    worktrunk.url = "github:max-sixty/worktrunk";
  };
}
