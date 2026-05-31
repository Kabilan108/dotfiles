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
    in
    {
      nixosConfigurations.tleilax = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs self; };
        modules = [
          agenix.nixosModules.default
          ./raspi-base.nix
          ./modules/jellyfin-client.nix
          ./modules/network-security.nix
        ];
      };

      # Flashable SD image. Build from jacurutu with:
      #   nix build ./raspi#nixosConfigurations.tleilax.config.system.build.sdImage
      # (requires boot.binfmt.emulatedSystems = [ "aarch64-linux" ]; on the build host)
    };
}
