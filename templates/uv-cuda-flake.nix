{
  description = "python devshell with uv and cuda support";

  # see https://www.nixhub.io/packages/python for version hashes
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs_py3919.url = "github:NixOS/nixpkgs/5ed627539ac84809c78b2dd6d26a5cebeb5ae269";
  };

  outputs = { self, nixpkgs, nixpkgs_py3919 }: let
    system = "x86_64-linux";
    pkgs   = import nixpkgs {
      inherit system; config.allowUnfree = true; config.cudaSupport = true;
    };
    oldPkgs   = import nixpkgs_py3919 {
      inherit system; config.allowUnfree = true; config.cudaSupport = true;
    };
  in {
    devShell.${system} = pkgs.mkShell {
      buildInputs = with pkgs; [
        oldPkgs.python39Full
        uv
        git
        cudaPackages.cudatoolkit
        cudaPackages.cudnn
      ];

      shellHook = ''
        export CUDA_PATH=${pkgs.cudaPackages.cudatoolkit}
        export LD_LIBRARY_PATH=${
          pkgs.lib.makeLibraryPath [
            pkgs.zlib
            pkgs.stdenv.cc.cc
            pkgs.cudaPackages.cudatoolkit
            pkgs.cudaPackages.cudnn
          ]
        }:/run/opengl-driver/lib:$LD_LIBRARY_PATH

        export UV_SYSTEM_PYTHON=1

        # include this if installing packages from private git repos over ssh
        eval "$(ssh-agent -s)"
        ssh-add $HOME/.ssh/bitbucket
      '';
    };
  };
}
