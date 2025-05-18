let
  pkgs = import <nixpkgs> { };
in
pkgs.mkShell {
  packages = [
    pkgs.nodejs_20
  ];

  shellHook = ''
    # set up npm global installs
    export NPM_CONFIG_PREFIX="$HOME/.npm-global"
    export PATH="$HOME/.npm-global/bin:$PATH"

    # install claude code
    if [ ! -f "$HOME/.npm-global/bin/claude" ]; then
      npm install -g @anthropic-ai/claude-code
    fi
  '';
}
