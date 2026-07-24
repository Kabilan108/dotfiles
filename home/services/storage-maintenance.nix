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

  reportStaleDirenvs = pkgs.writeShellApplication {
    name = "report-stale-direnvs";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnugrep
    ];
    text = ''
      cutoff="$(date -d "90 days ago" +%s)"
      active_cwds="$(
        for process_cwd in /proc/[0-9]*/cwd; do
          readlink -f "$process_cwd" 2>/dev/null || true
        done | sort -u
      )"

      candidates=()
      while IFS= read -r direnv_dir; do
        project="''${direnv_dir%/.direnv}"
        profile_mtime="$(
          find "$direnv_dir" -maxdepth 1 -type l -name "flake-profile*" \
            -printf "%T@\n" 2>/dev/null | sort -nr | head -n 1
        )"
        if [ -z "$profile_mtime" ]; then
          profile_mtime="$(stat -c %Y "$direnv_dir")"
        else
          profile_mtime="''${profile_mtime%%.*}"
        fi

        if [ "$profile_mtime" -gt "$cutoff" ]; then
          continue
        fi

        active=false
        while IFS= read -r active_cwd; do
          case "$active_cwd" in
            "$project" | "$project"/*)
              active=true
              break
              ;;
          esac
        done <<< "$active_cwds"
        if "$active"; then
          continue
        fi

        profile_date="$(date -d "@$profile_mtime" +%F)"
        candidates+=("- \`$project\` — $profile_date")
      done < <(
        find "${homeDir}" /vault -xdev -type d -name .direnv -prune 2>/dev/null \
          | sort -u
      )

      notify_args=()
      if [ "''${STALE_DIRENV_REPORT_DRY_RUN:-0}" = 1 ]; then
        notify_args+=(--dry-run)
      fi

      if [ "''${#candidates[@]}" -eq 0 ]; then
        "${homeDir}/dotfiles/bin/discord-notify" \
          --title "No stale direnv environments" \
          --status success \
          --body "No inactive direnv profiles older than 90 days were found." \
          "''${notify_args[@]}"
        exit 0
      fi

      printf "%s\n" "''${candidates[@]}" \
        | "${homeDir}/dotfiles/bin/discord-notify" \
          --title "''${#candidates[@]} stale direnv environments" \
          --status warning \
          "''${notify_args[@]}"
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

      report-stale-direnvs = {
        Unit.Description = "Report stale direnv environments";
        Service = {
          Type = "oneshot";
          ExecStart = lib.getExe reportStaleDirenvs;
          WorkingDirectory = homeDir;
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

      report-stale-direnvs = {
        Unit.Description = "Monthly stale direnv report";
        Timer = {
          OnCalendar = "monthly";
          Persistent = true;
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
  };
}
