{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.programs.appimages;
  appDir = "${config.home.homeDirectory}/.local/share/appimages";

  mkWrapper =
    name: app:
    let
      args = lib.escapeShellArgs app.args;
    in
    pkgs.writeShellScriptBin name ''
      set -euo pipefail

      latest=$(find "${appDir}" -maxdepth 1 -name '${app.pattern}' -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -n1 | cut -d' ' -f2-)
      if [ -z "$latest" ]; then
        ${lib.getExe pkgs.libnotify} -u critical "${app.desktopName}" "AppImage not found in ${appDir}"
        exit 1
      fi
      ${app.preExec}
      chmod +x "$latest"
      exec "$latest" ${args} "$@"
    '';
  wrappers = lib.mapAttrs mkWrapper cfg.apps;

  bootstrapper = pkgs.writeShellScript "bootstrap-appimages" ''
    set -euo pipefail
    mkdir -p "${appDir}"

    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: app: ''
        if ! find "${appDir}" -maxdepth 1 -name '${app.pattern}' -type f 2>/dev/null | grep -q .; then
          echo "Bootstrapping ${app.desktopName}..."
          ${lib.getExe pkgs.gh} release download --repo ${app.repo} \
            --pattern '${app.downloadPattern}' -D "${appDir}" || \
            echo "Warning: failed to download ${app.desktopName}. Download manually to ${appDir}." >&2
        fi
      '') cfg.apps
    )}
  '';
in
{
  options.programs.appimages = {
    enable = lib.mkEnableOption "AppImage management with auto-update support";

    apps = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            repo = lib.mkOption {
              type = lib.types.str;
              description = "GitHub owner/repo for release downloads";
            };
            pattern = lib.mkOption {
              type = lib.types.str;
              description = "Glob pattern to find AppImage files in the app directory";
            };
            downloadPattern = lib.mkOption {
              type = lib.types.str;
              description = "Pattern for gh release download --pattern";
            };
            desktopName = lib.mkOption {
              type = lib.types.str;
              description = "Display name for the desktop entry";
            };
            comment = lib.mkOption {
              type = lib.types.str;
              default = "";
            };
            args = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Default arguments to pass to the AppImage before caller-provided arguments";
            };
            preExec = lib.mkOption {
              type = lib.types.lines;
              default = "";
              description = "Shell code to run after resolving the AppImage and before executing it";
            };
            icon = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Icon name or path for the desktop entry";
            };
            startupWMClass = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "StartupWMClass value for the desktop entry";
            };
            executableSessionVariable = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Session variable that should point to this app's generated wrapper executable";
            };
            categories = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ "Application" ];
            };
          };
        }
      );
      default = { };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.attrValues wrappers;

    home.sessionVariables = lib.mapAttrs' (
      name: app: lib.nameValuePair app.executableSessionVariable "${wrappers.${name}}/bin/${name}"
    ) (lib.filterAttrs (_: app: app.executableSessionVariable != null) cfg.apps);

    xdg.desktopEntries = lib.mapAttrs (
      name: app:
      {
        name = app.desktopName;
        exec = "${name} %U";
        terminal = false;
        type = "Application";
        comment = app.comment;
        categories = app.categories;
      }
      // lib.optionalAttrs (app.icon != null) {
        icon = app.icon;
      }
      // lib.optionalAttrs (app.startupWMClass != null) {
        settings = {
          StartupWMClass = app.startupWMClass;
        };
      }
    ) cfg.apps;

    home.activation.bootstrapAppImages = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${bootstrapper}
    '';
  };
}
