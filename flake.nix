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
        (final: _prev: {
          ghostty = inputs.ghostty.packages.${final.stdenv.hostPlatform.system}.default;
          chatgpt-desktop = import ./packages/chatgpt-desktop.nix { pkgs = final; };
          grok-bot = import ./packages/grok-bot.nix { pkgs = final; };
          helium = import ./packages/helium.nix { pkgs = final; };
        })
        (import ./packages/rust-system-libs.nix)
        # Builds pagebin with this overlay set's bun, which `bun build --compile` embeds.
        inputs.pagebin.overlays.default
        inputs.atlas.overlays.default
        inputs.hark.overlays.default
        inputs.scout.overlays.default
        inputs.tracer.overlays.default
      ];

      # The deploy receiver only moves forward from this commit.
      configurationRevision = {
        system.configurationRevision = self.rev or self.dirtyRev or null;
      };

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
                config = {
                  allowUnfree = true;
                  # Zotero 10 bundles Firefox 140 ESR, which reached end of life on
                  # 2026-10-13. Remove once nixpkgs' Zotero moves to a supported ESR.
                  permittedInsecurePackages = [ "firefox-esr-140-bin-unwrapped-140.17.0esr" ];
                };
                inherit overlays;
              };
            }
            configurationRevision
            (./. + "/machines/${name}")
            ./configuration.nix
            ./user.nix
            ./modules/nixos/docker.nix
            ./modules/nixos/fleet.nix
            ./modules/nixos/backup
            ./modules/nixos/deploy
            ./modules/nixos/moberg-vpn.nix
            ./modules/nixos/moberg-tailscale.nix
            inputs.stylix.nixosModules.stylix
            ./modules/nixos/theme.nix
            ./modules/nixos/virt-manager.nix
            ./modules/nixos/teamviewer.nix
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
        # The Pi keeps none of the desktop modules or overlays above.
        tleilax = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          modules = [
            {
              nixpkgs = {
                hostPlatform = "aarch64-linux";
              };
            }
            configurationRevision
            ./machines/tleilax
          ];
        };
      };

      templates.devshell = {
        path = ./templates/devshell;
        description = "Flake with a dev shell for x86_64 and aarch64 Linux, loaded by direnv";
      };

      devShells.${system}.default =
        let
          pkgs = import nixpkgs {
            inherit system overlays;
            config.allowUnfree = true;
          };
        in
        pkgs.mkShell {
          DOTFILES_QML_IMPORT_PATH = "${pkgs.qt6.qtdeclarative}/lib/qt-6/qml:${pkgs.quickshell}/lib/qt-6/qml";
          packages = [
            (pkgs.python3.withPackages (ps: [ ps.jsonschema ]))
            pkgs.quickshell
            pkgs.sway
            pkgs.jq
            pkgs.ripgrep
            pkgs.libnotify
            pkgs.nixfmt
            pkgs.statix
            pkgs.deadnix
            pkgs.shellcheck
            pkgs.prek
            pkgs.nodejs
            pkgs.qt6.qtdeclarative
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
    };
    # tleilax's disk layout, used once at install and for its fileSystems.
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Build with the system nixpkgs so ghostty gets its glibc, Mesa ABI and
    # security fixes (its own nixpkgs shipped brotli 1.2.0, CVE-2026-111497).
    ghostty = {
      url = "github:ghostty-org/ghostty/v1.4.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # niri-flake stopped bumping its niri-unstable pin in August 2026; track
    # niri directly so fixes (e.g. SHM screencasting on NVIDIA) reach us.
    "niri-flake" = {
      url = "github:sodiboo/niri-flake";
      inputs.niri-unstable.url = "github:niri-wm/niri";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    try = {
      url = "github:tobi/try";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
    spindle = {
      url = "github:kabilan108/spindle";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    tracer = {
      url = "github:kabilan108/tracer";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
