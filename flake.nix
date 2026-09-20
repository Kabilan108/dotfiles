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
            ./modules/nixos/docker.nix
            ./modules/nixos/fleet.nix
            ./modules/nixos/moberg-vpn.nix
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

      devShells.${system}.default =
        let
          pkgs = import nixpkgs {
            inherit system overlays;
            config.allowUnfree = true;
          };
        in
        pkgs.mkShell {
          packages = [
            (pkgs.python3.withPackages (ps: [ ps.jsonschema ]))
            pkgs.quickshell
            pkgs.sway
            pkgs.jq
            pkgs.ripgrep
            pkgs.libnotify
            pkgs.nixfmt
          ];
        };
    };

  inputs = {
    # machine setup
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # 3rd party flakes
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    codex-desktop-linux = {
      url = "github:ilysenko/codex-desktop-linux";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    elephant.url = "github:abenz1267/elephant";
    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ghostty.url = "github:ghostty-org/ghostty/v1.3.1";
    herdr = {
      url = "github:herdrdev/herdr/v0.8.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hy3 = {
      url = "github:outfoxxed/hy3?ref=hl0.52.0";
      inputs.hyprland.follows = "hyprland";
    };
    hyprland.url = "github:hyprwm/Hyprland/v0.52.0";
    # Update this dependency pin deliberately alongside llama.cpp, not system updates.
    llama-nixpkgs.url = "github:NixOS/nixpkgs/b1b875982b17dabde9b4a37f3e229e74913e6db3";
    llama-cpp = {
      url = "github:ggml-org/llama.cpp/e85caa81ea2b65797396018c179b87ad61fa38ab";
      inputs.nixpkgs.follows = "llama-nixpkgs";
    };
    "niri-flake".url = "github:sodiboo/niri-flake";
    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    try.url = "github:tobi/try";
    walker = {
      url = "github:abenz1267/walker";
      inputs.elephant.follows = "elephant";
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # tools i maintain
    atlas.url = "github:kabilan108/atlas";
    claude-bar.url = "github:kabilan108/claude-bar";
    dictator.url = "github:kabilan108/dictator/rust-port";
    dump.url = "github:kabilan108/dump";
    hark.url = "github:Kabilan108/hark";
    omasnap = {
      url = "github:Kabilan108/omasnap/niri-native";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    omarecord = {
      url = "github:Kabilan108/omarecord";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pagebin = {
      url = "github:Kabilan108/pagebin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    raindrop.url = "github:kabilan108/raindrop";
    siren.url = "github:kabilan108/siren";
    tracer.url = "github:kabilan108/tracer";
  };
}
