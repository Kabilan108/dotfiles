{
  description = "python devshell with uv";

  # see https://www.nixhub.io/packages/python for version hashes
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: let
    system = "x86_64-linux";
    pkgs   = import nixpkgs {
      inherit system; config.allowUnfree = true;
    };
  in {
    devShell.${system} = pkgs.mkShell {
      buildInputs = with pkgs; [
        python312Full
        uv
        git
      ];

      shellHook = ''
        export LD_LIBRARY_PATH=${
          pkgs.lib.makeLibraryPath [
            pkgs.zlib
            pkgs.stdenv.cc.cc
          ]
        }:/run/opengl-driver/lib:$LD_LIBRARY_PATH
      '';
    };
  };
}
