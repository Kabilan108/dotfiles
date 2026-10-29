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
          chatgpt-desktop = import ./packages/chatgpt-desktop.nix { pkgs = final; };
          grok-bot = import ./packages/grok-bot.nix { pkgs = final; };
        })
        (import ./packages/security-overrides.nix)
        # Builds pagebin with this overlay set's bun, which `bun build --compile` embeds.
        inputs.pagebin.overlays.default
        inputs.atlas.overlays.default
        inputs.hark.overlays.default
        inputs.scout.overlays.default
        inputs.tracer.overlays.default
      ];

      makeSystem =
        {
          name,
          modules ? [ ],
        }:
        nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
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
            ./modules/nixos/moberg-tailscale.nix
            inputs.stylix.nixosModules.stylix
            ./modules/nixos/theme.nix
            ./modules/nixos/virt-manager.nix
            ./modules/nixos/syncthing.nix
            ./modules/nixos/desktop-wayland.nix
            # niri-flake packages and caches niri; its config.kdl lives in HM as a manual file.
            inputs."niri-flake".nixosModules.niri
            ./modules/nixos/wayland/niri.nix
          ]
          ++ modules;
        };
    in
    {
      nixosConfigurations = {
        sietch = makeSystem {
          name = "sietch";
          modules = [
            ./modules/nixos/nvidia.nix
            ./modules/nixos/xbox-controller.nix
            ./modules/nixos/mullvad-vpn.nix
          ];
        };
        jacurutu = makeSystem { name = "jacurutu"; };
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
    # Jacurutu's working boot stack before the October 2 display freezes.
    # Advance after kernel and AMD firmware have passed a boot test.
    jacurutu-boot-nixpkgs.url = "github:NixOS/nixpkgs/b1b875982b17dabde9b4a37f3e229e74913e6db3";

    # 3rd party flakes
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ghostty.url = "github:ghostty-org/ghostty/v1.4.0";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Update this dependency pin deliberately alongside llama.cpp, not system updates.
    llama-nixpkgs.url = "github:NixOS/nixpkgs/b1b875982b17dabde9b4a37f3e229e74913e6db3";
    # Temporary Zotero pin while its build is incompatible with Firefox 153.
    # Remove once https://github.com/Kabilan108/dotfiles/issues/18 is resolved.
    zotero-nixpkgs.url = "github:NixOS/nixpkgs/b1b875982b17dabde9b4a37f3e229e74913e6db3";
    llama-cpp = {
      url = "github:ggml-org/llama.cpp/e85caa81ea2b65797396018c179b87ad61fa38ab";
      inputs.nixpkgs.follows = "llama-nixpkgs";
    };
    # niri-flake stopped bumping its niri-unstable pin in August 2026; track
    # niri directly so fixes (e.g. SHM screencasting on NVIDIA) reach us.
    "niri-flake" = {
      url = "github:sodiboo/niri-flake";
      inputs.niri-unstable.url = "github:niri-wm/niri";
    };
    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    try.url = "github:tobi/try";
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # tools i maintain
    atlas = {
      url = "github:kabilan108/atlas";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dictator = {
      url = "github:kabilan108/dictator";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disktree = {
      url = "github:Kabilan108/disktree";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hark = {
      url = "github:Kabilan108/hark";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
    scout = {
      url = "github:Kabilan108/scout";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    siren = {
      url = "github:kabilan108/siren";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    tracer = {
      url = "github:kabilan108/tracer";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
