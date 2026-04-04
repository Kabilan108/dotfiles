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
    pkgs.writeShellScriptBin name ''
      latest=$(find "${appDir}" -maxdepth 1 -name '${app.pattern}' -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -n1 | cut -d' ' -f2-)
      if [ -z "$latest" ]; then
        ${lib.getExe pkgs.libnotify} -u critical "${app.desktopName}" "AppImage not found in ${appDir}"
        exit 1
      fi
      chmod +x "$latest"
      exec "$latest" "$@"
    '';

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
    home.packages = lib.mapAttrsToList mkWrapper cfg.apps;

    xdg.desktopEntries = lib.mapAttrs (name: app: {
      name = app.desktopName;
      exec = "${name} %U";
      terminal = false;
      type = "Application";
      comment = app.comment;
      categories = app.categories;
    }) cfg.apps;

    home.activation.bootstrapAppImages = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${bootstrapper}
    '';
  };
}
