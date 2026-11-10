{
  lib,
  pkgs,
  ...
}:
let
  heliumAgentsProfile = "/vault/userdata/browser-profiles/helium/agents";
  heliumAgentsDevtoolsPort = "9222";
  heliumIcon = ''
    <svg width="256" height="256" viewBox="0 0 256 256" fill="none" xmlns="http://www.w3.org/2000/svg"><rect width="256" height="256" rx="67" fill="#3450D1"/><path d="M145.966 207.813L128 221L110.034 207.813L118.198 144.891L67.4689 183.379L47 174.5L49.4993 152.438L108.391 128L49.4993 103.562L47 81.5L67.4689 72.6214L118.198 111.109L110.034 48.1871L128 35L145.966 48.1871L137.802 111.109L188.531 72.6214L209 81.5L206.501 103.562L147.609 128L206.501 152.438L209 174.5L188.531 183.379L137.802 144.891L145.966 207.813Z" fill="#FBFCFF"/></svg>
  '';
  mkHeliumIconVariant =
    background: foreground:
    lib.replaceStrings
      [
        "#3450D1"
        "#FBFCFF"
      ]
      [
        background
        foreground
      ]
      heliumIcon;
  heliumAgentsDevtoolsIcon = mkHeliumIconVariant "#2b1b17" "#f4a261";
  heliumAgentsDevtools = pkgs.writeShellScriptBin "helium-agents-devtools" ''
    set -euo pipefail
    profile=${lib.escapeShellArg heliumAgentsProfile}
    port=${lib.escapeShellArg heliumAgentsDevtoolsPort}

    mkdir -p "$profile"

    profileInUse=false
    if ! ${lib.getExe pkgs.curl} -fsS "http://127.0.0.1:$port/json/version" >/dev/null 2>&1; then
      lockTarget=$(${lib.getExe' pkgs.coreutils "readlink"} "$profile/SingletonLock" 2>/dev/null || true)
      IFS= read -r host < /proc/sys/kernel/hostname

      case "$lockTarget" in
        "$host"-*)
          pid="''${lockTarget#"$host"-}"
          case "$pid" in
            "" | *[!0-9]*) ;;
            *)
              if [ -r "/proc/$pid/cmdline" ]; then
                while IFS= read -r -d "" arg; do
                  if [ "$arg" = "--user-data-dir=$profile" ]; then
                    profileInUse=true
                    break
                  fi
                done < "/proc/$pid/cmdline"
              fi
              ;;
          esac
          ;;
      esac
    fi

    if $profileInUse; then
      ${lib.getExe pkgs.libnotify} -u critical "Helium Agents DevTools" "Another Helium instance is using the agents profile. Close it first."
      printf '%s\n' "helium-agents-devtools: another Helium instance is using the agents profile; close it first." >&2
      exit 1
    fi

    exec ${lib.getExe pkgs.helium} \
      --user-data-dir=${lib.escapeShellArg heliumAgentsProfile} \
      --remote-debugging-address=127.0.0.1 \
      --remote-debugging-port=${heliumAgentsDevtoolsPort} \
      --class=HeliumAgentsDevTools \
      "$@"
  '';
in
{
  home.sessionVariables = {
    BROWSER = "helium";
    HELIUM_AGENTS_PROFILE = heliumAgentsProfile;
    HELIUM_AGENTS_CDP_PORT = heliumAgentsDevtoolsPort;
  };

  home.packages = [
    pkgs.helium
    heliumAgentsDevtools
  ];

  xdg.desktopEntries.helium-agents-devtools = {
    name = "Helium Agents DevTools";
    comment = "Helium browser";
    exec = "helium-agents-devtools %U";
    icon = "helium-agents-devtools";
    categories = [
      "Network"
      "WebBrowser"
    ];
    settings.StartupWMClass = "HeliumAgentsDevTools";
  };

  xdg.dataFile = {
    "icons/hicolor/scalable/apps/helium.svg".text = heliumIcon;
    "icons/hicolor/scalable/apps/helium-agents-devtools.svg".text = heliumAgentsDevtoolsIcon;
  };
}
