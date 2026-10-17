{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.services.t3-code;
  t3Binary = "${config.home.homeDirectory}/.local/bin/t3";
  android = pkgs.androidenv.composeAndroidPackages {
    platformVersions = [ "37.0" ];
    buildToolsVersions = [ "37.0.0" ];
    includeEmulator = true;
    includeSystemImages = true;
    systemImageTypes = [ "google_apis" ];
    abiVersions = [ "x86_64" ];
  };
  androidSdkPackage = pkgs.symlinkJoin {
    name = "androidsdk-t3";
    paths = [ android.androidsdk ];
    # T3 requires the Android Studio layout; Nix installs tools by version.
    postBuild = ''
      tools_root="$out/libexec/android-sdk/cmdline-tools"
      if [ ! -e "$tools_root/latest" ]; then
        for tools in "$tools_root"/*; do
          if [ -x "$tools/bin/avdmanager" ]; then
            ln -s "$(basename "$tools")" "$tools_root/latest"
            break
          fi
        done
      fi
      test -x "$tools_root/latest/bin/avdmanager"
    '';
  };
  androidSdk = "${androidSdkPackage}/libexec/android-sdk";

  t3CodeStart = pkgs.writeShellScript "t3-code-start" ''
    set -eu
    source "$HOME/.bashenv"

    ${lib.optionalString cfg.android.enable ''
      export ANDROID_HOME=${lib.escapeShellArg androidSdk}
      export ANDROID_SDK_ROOT="$ANDROID_HOME"
      export JAVA_HOME=${pkgs.jdk17}
      export PATH="${
        lib.makeBinPath [
          androidSdkPackage
          pkgs.jdk17
        ]
      }:$PATH"
    ''}

    export PATH="${
      pkgs.lib.makeBinPath [
        pkgs.gcc
        pkgs.gnumake
        pkgs.python3
      ]
    }:$PATH"

    if [[ ! -x ${lib.escapeShellArg t3Binary} ]]; then
      echo "T3 Code binary missing. Install it from https://t3.codes/install.sh before starting this service." >&2
      exit 1
    fi

    exec ${lib.escapeShellArg t3Binary} serve \
      --host 127.0.0.1 \
      --port 3773 \
      --tailscale-serve \
      --tailscale-serve-port 443
  '';

  t3Update = pkgs.writeShellApplication {
    name = "t3-update";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
    ];
    text = ''
      t3_binary=${lib.escapeShellArg t3Binary}

      usage() {
        echo "Usage: t3-update [--channel stable|nightly|preview | --version VERSION]"
      }

      update_args=(--channel nightly)
      case "''${1:-}" in
        "") if (( $# != 0 )); then usage >&2; exit 2; fi ;;
        --help|-h) usage; exit 0 ;;
        --channel)
          if (( $# != 2 )); then usage >&2; exit 2; fi
          case "$2" in
            stable|nightly|preview) update_args=(--channel "$2" --allow-downgrade) ;;
            *) usage >&2; exit 2 ;;
          esac
          ;;
        --version)
          if (( $# != 2 )) || [[ -z "$2" || "$2" == -* ]]; then
            usage >&2; exit 2
          fi
          update_args=("$2" --allow-downgrade)
          ;;
        *) usage >&2; exit 2 ;;
      esac

      # Home Manager owns t3-code.service; do not install the upstream service.
      "$t3_binary" update "''${update_args[@]}"

      # Compare the running executable with the updated symlink, including when
      # an earlier update downloaded a release without restarting this service.
      running_pid=$(systemctl --user show t3-code.service --property=MainPID --value)
      running_binary=$(readlink -f "/proc/$running_pid/exe" || true)
      installed_binary=$(readlink -f "$t3_binary")
      if [[ "$running_pid" == 0 || "$running_binary" != "$installed_binary" ]]; then
        systemctl --user restart t3-code.service
        echo "T3 Code server restarted with $("$t3_binary" --version)"
      else
        echo "T3 Code server already runs $("$t3_binary" --version); no restart needed."
      fi
    '';
  };
in
{
  options.dotfiles.services.t3-code = {
    enable = lib.mkEnableOption "T3 Code server exposed through Tailscale Serve";
    android.enable = lib.mkEnableOption "a local Android SDK and emulator for T3 Code";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      t3Update
    ]
    ++ lib.optionals cfg.android.enable [ androidSdkPackage ];

    # Also expose the conventional path for tools outside the systemd service.
    home.file."Android/Sdk" = lib.mkIf cfg.android.enable {
      source = androidSdk;
    };

    systemd.user.services.t3-code = {
      Unit = {
        Description = "T3 Code server exposed through Tailscale Serve";
        After = [ "network-online.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = t3CodeStart;
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
