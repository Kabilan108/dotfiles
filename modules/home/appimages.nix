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

  autoUpdateApps = lib.filterAttrs (_: app: app.autoUpdate) cfg.apps;

  updater = pkgs.writeShellApplication {
    name = "update-appimages";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      gh
      jq
      libnotify
    ];
    text = ''
      app_dir=${lib.escapeShellArg appDir}
      failed=0
      declare -a staging_dirs=()
      trap 'if (( ''${#staging_dirs[@]} > 0 )); then rm -rf -- "''${staging_dirs[@]}"; fi' EXIT

      update_app() {
        local display_name="$1"
        local repo="$2"
        local local_pattern="$3"
        local download_pattern="$4"
        local assets
        local asset
        local release
        local published_at
        local published_epoch
        local now_epoch
        local release_age
        local target
        local staging_dir
        local -a matching_assets=()

        if ! release=$(gh release view --repo "$repo" --json assets,publishedAt); then
          notify-send -u critical "$display_name update failed" "Could not check the latest GitHub release." || true
          failed=1
          return
        fi

        published_at=$(jq -r '.publishedAt' <<< "$release")
        if ! published_epoch=$(date --date="$published_at" +%s); then
          notify-send -u critical "$display_name update failed" "Could not read the latest release date." || true
          failed=1
          return
        fi

        now_epoch=$(date +%s)
        release_age=$(( now_epoch - published_epoch ))
        if (( release_age <= 7 * 24 * 60 * 60 )); then
          printf '%s release is not yet more than seven days old: %s\n' "$display_name" "$published_at"
          return
        fi

        assets=$(jq -r '.assets[].name' <<< "$release")

        while IFS= read -r asset; do
          # shellcheck disable=SC2053 # The release asset is matched against a configured glob.
          if [[ "$asset" == $download_pattern ]]; then
            matching_assets+=("$asset")
          fi
        done <<< "$assets"

        if (( ''${#matching_assets[@]} != 1 )); then
          notify-send -u critical "$display_name update failed" "Expected one release asset matching $download_pattern, found ''${#matching_assets[@]}." || true
          failed=1
          return
        fi

        asset="''${matching_assets[0]}"
        target="$app_dir/$asset"
        if [[ -e "$target" ]]; then
          printf '%s is current: %s\n' "$display_name" "$asset"
          return
        fi

        staging_dir=$(mktemp -d "$app_dir/.update.XXXXXX")
        staging_dirs+=("$staging_dir")
        if ! gh release download --repo "$repo" --pattern "$download_pattern" --dir "$staging_dir"; then
          rm -rf -- "$staging_dir"
          notify-send -u critical "$display_name update failed" "Could not download $asset." || true
          failed=1
          return
        fi

        if [[ ! -s "$staging_dir/$asset" ]]; then
          rm -rf -- "$staging_dir"
          notify-send -u critical "$display_name update failed" "The downloaded AppImage was missing or empty." || true
          failed=1
          return
        fi

        chmod 0755 "$staging_dir/$asset"
        mv -- "$staging_dir/$asset" "$target"
        rmdir -- "$staging_dir"

        find "$app_dir" -maxdepth 1 -name "$local_pattern" -type f -printf '%T@ %p\0' \
          | sort -z -nr \
          | tail -z -n +3 \
          | cut -z -d ' ' -f 2- \
          | xargs -0 -r rm -f --

        notify-send "$display_name updated" "Installed $asset. Restart $display_name to use it." || true
      }

      mkdir -p "$app_dir"

      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (_name: app: ''
          update_app \
            ${lib.escapeShellArg app.desktopName} \
            ${lib.escapeShellArg app.repo} \
            ${lib.escapeShellArg app.pattern} \
            ${lib.escapeShellArg app.downloadPattern}
        '') autoUpdateApps
      )}

      exit "$failed"
    '';
  };

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
            autoUpdate = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Whether to periodically install the latest matching GitHub release asset";
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

    systemd.user.services.update-appimages = lib.mkIf (autoUpdateApps != { }) {
      Unit.Description = "Update managed AppImages";
      Service = {
        Type = "oneshot";
        ExecStart = lib.getExe updater;
      };
    };

    systemd.user.timers.update-appimages = lib.mkIf (autoUpdateApps != { }) {
      Unit.Description = "Weekly managed AppImage update check";
      Timer = {
        OnCalendar = "weekly";
        RandomizedDelaySec = "2h";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
