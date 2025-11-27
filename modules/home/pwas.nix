{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.programs.pwas;
  iconDir = "${config.home.homeDirectory}/.local/share/icons/dashboardicons";
  iconsUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png";

  mkEntry =
    app:
    let
      name = app.name;
      url = app.url;
      iconSlug = app.icon; # dashboardicons slug (png)
      wmClass = if app.class == null then name else app.class;
      profile = app.profile;
      cats = app.categories;
      iconPath = "${iconDir}/${iconSlug}.png";
      exec = "${pkgs.ungoogled-chromium}/bin/chromium --profile-directory=${profile} --class=${wmClass} --new-window --app=${url}";
    in
    {
      name = lib.replaceStrings [ " " ] [ "-" ] (lib.toLower name);
      value = {
        name = name;
        exec = exec;
        icon = iconPath; # absolute path works fine
        terminal = false;
        type = "Application";
        comment = "PWA: ${name}";
        categories = cats;
        settings = {
          StartupWMClass = wmClass;
        };
      };
    };

  iconFetcher = pkgs.writeShellScript "pwa-icon-fetcher" ''
    set -euo pipefail
    mkdir -p "${iconDir}"
    base="https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png"

    ${lib.concatStringsSep "\n" (
      map (app: ''
        if [ ! -f "${iconDir}/${app.icon}.png" ]; then
          ${pkgs.curl}/bin/curl -fsSL "${iconsUrl}/${app.icon}.png" -o "${iconDir}/${app.icon}.png" || {
            echo "warning: failed to fetch icon ${app.icon}" >&2
          }
        fi
      '') cfg.apps
    )}
  '';

in
{
  options.programs.pwas = {
    enable = lib.mkEnableOption "PWA desktop entries";
    apps = lib.mkOption {
      type =
        with lib.types;
        listOf (submodule {
          options = {
            name = lib.mkOption {
              type = str;
              description = "App name (shown in menus)";
            };
            url = lib.mkOption {
              type = str;
              description = "https URL";
            };
            icon = lib.mkOption {
              type = str;
              description = "dashboardicons slug (png)";
            };
            class = lib.mkOption {
              type = nullOr str;
              default = null;
              description = "WM_CLASS override (defaults to name)";
            };
            profile = lib.mkOption {
              type = nullOr str;
              default = "Default";
              description = "Profile directory";
            };
            categories = lib.mkOption {
              type = listOf str;
              default = [ "Network" ];
              description = "XDG categories";
            };
          };
        });
      default = [ ];
      description = "List of PWAs to expose as desktop apps.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.ungoogled-chromium ];

    # create .desktop entries
    xdg.desktopEntries = builtins.listToAttrs (map mkEntry cfg.apps);

    # fetch/update icons at activation time
    home.activation.pwaIcons = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${iconFetcher}
    '';
  };
}
