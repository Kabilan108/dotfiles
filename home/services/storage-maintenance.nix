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

      clean_contents "/vault/userdata/cache/gradle/caches"
      clean_contents "/vault/userdata/cache/gradle/.tmp"
      clean_contents "/vault/userdata/cache/npm/_cacache"
      clean_contents "/vault/userdata/cache/npm/_npx"
      clean_contents "/vault/userdata/cache/pnpm-cache"
      clean_contents "/vault/userdata/cache/pnpm-store"
      clean_contents "${homeDir}/.cache/nix"
      clean_contents "${homeDir}/.cache/codex-runtimes"
      clean_contents "/vault/userdata/cache/bun-install"
      clean_contents "/vault/userdata/cache/uv"
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
      pkgs.curl
      pkgs.findutils
      pkgs.gnugrep
      pkgs.jq
    ];
    text = ''
      cutoff="$(date -d "90 days ago" +%s)"
      report_month="$(date +%Y-%m)"
      curl_config="${homeDir}/.config/hark/integrations/fleet-maintenance.curl"

      active_cwds=()
      for process_cwd in /proc/[0-9]*/cwd; do
        active_cwd="$(readlink -f "$process_cwd" 2>/dev/null || true)"
        if [ -n "$active_cwd" ]; then
          active_cwds+=("$active_cwd")
        fi
      done

      candidates=()
      while IFS= read -r -d "" direnv_dir; do
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
        for active_cwd in "''${active_cwds[@]}"; do
          case "$active_cwd" in
            "$project" | "$project"/*)
              active=true
              break
              ;;
          esac
        done
        if "$active"; then
          continue
        fi

        profile_date="$(date -d "@$profile_mtime" +%F)"
        candidates+=("- \`$project\` — $profile_date")
      done < <(
        find "${homeDir}" /vault -xdev -type d -name .direnv -prune -print0 2>/dev/null \
          | sort -zu
      )

      build_payload() {
        jq -cn \
          --arg body "$2" \
          --arg title "$1" \
          --arg project "Dotfiles" \
          '{body: $body, title: $title, project: $project}'
      }

      deliver_report() {
        title="$1"
        body="$2"
        payload="$(build_payload "$title" "$body")"

        if [ "''${STALE_DIRENV_REPORT_DRY_RUN:-0}" = 1 ]; then
          jq . <<< "$payload"
          return
        fi

        idempotency_key="stale-direnv:$report_month:$(printf '%s' "$payload" | sha256sum | cut -d ' ' -f 1)"
        printf '%s' "$payload" | curl \
          --config "$curl_config" \
          --silent \
          --show-error \
          --fail \
          --output /dev/null \
          --header "Content-Type: application/json" \
          --header "Idempotency-Key: $idempotency_key" \
          --data-binary @-
      }

      if [ "''${#candidates[@]}" -eq 0 ]; then
        deliver_report \
          "No stale direnv environments" \
          "No inactive direnv profiles older than 90 days were found."
        exit 0
      fi

      title="''${#candidates[@]} stale direnv environments"
      body="$(printf "%s\n" "''${candidates[@]}")"
      payload="$(build_payload "$title" "$body")"
      if [ "$(printf '%s' "$body" | wc -m)" -gt 8000 ] \
        || [ "$(printf '%s' "$payload" | wc -c)" -gt 16384 ]; then
        report_path="${homeDir}/.local/state/storage-maintenance/stale-direnv-$report_month.txt"
        if [ "''${STALE_DIRENV_REPORT_DRY_RUN:-0}" != 1 ]; then
          mkdir -p "$(dirname "$report_path")"
          printf '%s\n' "$body" > "$report_path"
        fi
        body="Found ''${#candidates[@]} inactive direnv profiles older than 90 days. Full report: $report_path"
      fi
      deliver_report "$title" "$body"
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
          RandomizedDelaySec = "6h";
          Persistent = true;
        };
        Install.WantedBy = [ "timers.target" ];
      };

      prune-appimage-cache = {
        Unit.Description = "Daily AppImage extraction pruning";
        Timer = {
          OnCalendar = "daily";
          RandomizedDelaySec = "1h";
          Persistent = true;
        };
        Install.WantedBy = [ "timers.target" ];
      };

      report-stale-direnvs = {
        Unit.Description = "Monthly stale direnv report";
        Timer = {
          OnCalendar = "monthly";
          RandomizedDelaySec = "2h";
          Persistent = true;
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
  };
}
