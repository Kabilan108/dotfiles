{
  description = "tleilax — Raspberry Pi 4B (aarch64) NixOS, separate flake for the Pi's architecture and inputs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    herdr = {
      url = "github:herdrdev/herdr/v0.8.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      agenix,
      ...
    }@inputs:
    let
      system = "aarch64-linux";
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAllSystems =
        f: nixpkgs.lib.genAttrs systems (systemName: f nixpkgs.legacyPackages.${systemName});
      mkTleilaxRemote =
        pkgs:
        pkgs.writeShellApplication {
          name = "tleilax-remote";
          runtimeInputs = with pkgs; [
            bash
            codex
            coreutils
            curl
            findutils
            gawk
            tailscale
            wireplumber
          ];
          text = ''
            exec ${pkgs.python313}/bin/python3 ${./remote/server.py} "$@"
          '';
          meta = {
            description = "Phone-friendly Jellyfin and Pi control remote";
            mainProgram = "tleilax-remote";
          };
        };
    in
    {
      packages = forAllSystems (
        pkgs:
        let
          tleilaxRemote = mkTleilaxRemote pkgs;
        in
        {
          tleilax-remote = tleilaxRemote;
          default = tleilaxRemote;
        }
        // pkgs.lib.optionalAttrs pkgs.stdenv.isAarch64 {
          codex-preview = pkgs.callPackage ./packages/codex-preview.nix { };
          pi-coding-agent = pkgs.callPackage ./packages/pi-coding-agent { };
          t3-preview = pkgs.callPackage ./packages/t3-preview.nix { };
          cliproxyapi-openai-only = pkgs.callPackage ./packages/cliproxyapi-openai-only.nix { };
        }
      );

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            jq
            python313
            tailscale
          ];
        };
      });

      nixosConfigurations.tleilax = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs self; };
        modules = [
          agenix.nixosModules.default
          ./raspi-base.nix
          ./modules/airplay-receiver.nix
          ./modules/jellyfin-client.nix
          ./modules/network-security.nix
          ./modules/remote.nix
          ./modules/t3-v2-preview.nix
        ];
      };

      # Flashable SD image. Build from jacurutu with:
      #   nix build ./raspi#nixosConfigurations.tleilax.config.system.build.sdImage
      # (requires boot.binfmt.emulatedSystems = [ "aarch64-linux" ]; on the build host)
    };
}
