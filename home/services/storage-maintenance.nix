{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.services.storage-maintenance;
  homeDir = config.home.homeDirectory;

  cleanDeveloperCaches = pkgs.writeShellApplication {
    name = "clean-developer-caches";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
    ];
    text = ''
      clean_contents() {
        target="$1"
        if [ -d "$target" ]; then
          find "$target" -depth -mindepth 1 -delete
        fi
      }

      clean_contents "${homeDir}/.gradle/caches"
      clean_contents "${homeDir}/.gradle/.tmp"
      clean_contents "${homeDir}/.npm/_cacache"
      clean_contents "${homeDir}/.npm/_npx"
      clean_contents "${homeDir}/.cache/pnpm"
      clean_contents "${homeDir}/.cache/nix"
      clean_contents "${homeDir}/.cache/codex-runtimes"
      clean_contents "/vault/userdata/cache/bun-install"
      clean_contents "/vault/userdata/cache/uv"
      clean_contents "/vault/.pnpm-store"
    '';
  };

  pruneAppImageCache = pkgs.writeShellApplication {
    name = "prune-appimage-cache";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnugrep
      pkgs.gnused
    ];
    text = ''
      cache_dir="${homeDir}/.cache/appimage-run"
      [ -d "$cache_dir" ] || exit 0

      active_hashes="$(
        for executable in /proc/[0-9]*/exe; do
          readlink -f "$executable" 2>/dev/null || true
        done \
          | sed -n "s#^$cache_dir/\\([^/]*\\)/.*#\\1#p" \
          | sort -u
      )"

      for directory in "$cache_dir"/*; do
        [ -d "$directory" ] || continue
        hash="''${directory##*/}"
        if printf '%s\n' "$active_hashes" | grep -Fxq "$hash"; then
          continue
        fi
        if find "$directory" -maxdepth 0 -mtime +30 -print -quit | grep -q .; then
          find "$directory" -depth -mindepth 1 -delete
          rmdir "$directory"
        fi
      done
    '';
  };
in
{
  options.dotfiles.services.storage-maintenance.enable =
    lib.mkEnableOption "periodic storage maintenance";

  config = lib.mkIf cfg.enable {
    systemd.user.services = {
      clean-developer-caches = {
        Unit.Description = "Clear rebuildable developer caches";
        Service = {
          Type = "oneshot";
          ExecStart = lib.getExe cleanDeveloperCaches;
        };
      };

      prune-appimage-cache = {
        Unit.Description = "Prune inactive AppImage extractions older than 30 days";
        Service = {
          Type = "oneshot";
          ExecStart = lib.getExe pruneAppImageCache;
        };
      };
    };

    systemd.user.timers = {
      clean-developer-caches = {
        Unit.Description = "Quarterly developer cache cleanup";
        Timer = {
          OnCalendar = "quarterly";
          Persistent = true;
        };
        Install.WantedBy = [ "timers.target" ];
      };

      prune-appimage-cache = {
        Unit.Description = "Daily AppImage extraction pruning";
        Timer = {
          OnCalendar = "daily";
          Persistent = true;
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
  };
}
