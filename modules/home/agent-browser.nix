{
  config,
  lib,
  pkgs,
  ...
}:
let
  miseConfigDir = "${config.home.homeDirectory}/dotfiles/config/mise";
  launcher = pkgs.writeShellScriptBin "agent-browser" ''
    # Use the fleet pin, even inside projects with their own mise toolchain.
    export MISE_GLOBAL_CONFIG_FILE=${lib.escapeShellArg "${miseConfigDir}/config.toml"}
    export MISE_CEILING_PATHS="$PWD"
    export AGENT_BROWSER_EXECUTABLE_PATH=${lib.getExe pkgs.google-chrome}
    export PATH=${lib.makeBinPath [ pkgs.ffmpeg-full ]}:"$PATH"
    exec ${lib.getExe pkgs.mise} exec --locked -- agent-browser "$@"
  '';
in
{
  home.packages = [
    pkgs.mise
    launcher
  ];

  # Remove the old pnpm shim only after the replacement profile is installed.
  home.activation.removeLegacyPnpmAgentBrowser = lib.hm.dag.entryAfter [ "installPackages" ] ''
    legacy=${lib.escapeShellArg "${config.home.homeDirectory}/.local/share/pnpm/bin/agent-browser"}
    if [ -e "$legacy" ] || [ -L "$legacy" ]; then
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/env \
        PNPM_HOME=${lib.escapeShellArg "${config.home.homeDirectory}/.local/share/pnpm"} \
        PATH=${
          lib.makeBinPath [
            pkgs.nodejs_24
            pkgs.coreutils
          ]
        }:${config.home.homeDirectory}/.local/share/pnpm/bin:"$PATH" \
        ${lib.getExe pkgs.pnpm} remove -g agent-browser
    fi
  '';

  # Keep the version and lock writable by `mise upgrade --bump` in the checkout.
  xdg.configFile."mise".source = config.lib.file.mkOutOfStoreSymlink miseConfigDir;
}
