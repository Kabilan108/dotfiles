{ pkgs, ... }:
{
  system.activationScripts.code-agents.text = ''
    ${pkgs.sudo}/bin/sudo -u kabilan ${pkgs.bash}/bin/bash -c '
      export NPM_CONFIG_PREFIX="$HOME/.npm-global"
      export PATH="${pkgs.bash}/bin:${pkgs.coreutils}/bin:${pkgs.nodejs_20}/bin:$NPM_CONFIG_PREFIX/bin:$PATH"

      mkdir -p "$NPM_CONFIG_PREFIX/bin"

      for pkg in @anthropic-ai/claude-code opencode-ai@latest ccusage; do
        if ! command -v "$(basename "$pkg")" >/dev/null 2>&1; then
          ${pkgs.nodejs_20}/bin/npm install -g "$pkg" || echo "npm failed to install $pkg"
        fi
      done
    '
  '';
}
