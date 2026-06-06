{
  description = "tleilax — Raspberry Pi 4B (aarch64) NixOS, separate flake for the Pi's architecture and inputs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    agenix = {
      url = "github:ryantm/agenix";
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
      packages = forAllSystems (pkgs: rec {
        tleilax-remote = mkTleilaxRemote pkgs;
        default = tleilax-remote;
      });

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
        ];
      };

      # Flashable SD image. Build from jacurutu with:
      #   nix build ./raspi#nixosConfigurations.tleilax.config.system.build.sdImage
      # (requires boot.binfmt.emulatedSystems = [ "aarch64-linux" ]; on the build host)
    };
}
